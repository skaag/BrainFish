import Foundation
import EventKit
import Combine

/// Engine responsible for two-way sync between Tasks and EventKit Reminders
@MainActor
class SyncEngine: ObservableObject {
    private let reminderService: ReminderService
    private let taskStore: AppData  // Reference to existing AppData

    private var syncTask: _Concurrency.Task<Void, Never>?
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 1.5

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    init(reminderService: ReminderService, taskStore: AppData) {
        self.reminderService = reminderService
        self.taskStore = taskStore

        setupExternalChangeListener()
    }

    // MARK: - Setup

    private func setupExternalChangeListener() {
        // Listen for external EventKit changes
        reminderService.onExternalChange = { [weak self] in
            _Concurrency.Task { @MainActor in
                await self?.scheduleDebouncedSync()
            }
        }
    }

    // MARK: - Debounced Sync

    func scheduleDebouncedSync() async {
        // Cancel existing timer
        debounceTimer?.invalidate()

        // Schedule new sync after debounce interval
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            _Concurrency.Task { @MainActor in
                await self?.performSync()
            }
        }

        print("⏱️ Sync scheduled (debounced for \(debounceInterval)s)")
    }

    // MARK: - Sync Operations

    func performInitialSync() async {
        guard reminderService.syncEnabled else {
            print("⚠️ Sync disabled - authorization required")
            return
        }

        await performSync()
    }

    private func performSync() async {
        guard !isSyncing else {
            print("⚠️ Sync already in progress, skipping")
            return
        }

        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        print("🔄 Starting sync...")

        do {
            // 1. Fetch all reminders from EventKit
            let reminders = try await reminderService.loadAllReminders()
            print("📥 Loaded \(reminders.count) reminders from EventKit")

            // 2. Build reminder ID map
            let remindersByID = Dictionary(uniqueKeysWithValues: reminders.map { ($0.calendarItemIdentifier, $0) })

            // 3. Build task ID map
            let tasksByReminderID = Dictionary(uniqueKeysWithValues: taskStore.tasks.compactMap { task in
                task.reminderID.map { ($0, task) }
            })

            // 4. Reconcile: Reminders → Tasks (import or update)
            for reminder in reminders {
                if let existingTask = tasksByReminderID[reminder.calendarItemIdentifier] {
                    // Task exists - check for conflicts
                    try await resolveConflict(task: existingTask, reminder: reminder)
                } else {
                    // New reminder - import as task
                    await importReminder(reminder)
                }
            }

            // 5. Reconcile: Tasks → Reminders (create or cleanup)
            for task in taskStore.tasks {
                if let reminderID = task.reminderID {
                    // Task has reminderID but reminder doesn't exist
                    if remindersByID[reminderID] == nil {
                        print("⚠️ Task '\(task.title)' has reminderID but reminder not found - marking as deleted")
                        task.reminderID = nil
                        task.reminderDeleted = true  // Mark as deliberately deleted
                        task.lastModified = Date()
                        taskStore.saveTasks()
                    }
                } else {
                    // Task has no reminder - create one only if it wasn't deliberately deleted
                    if !task.isCompleted && !task.reminderDeleted {
                        try await createReminderForTask(task)
                    }
                }
            }

            lastSyncDate = Date()
            print("✅ Sync completed successfully")

        } catch {
            syncError = error.localizedDescription
            print("❌ Sync failed: \(error)")
        }
    }

    // MARK: - Conflict Resolution

    private func resolveConflict(task: BrainFish.Task, reminder: EKReminder) async throws {
        let reminderModified = reminderService.lastModifiedDate(for: reminder)

        if task.lastModified > reminderModified {
            // Task is newer - update reminder
            print("📤 Task '\(task.title)' is newer - updating reminder")
            try await reminderService.updateReminder(reminder.calendarItemIdentifier, from: task)

        } else if reminderModified > task.lastModified {
            // Reminder is newer - update task
            print("📥 Reminder '\(reminder.title ?? "untitled")' is newer - updating task")
            updateTaskFromReminder(task: task, reminder: reminder)

        } else {
            // Same modification time - no action needed
            print("✓ Task '\(task.title)' and reminder are in sync")
        }
    }

    // MARK: - Import/Export

    private func importReminder(_ reminder: EKReminder) async {
        let title = reminder.title ?? "Untitled"
        let notes = reminder.notes
        let dueDate = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }

        // Create new task from reminder
        let newTask = BrainFish.Task(
            title: title,
            startOffset: Double.random(in: 0...1),
            speed: CGFloat.random(in: 20...40),
            remainingTime: 7200,
            notes: notes,
            dueDate: dueDate,
            isCompleted: reminder.isCompleted,
            reminderID: reminder.calendarItemIdentifier,
            reminderDeleted: false  // Imported reminder, not deleted
        )

        taskStore.tasks.append(newTask)
        taskStore.saveTasks()

        print("📥 Imported reminder as task: '\(title)'")
    }

    private func updateTaskFromReminder(task: BrainFish.Task, reminder: EKReminder) {
        task.title = reminder.title ?? "Untitled"
        task.notes = reminder.notes
        task.dueDate = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        task.isCompleted = reminder.isCompleted
        task.reminderID = reminder.calendarItemIdentifier
        task.lastModified = reminderService.lastModifiedDate(for: reminder)

        taskStore.saveTasks()
    }

    private func createReminderForTask(_ task: BrainFish.Task) async throws {
        print("📤 Creating reminder for task: '\(task.title)'")
        let reminderID = try await reminderService.createReminder(from: task)

        task.reminderID = reminderID
        task.lastModified = Date()
        taskStore.saveTasks()
    }

    // MARK: - Manual Sync Triggers

    func syncTaskUpdate(_ task: BrainFish.Task) async {
        guard let reminderID = task.reminderID else {
            // Task doesn't have a reminder yet - create one
            try? await createReminderForTask(task)
            return
        }

        // Update existing reminder
        do {
            try await reminderService.updateReminder(reminderID, from: task)
            task.lastModified = Date()
            taskStore.saveTasks()
        } catch {
            print("❌ Failed to update reminder: \(error)")
        }
    }

    func syncTaskCompletion(_ task: BrainFish.Task, completed: Bool) async {
        task.isCompleted = completed
        task.lastModified = Date()

        if let reminderID = task.reminderID {
            do {
                try await reminderService.updateReminder(reminderID, from: task)
            } catch {
                print("❌ Failed to mark reminder as completed: \(error)")
            }
        }

        taskStore.saveTasks()
    }

    func syncTaskDeletion(_ task: BrainFish.Task) async {
        if let reminderID = task.reminderID {
            do {
                try await reminderService.deleteReminder(reminderID)
            } catch {
                print("❌ Failed to delete reminder: \(error)")
            }
        }

        if let index = taskStore.tasks.firstIndex(where: { $0.id == task.id }) {
            taskStore.tasks.remove(at: index)
            taskStore.saveTasks()
        }
    }
}
