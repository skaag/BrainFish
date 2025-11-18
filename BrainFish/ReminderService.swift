import Foundation
import EventKit

/// Service responsible for all EventKit (Reminders) operations
@MainActor
class ReminderService: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var isAuthorized = false
    @Published var syncEnabled = false

    // Callback for when external changes are detected
    var onExternalChange: (() -> Void)?

    init() {
        setupNotifications()
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            isAuthorized = granted
            syncEnabled = granted
            return granted
        } catch {
            print("❌ Failed to request reminders access: \(error)")
            isAuthorized = false
            syncEnabled = false
            return false
        }
    }

    // MARK: - Change Notifications

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eventStoreChanged(_:)),
            name: .EKEventStoreChanged,
            object: eventStore
        )
    }

    @objc private func eventStoreChanged(_ notification: Notification) {
        print("📬 EventKit database changed - triggering sync")
        _Concurrency.Task { @MainActor in
            onExternalChange?()
        }
    }

    // MARK: - Load Operations

    func loadAllReminders() async throws -> [EKReminder] {
        guard isAuthorized else {
            throw ReminderServiceError.unauthorized
        }

        // Get the BrainFish calendar specifically
        let brainFishCalendar = try await loadBrainFishList()

        // Only fetch reminders from the BrainFish calendar
        let predicate = eventStore.predicateForReminders(in: [brainFishCalendar])

        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    // Only return incomplete reminders (active tasks)
                    let activeReminders = reminders.filter { !$0.isCompleted }
                    continuation.resume(returning: activeReminders)
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    func loadBrainFishList() async throws -> EKCalendar {
        guard isAuthorized else {
            throw ReminderServiceError.unauthorized
        }

        // Check if BrainFish calendar already exists
        let calendars = eventStore.calendars(for: .reminder)
        if let existingCalendar = calendars.first(where: { $0.title == "BrainFish" }) {
            print("✅ Found existing BrainFish reminders list")
            return existingCalendar
        }

        // Create new BrainFish calendar
        let newCalendar = EKCalendar(for: .reminder, eventStore: eventStore)
        newCalendar.title = "BrainFish"

        // Get the source (usually iCloud or local)
        guard let source = eventStore.sources.first(where: { $0.sourceType == .calDAV || $0.sourceType == .local }) ?? eventStore.sources.first else {
            throw ReminderServiceError.noDefaultCalendar
        }

        newCalendar.source = source

        try eventStore.saveCalendar(newCalendar, commit: true)
        print("✅ Created new BrainFish reminders list")

        return newCalendar
    }

    // MARK: - Create Operations

    func createReminder(from task: Task) async throws -> String {
        guard isAuthorized else {
            throw ReminderServiceError.unauthorized
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = task.title
        reminder.notes = task.notes
        reminder.dueDateComponents = task.dueDate.map { Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0) }
        reminder.isCompleted = task.isCompleted

        // Embed fish task UUID in reminder URL for matching
        reminder.url = URL(string: "fishapp://task/\(task.id.uuidString)")

        let brainFishCalendar = try await loadBrainFishList()
        reminder.calendar = brainFishCalendar

        try eventStore.save(reminder, commit: true)

        print("✅ Created reminder: \(reminder.title ?? "untitled") with ID: \(reminder.calendarItemIdentifier)")
        return reminder.calendarItemIdentifier
    }

    // MARK: - Update Operations

    func updateReminder(_ reminderID: String, from task: Task) async throws {
        guard isAuthorized else {
            throw ReminderServiceError.unauthorized
        }

        guard let reminder = eventStore.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            throw ReminderServiceError.reminderNotFound
        }

        reminder.title = task.title
        reminder.notes = task.notes
        reminder.dueDateComponents = task.dueDate.map { Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0) }
        reminder.isCompleted = task.isCompleted

        try eventStore.save(reminder, commit: true)
        print("📝 Updated reminder: \(reminder.title ?? "untitled")")
    }

    // MARK: - Delete Operations

    func deleteReminder(_ reminderID: String) async throws {
        guard isAuthorized else {
            throw ReminderServiceError.unauthorized
        }

        guard let reminder = eventStore.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            throw ReminderServiceError.reminderNotFound
        }

        try eventStore.remove(reminder, commit: true)
        print("🗑️ Deleted reminder: \(reminder.title ?? "untitled")")
    }

    // MARK: - Helper Methods

    /// Extracts task UUID from reminder URL
    func extractTaskUUID(from reminder: EKReminder) -> UUID? {
        guard let url = reminder.url,
              url.scheme == "fishapp",
              url.host == "task",
              let uuidString = url.pathComponents.last,
              let uuid = UUID(uuidString: uuidString) else {
            return nil
        }
        return uuid
    }

    /// Computes approximate last modified date for a reminder
    func lastModifiedDate(for reminder: EKReminder) -> Date {
        // EventKit doesn't expose explicit lastModified, so we use the latest of available dates
        let dates = [
            reminder.completionDate,
            reminder.creationDate,
            reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
        ].compactMap { $0 }

        return dates.max() ?? Date()
    }
}

// MARK: - Errors

enum ReminderServiceError: Error, LocalizedError {
    case unauthorized
    case noDefaultCalendar
    case reminderNotFound

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Reminders access not authorized. Please grant permission in System Settings."
        case .noDefaultCalendar:
            return "No default reminders list found."
        case .reminderNotFound:
            return "Reminder not found in EventKit database."
        }
    }
}
