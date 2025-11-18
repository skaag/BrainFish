/*
 __________               .__       ___________.__       .__
 \______   \____________  |__| ____ \_   _____/|__| _____|  |__
  |    |  _/\_  __ \__  \ |  |/    \ |    __)  |  |/  ___/  |  \
  |    |   \ |  | \// __ \|  |   |  \|     \   |  |\___ \|   Y  \
  |    |   / |__|  (____  /__|___|  /\___  /   |__/____  >___|  /
  |______  /             \/        \/     \/            \/     \/

 BrainFish - A macOS Floating Fish Reminder App
 Developed by Aric Fedida
 Version 1.0 | Date: February 10th 2025

 "Let your reminders swim by, so you never forget your goals."
 (Thank you https://patorjk.com/software/taag/#p=display&f=Graffiti&t=BrainFish for the beautiful logo!)
*/

import SwiftUI
import Combine
import AppKit
import Foundation
import UniformTypeIdentifiers
import ApplicationServices
import ServiceManagement
import CoreServices

// MARK: - Constants
private enum FishConstants {
    static let headSizeMultiplier: CGFloat = 2.0
    static let pectoralFinSizeMultiplier: CGFloat = 1.4
    static let pectoralFinPosition: CGFloat = 0.15
    static let ventralFinSizeMultiplier: CGFloat = 1.1
    static let ventralFinPosition: CGFloat = 0.4
    static let tailSizeMultiplier: CGFloat = 1.6
    static let tailOffsetMultiplier: CGFloat = 0.8
    static let letterSpacingMultiplier: CGFloat = 0.6
    static let outlineWidth: CGFloat = 1.0
    static let maxTaskTitleLength: Int = 100
}

// --- Global Mouse Tracker ---
class GlobalMouseTracker: ObservableObject {
    private var timer: Timer?
    private var globalMonitor: Any?
    @Published var globalMousePosition: NSPoint = .zero
    @Published var hasAccessibilityPermission: Bool = false
    var pollingInterval: TimeInterval = 1.0 / 30.0

    deinit {
        stop()
    }

    func start() {
        stop()
        let trusted = AXIsProcessTrusted()
        hasAccessibilityPermission = trusted

        if trusted {
            let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
                self?.updateMousePosition(from: event.locationInWindow)
            }
        }

        if globalMonitor == nil {
            timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if let event = CGEvent(source: nil) {
                    self.updateMousePosition(from: event.location)
                }
            }
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        timer?.invalidate()
        timer = nil
    }

    private func updateMousePosition(from location: CGPoint) {
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let converted = NSPoint(x: location.x, y: screenHeight - location.y)
        DispatchQueue.main.async {
            self.globalMousePosition = converted
        }
    }
}


// Make UUID conform to Transferable
extension UUID: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.uuidString)
    }
}

func timeString(from seconds: TimeInterval) -> String {
    guard seconds >= 0 else { return "00:00" }
    let minutes = Int(seconds) / 60
    let secs = Int(seconds) % 60
    return String(format: "%02d:%02d", minutes, secs)
}

// MARK: - StatusBarController
class StatusBarController {
    private var statusItem: NSStatusItem
    //private var popover: NSPopover

    init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "fish.fill", accessibilityDescription: "BrainFish")
        }
        
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Task List", action: #selector(AppDelegate.showTaskListAction), keyEquivalent: "")
        menu.addItem(withTitle: "Settings", action: #selector(AppDelegate.showSettingsAction), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        
        statusItem.menu = menu
    }

    @objc func showTaskListAction() {
        NotificationCenter.default.post(name: Notification.Name("ShowTaskList"), object: nil)
    }

    @objc func showSettingsAction() {
        NotificationCenter.default.post(name: Notification.Name("ShowSettings"), object: nil)
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var popover: NSPopover!
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first, let screen = NSScreen.main {
            window.setFrame(screen.frame, display: true)
            // Use floating level so drawer can receive drops over other windows
            window.level = .floating
            window.styleMask = [.borderless]
            window.isOpaque = false
            window.backgroundColor = .clear
            // Note: NOT ignoring mouse events globally - ClipDrawer needs drops
            // Fish area will ignore via SwiftUI .allowsHitTesting(false)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            self.window = window
        }
        statusBarController = StatusBarController()
        setupScreenChangeObserver()
    }
    
    @objc func showTaskListAction() {
        NotificationCenter.default.post(name: Notification.Name("ShowTaskList"), object: nil)
    }
    
    @objc func showSettingsAction() {
        NotificationCenter.default.post(name: Notification.Name("ShowSettings"), object: nil)
    }

    private func updateWindowFrame(for window: NSWindow) {
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            window.setFrame(screenFrame, display: true)
        }
    }

    @objc func handleScreenChange() {
        guard let screen = NSScreen.main else { return }
        let screenBounds = screen.visibleFrame

        // Calculate safe zone (80% of visible screen)
        let safeZone = CGRect(
            x: screenBounds.minX + screenBounds.width * 0.1,
            y: screenBounds.minY + screenBounds.height * 0.1,
            width: screenBounds.width * 0.8,
            height: screenBounds.height * 0.8
        )

        // Reset fish positions within safe zone
        NotificationCenter.default.post(
            name: Notification.Name("ResetFishPositions"),
            object: nil,
            userInfo: ["safeZone": safeZone]
        )

        // Safely update window frame
        guard let window = window else { return }
        updateWindowFrame(for: window)
    }

    private func setupScreenChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
}


// MARK: - Clip Model (for ClipDrawer)
struct Clip: Identifiable, Codable, Equatable {
    let id: UUID
    let content: ClipContent
    let timestamp: Date
    let preview: String // First 10 chars for display
    let side: DrawerSide // Which drawer this clip belongs to
    let dropZone: Int // Zone 0-31 where clip was dropped
    let sourceAppBundleID: String? // Bundle ID of app that provided the clip
    let sourceAppName: String? // Name of app that provided the clip

    init(content: ClipContent, side: DrawerSide, dropZone: Int = 0, timestamp: Date = Date(), sourceAppBundleID: String? = nil, sourceAppName: String? = nil) {
        self.id = UUID()
        self.content = content
        self.side = side
        self.dropZone = dropZone
        self.timestamp = timestamp
        self.preview = content.previewText
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
    }

    static func == (lhs: Clip, rhs: Clip) -> Bool {
        lhs.id == rhs.id
    }
}

enum DrawerSide: String, Codable {
    case left, right
}

enum ClipContent: Codable, Equatable {
    case text(String)
    case url(URL)
    case image(Data)

    var previewText: String {
        switch self {
        case .text(let string):
            return String(string.prefix(10))
        case .url(let url):
            return String(url.absoluteString.prefix(10))
        case .image(let data):
            let kb = data.count / 1024
            return "Image \(kb)KB"
        }
    }

    var fullText: String {
        switch self {
        case .text(let string):
            return string
        case .url(let url):
            return url.absoluteString
        case .image(let data):
            let kb = data.count / 1024
            if let nsImage = NSImage(data: data),
               let pixelSize = nsImage.representations.first {
                return "Image: \(Int(pixelSize.pixelsWide))×\(Int(pixelSize.pixelsHigh)) (\(kb) KB)"
            }
            return "Image (\(kb) KB)"
        }
    }

    var image: NSImage? {
        switch self {
        case .image(let data):
            return NSImage(data: data)
        default:
            return nil
        }
    }
}

// MARK: - Task Model
final class Task: Identifiable, ObservableObject {
    let id = UUID()
    @Published var title: String
    var startOffset: Double
    var speed: CGFloat
    @Published var remainingTime: TimeInterval
    @Published var accelerationEndTime: Date? = nil // Added for sustained speed

    // EventKit integration properties
    @Published var notes: String?
    @Published var dueDate: Date?
    @Published var isCompleted: Bool = false
    var reminderID: String?  // EKReminder.calendarItemIdentifier
    var lastModified: Date
    var reminderDeleted: Bool = false  // Track if reminder was deliberately deleted

    init(title: String, startOffset: Double, speed: CGFloat, remainingTime: TimeInterval = 7200, notes: String? = nil, dueDate: Date? = nil, isCompleted: Bool = false, reminderID: String? = nil, reminderDeleted: Bool = false) {
        self.title = title
        self.startOffset = startOffset
        self.speed = speed
        self.remainingTime = remainingTime
        self.notes = notes
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.reminderID = reminderID
        self.lastModified = Date()
        self.reminderDeleted = reminderDeleted
    }
}

extension Task: Codable {
    enum CodingKeys: String, CodingKey {
        case title, startOffset, speed, remainingTime, notes, dueDate, isCompleted, reminderID, lastModified, reminderDeleted
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(startOffset, forKey: .startOffset)
        try container.encode(Double(speed), forKey: .speed)
        try container.encode(remainingTime, forKey: .remainingTime)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(reminderID, forKey: .reminderID)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(reminderDeleted, forKey: .reminderDeleted)
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let title = try container.decode(String.self, forKey: .title)
        let startOffset = try container.decode(Double.self, forKey: .startOffset)
        let speedDouble = try container.decode(Double.self, forKey: .speed)
        let remainingTime = try container.decode(TimeInterval.self, forKey: .remainingTime)
        let notes = try container.decodeIfPresent(String.self, forKey: .notes)
        let dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        let isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        let reminderID = try container.decodeIfPresent(String.self, forKey: .reminderID)
        let reminderDeleted = try container.decodeIfPresent(Bool.self, forKey: .reminderDeleted) ?? false

        self.init(title: title, startOffset: startOffset, speed: CGFloat(speedDouble), remainingTime: remainingTime, notes: notes, dueDate: dueDate, isCompleted: isCompleted, reminderID: reminderID, reminderDeleted: reminderDeleted)

        // Restore lastModified if present, otherwise use current time
        if let savedLastModified = try? container.decode(Date.self, forKey: .lastModified) {
            self.lastModified = savedLastModified
        }
    }
}


// MARK: - ClipDrawerManager
class ClipDrawerManager: ObservableObject {
    @Published var clips: [Clip] = []
    @Published var isLeftDrawerVisible: Bool = false
    @Published var isRightDrawerVisible: Bool = false
    @Published var isLeftClipsVisible: Bool = false
    @Published var isRightClipsVisible: Bool = false
    @Published var hoveredClipID: UUID?
    @Published var globalMousePosition: CGPoint = .zero
    @Published var isDraggingClip: Bool = false

    private let clipsKey = "SavedClips"
    private var cancellables = Set<AnyCancellable>()

    // Auto-hide timers for clips
    private var leftClipsHideTimer: Timer?
    private var rightClipsHideTimer: Timer?
    var autoHideDelay: Double = 4.0

    init() {
        loadClips()
        // Save clips whenever the array changes
        $clips
            .sink { [weak self] _ in
                self?.saveClips()
            }
            .store(in: &cancellables)
    }

    func addClip(_ clip: Clip) {
        clips.insert(clip, at: 0) // Most recent at top
    }

    func removeClip(_ clip: Clip) {
        clips.removeAll { $0.id == clip.id }
    }

    func clipsForSide(_ side: DrawerSide) -> [Clip] {
        clips.filter { $0.side == side }
    }

    // Check if mouse is within visible radius of any clip on the given side
    func isMouseNearClips(side: DrawerSide, screenWidth: CGFloat, screenHeight: CGFloat, drawerWidth: CGFloat, visibleRadius: CGFloat, topMargin: CGFloat, usableHeight: CGFloat, xOffset: CGFloat) -> Bool {
        let sideClips = clipsForSide(side)
        guard !sideClips.isEmpty else { return false }

        let zoneHeight = usableHeight / 32

        for clip in sideClips {
            let clipY = topMargin + CGFloat(clip.dropZone) * zoneHeight

            // Calculate clip screen position
            let clipScreenX: CGFloat = side == .left
                ? drawerWidth / 2 + xOffset
                : screenWidth - drawerWidth / 2 + xOffset

            // Convert clipY from view coords to screen coords
            let clipScreenY = screenHeight - clipY

            let mouseX = globalMousePosition.x
            let mouseY = globalMousePosition.y

            let dx = mouseX - clipScreenX
            let dy = mouseY - clipScreenY
            let distance = sqrt(dx * dx + dy * dy)

            if distance <= visibleRadius {
                return true
            }
        }

        return false
    }

    func saveClips() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(clips)
            UserDefaults.standard.set(data, forKey: clipsKey)
        } catch {
            print("Failed to encode clips: \(error.localizedDescription)")
        }
    }

    func loadClips() {
        guard let data = UserDefaults.standard.data(forKey: clipsKey) else { return }
        let decoder = JSONDecoder()
        do {
            clips = try decoder.decode([Clip].self, from: data)
            print("✅ Loaded \(clips.count) clips from storage")
        } catch {
            print("❌ Failed to decode clips (likely old format without 'side' field): \(error.localizedDescription)")
            print("   Clearing old clips data...")
            UserDefaults.standard.removeObject(forKey: clipsKey)
            clips = []
        }
    }

    // Schedule auto-hide timer for left clips only
    func scheduleLeftClipsHide() {
        leftClipsHideTimer?.invalidate()
        leftClipsHideTimer = Timer.scheduledTimer(withTimeInterval: autoHideDelay, repeats: false) { [weak self] _ in
            self?.isLeftClipsVisible = false
        }
    }

    // Schedule auto-hide timer for right clips only
    func scheduleRightClipsHide() {
        rightClipsHideTimer?.invalidate()
        rightClipsHideTimer = Timer.scheduledTimer(withTimeInterval: autoHideDelay, repeats: false) { [weak self] _ in
            self?.isRightClipsVisible = false
        }
    }

    // Cancel auto-hide timer for left clips
    func cancelLeftClipsHide() {
        leftClipsHideTimer?.invalidate()
        leftClipsHideTimer = nil
    }

    // Cancel auto-hide timer for right clips
    func cancelRightClipsHide() {
        rightClipsHideTimer?.invalidate()
        rightClipsHideTimer = nil
    }
}

// MARK: - AppData
@MainActor
class AppData: ObservableObject {
    @Published var tasks: [Task] = [
        Task(title: "Buy groceries", startOffset: 0, speed: 50)
    ]
    @Published var currentPomodoroTaskIndex: Int = 0
    var defaultPomodoroTime: TimeInterval = 7200  // 120 minutes

    private var timer: Timer?

    private let tasksKey = "SavedTasks"
    private var cancellables = Set<AnyCancellable>()

    // EventKit integration
    let reminderService: ReminderService
    private(set) var syncEngine: SyncEngine!

    init() {
        // Initialize EventKit services
        self.reminderService = ReminderService()

        loadTasks()  // Attempt to load saved tasks
        startTimer()

        // Save tasks whenever the tasks array changes.
        $tasks
            .sink { [weak self] _ in
                self?.saveTasks()
            }
            .store(in: &cancellables)

        // Initialize sync engine on main actor (but don't request permission yet)
        _Concurrency.Task { @MainActor in
            self.syncEngine = SyncEngine(reminderService: self.reminderService, taskStore: self)
        }
    }

    func enableRemindersSync() async -> Bool {
        print("🔵 enableRemindersSync called - requesting authorization...")
        let authorized = await reminderService.requestAuthorization()
        print("🔵 Authorization result: \(authorized)")
        if authorized {
            print("✅ Reminders authorization granted")
            await syncEngine.performInitialSync()
            return true
        } else {
            print("⚠️ Reminders authorization denied")
            return false
        }
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                self.updatePomodoroTimer()
            }
        }
    }
    
    func saveTasks() {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(tasks)
            UserDefaults.standard.set(data, forKey: tasksKey)
        } catch {
            print("Failed to encode tasks: \(error.localizedDescription)")
        }
    }

    func loadTasks() {
        guard let data = UserDefaults.standard.data(forKey: tasksKey) else { return }
        let decoder = JSONDecoder()
        do {
            tasks = try decoder.decode([Task].self, from: data)
        } catch {
            print("Failed to decode tasks: \(error.localizedDescription)")
            // Keep default tasks if decode fails
        }
    }

    func updatePomodoroTimer() {
        guard !tasks.isEmpty else { return }
        let index = currentPomodoroTaskIndex % tasks.count
        let currentTask = tasks[index]
        currentTask.remainingTime -= 1
        if currentTask.remainingTime <= 0 {
            currentTask.remainingTime = 0
            currentPomodoroTaskIndex += 1
            if currentPomodoroTaskIndex >= tasks.count {
                currentPomodoroTaskIndex = 0
                for task in tasks {
                    task.remainingTime = defaultPomodoroTime
                }
            } else {
                tasks[currentPomodoroTaskIndex].remainingTime = defaultPomodoroTime
            }
        }
    }
}


// MARK: - Add a thick black line around the font (for visibility)
struct OutlineText: ViewModifier {
    var color: Color = .gray
    var lineWidth: CGFloat = 0
    func body(content: Content) -> some View {
        ZStack {
            // Four copies, each offset slightly in different directions:
            content
                .foregroundColor(color)
                .offset(x: lineWidth, y: lineWidth)
            // The original content on top.
            content
        }
    }
}


// MARK: - AppSettings
class AppSettings: ObservableObject {
    @Published var useGlobalMouseTracking: Bool = true
    @Published var fontColor: Color = .red  // (For Color you might need a custom solution, but we'll leave it as-is for now.)

    @Published var fontSize: CGFloat = 20 {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: "fontSize")
        }
    }

    @Published var pomodoroMode: Bool = false {
        didSet {
            UserDefaults.standard.set(pomodoroMode, forKey: "pomodoroMode")
        }
    }

    @Published var defaultPomodoroTime: TimeInterval = 7200 {
        didSet {
            UserDefaults.standard.set(defaultPomodoroTime, forKey: "defaultPomodoroTime")
        }
    }

    // --- Reminders Sync Settings ---
    @Published var remindersSyncEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(remindersSyncEnabled, forKey: "remindersSyncEnabled")
        }
    }

    // --- Sleep Cycle Settings ---
    @Published var sleepIntervalMinutes: Int = 1 {
        didSet { UserDefaults.standard.set(sleepIntervalMinutes, forKey: "sleepIntervalMinutes") }
    }
    @Published var sleepDurationMinutes: Int = 4 {
        didSet { UserDefaults.standard.set(sleepDurationMinutes, forKey: "sleepDurationMinutes") }
    }

    @Published var launchAtLogin: Bool = false {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            setLaunchAtLogin(enabled: launchAtLogin)
        }
    }

    // --- ClipDrawer Settings ---
    @Published var clipDrawerEnabled: Bool = true {
        didSet { UserDefaults.standard.set(clipDrawerEnabled, forKey: "clipDrawerEnabled") }
    }
    @Published var clipDrawerLeftEnabled: Bool = true {
        didSet { UserDefaults.standard.set(clipDrawerLeftEnabled, forKey: "clipDrawerLeftEnabled") }
    }
    @Published var clipDrawerRightEnabled: Bool = false {
        didSet { UserDefaults.standard.set(clipDrawerRightEnabled, forKey: "clipDrawerRightEnabled") }
    }
    @Published var clipDrawerDeleteOnDragOut: Bool = true {
        didSet { UserDefaults.standard.set(clipDrawerDeleteOnDragOut, forKey: "clipDrawerDeleteOnDragOut") }
    }
    @Published var clipDrawerShowAppIcons: Bool = true {
        didSet { UserDefaults.standard.set(clipDrawerShowAppIcons, forKey: "clipDrawerShowAppIcons") }
    }
    @Published var clipDrawerShowAdvancedSettings: Bool = false {
        didSet { UserDefaults.standard.set(clipDrawerShowAdvancedSettings, forKey: "clipDrawerShowAdvancedSettings") }
    }

    // ClipDrawer Visual Tuning
    @Published var clipFontSize: CGFloat = 6 {
        didSet { UserDefaults.standard.set(clipFontSize, forKey: "clipFontSize") }
    }
    @Published var clipPaddingHorizontal: CGFloat = 6 {
        didSet { UserDefaults.standard.set(clipPaddingHorizontal, forKey: "clipPaddingHorizontal") }
    }
    @Published var clipPaddingVertical: CGFloat = 0 {
        didSet { UserDefaults.standard.set(clipPaddingVertical, forKey: "clipPaddingVertical") }
    }
    @Published var clipAppIconSize: CGFloat = 10 {
        didSet { UserDefaults.standard.set(clipAppIconSize, forKey: "clipAppIconSize") }
    }
    @Published var clipBackgroundColor: Color = .gray {
        didSet {
            if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(clipBackgroundColor), requiringSecureCoding: false) {
                UserDefaults.standard.set(colorData, forKey: "clipBackgroundColor")
            }
        }
    }
    @Published var clipFontColor: Color = .white {
        didSet {
            if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(clipFontColor), requiringSecureCoding: false) {
                UserDefaults.standard.set(colorData, forKey: "clipFontColor")
            }
        }
    }

    // ClipDrawer Proximity Zoom
    @Published var clipZoomRadiusHidden: CGFloat = 100 {
        didSet { UserDefaults.standard.set(clipZoomRadiusHidden, forKey: "clipZoomRadiusHidden") }
    }
    @Published var clipZoomRadiusVisible: CGFloat = 150 {
        didSet { UserDefaults.standard.set(clipZoomRadiusVisible, forKey: "clipZoomRadiusVisible") }
    }
    @Published var clipZoomMax: CGFloat = 3.0 {
        didSet { UserDefaults.standard.set(clipZoomMax, forKey: "clipZoomMax") }
    }
    @Published var clipZoomMin: CGFloat = 1.4 {
        didSet { UserDefaults.standard.set(clipZoomMin, forKey: "clipZoomMin") }
    }
    @Published var clipZoomPower: CGFloat = 2.0 {
        didSet { UserDefaults.standard.set(clipZoomPower, forKey: "clipZoomPower") }
    }
    @Published var clipShowDebugCircles: Bool = false {
        didSet { UserDefaults.standard.set(clipShowDebugCircles, forKey: "clipShowDebugCircles") }
    }

    // ClipDrawer Behavior
    @Published var clipEdgeSensitivity: CGFloat = 0.03 {
        didSet { UserDefaults.standard.set(clipEdgeSensitivity, forKey: "clipEdgeSensitivity") }
    }
    @Published var clipDrawerAutoHideDelay: Double = 4.0 {
        didSet { UserDefaults.standard.set(clipDrawerAutoHideDelay, forKey: "clipDrawerAutoHideDelay") }
    }
    @Published var clipSlideOutDistance: CGFloat = 20 {
        didSet { UserDefaults.standard.set(clipSlideOutDistance, forKey: "clipSlideOutDistance") }
    }
    @Published var clipPeekWidth: CGFloat = 4 {
        didSet { UserDefaults.standard.set(clipPeekWidth, forKey: "clipPeekWidth") }
    }
    @Published var clipBumpPeekDistance: CGFloat = -16 {
        didSet { UserDefaults.standard.set(clipBumpPeekDistance, forKey: "clipBumpPeekDistance") }
    }
    @Published var clipDrawerCornerRadiusHidden: CGFloat = 8 {
        didSet { UserDefaults.standard.set(clipDrawerCornerRadiusHidden, forKey: "clipDrawerCornerRadiusHidden") }
    }
    @Published var clipDrawerCornerRadiusVisible: CGFloat = 20 {
        didSet { UserDefaults.standard.set(clipDrawerCornerRadiusVisible, forKey: "clipDrawerCornerRadiusVisible") }
    }
    @Published var clipDrawerWidth: CGFloat = 46 {
        didSet { UserDefaults.standard.set(clipDrawerWidth, forKey: "clipDrawerWidth") }
    }
    @Published var clipEdgeDistance: CGFloat = 0 {
        didSet { UserDefaults.standard.set(clipEdgeDistance, forKey: "clipEdgeDistance") }
    }
    @Published var clipShadowStrength: CGFloat = 0 {
        didSet { UserDefaults.standard.set(clipShadowStrength, forKey: "clipShadowStrength") }
    }
    @Published var clipDrawerShadowEnabled: Bool = true {
        didSet { UserDefaults.standard.set(clipDrawerShadowEnabled, forKey: "clipDrawerShadowEnabled") }
    }
    @Published var clipBumpShadowEnabled: Bool = true {
        didSet { UserDefaults.standard.set(clipBumpShadowEnabled, forKey: "clipBumpShadowEnabled") }
    }
    @Published var clipBumpHeight: CGFloat = 80 {
        didSet { UserDefaults.standard.set(clipBumpHeight, forKey: "clipBumpHeight") }
    }
    @Published var clipBumpMinHeight: CGFloat = 15 {
        didSet { UserDefaults.standard.set(clipBumpMinHeight, forKey: "clipBumpMinHeight") }
    }
    @Published var clipBumpCornerRadiusHidden: CGFloat = 6 {
        didSet { UserDefaults.standard.set(clipBumpCornerRadiusHidden, forKey: "clipBumpCornerRadiusHidden") }
    }
    @Published var clipBumpCornerRadiusVisible: CGFloat = 20 {
        didSet { UserDefaults.standard.set(clipBumpCornerRadiusVisible, forKey: "clipBumpCornerRadiusVisible") }
    }
    @Published var clipLeftIconPosition: String = "bottom" {
        didSet { UserDefaults.standard.set(clipLeftIconPosition, forKey: "clipLeftIconPosition") }
    }
    @Published var clipRightIconPosition: String = "top" {
        didSet { UserDefaults.standard.set(clipRightIconPosition, forKey: "clipRightIconPosition") }
    }

    init() {
        if let savedFontSize = UserDefaults.standard.object(forKey: "fontSize") as? CGFloat {
            fontSize = savedFontSize
        }
        if let savedPomodoroMode = UserDefaults.standard.object(forKey: "pomodoroMode") as? Bool {
            pomodoroMode = savedPomodoroMode
        }
        if let savedDefaultTime = UserDefaults.standard.object(forKey: "defaultPomodoroTime") as? TimeInterval {
            defaultPomodoroTime = savedDefaultTime
        }
        // --- Load Reminders Sync Setting ---
        if let savedRemindersSyncEnabled = UserDefaults.standard.object(forKey: "remindersSyncEnabled") as? Bool {
            remindersSyncEnabled = savedRemindersSyncEnabled
        }
        // --- Load Sleep Cycle Settings ---
        if let interval = UserDefaults.standard.object(forKey: "sleepIntervalMinutes") as? Int {
            sleepIntervalMinutes = interval
        }
        if let duration = UserDefaults.standard.object(forKey: "sleepDurationMinutes") as? Int {
            sleepDurationMinutes = duration
        }
        // Load useGlobalMouseTracking setting
        if let savedUseGlobalMouseTracking = UserDefaults.standard.object(forKey: "useGlobalMouseTracking") as? Bool {
            useGlobalMouseTracking = savedUseGlobalMouseTracking
        } else {
            // If not saved, it defaults to true (as set in property declaration), so ensure UserDefaults reflects this for next time
             UserDefaults.standard.set(useGlobalMouseTracking, forKey: "useGlobalMouseTracking")
        }

        // Load launch at login setting
        if let savedLaunchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool {
            launchAtLogin = savedLaunchAtLogin
        }

        // Load ClipDrawer settings
        if let saved = UserDefaults.standard.object(forKey: "clipDrawerEnabled") as? Bool {
            clipDrawerEnabled = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipDrawerLeftEnabled") as? Bool {
            clipDrawerLeftEnabled = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipDrawerRightEnabled") as? Bool {
            clipDrawerRightEnabled = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipDrawerShowAppIcons") as? Bool {
            clipDrawerShowAppIcons = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipDrawerDeleteOnDragOut") as? Bool {
            clipDrawerDeleteOnDragOut = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipDrawerShowAdvancedSettings") as? Bool {
            clipDrawerShowAdvancedSettings = saved
        }

        // Load ClipDrawer visual tuning settings
        if let saved = UserDefaults.standard.object(forKey: "clipFontSize") as? CGFloat {
            clipFontSize = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipPaddingHorizontal") as? CGFloat {
            clipPaddingHorizontal = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipPaddingVertical") as? CGFloat {
            clipPaddingVertical = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipAppIconSize") as? CGFloat {
            clipAppIconSize = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipZoomRadiusHidden") as? CGFloat {
            clipZoomRadiusHidden = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipZoomRadiusVisible") as? CGFloat {
            clipZoomRadiusVisible = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipZoomMax") as? CGFloat {
            clipZoomMax = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipZoomMin") as? CGFloat {
            clipZoomMin = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipZoomPower") as? CGFloat {
            clipZoomPower = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipEdgeSensitivity") as? CGFloat {
            clipEdgeSensitivity = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipDrawerAutoHideDelay") as? Double {
            clipDrawerAutoHideDelay = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipSlideOutDistance") as? CGFloat {
            clipSlideOutDistance = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipPeekWidth") as? CGFloat {
            clipPeekWidth = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipBumpPeekDistance") as? CGFloat {
            clipBumpPeekDistance = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipShowDebugCircles") as? Bool {
            clipShowDebugCircles = saved
        }
        if let colorData = UserDefaults.standard.data(forKey: "clipBackgroundColor"),
           let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            clipBackgroundColor = Color(nsColor)
        }
        if let colorData = UserDefaults.standard.data(forKey: "clipFontColor"),
           let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            clipFontColor = Color(nsColor)
        }

        // Activate global mouse tracking if enabled at startup
        if useGlobalMouseTracking {
            NotificationCenter.default.post(name: Notification.Name("StartGlobalMouseTracking"), object: nil)
        }
        // (If you want to persist fontColor, you could convert it to/from a hex string or Data.)
    }

    private func setLaunchAtLogin(enabled: Bool) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.aricfedida.BrainFish"

        if #available(macOS 13.0, *) {
            // Use SMAppService for macOS 13+
            let service = SMAppService.mainApp

            do {
                if enabled {
                    if service.status == .notRegistered {
                        try service.register()
                    }
                } else {
                    if service.status == .enabled {
                        try service.unregister()
                    }
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            }
        } else {
            // DEPRECATED: Use LSSharedFileList for older macOS versions (pre-13)
            // This API is deprecated but maintained for backward compatibility
            // TODO: Remove when minimum deployment target is macOS 13+
            let itemURL = URL(fileURLWithPath: Bundle.main.bundlePath)
            if enabled {
                guard let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue() else {
                    print("Failed to create login items list")
                    return
                }
                LSSharedFileListInsertItemURL(
                    loginItems,
                    kLSSharedFileListItemLast.takeRetainedValue(),
                    nil,
                    nil,
                    itemURL as CFURL,
                    nil,
                    nil
                )
            } else {
                // Remove from login items
                guard let loginItems = LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue(),
                      let loginItemsArray = LSSharedFileListCopySnapshot(loginItems, nil)?.takeRetainedValue() as? [LSSharedFileListItem] else {
                    print("Failed to access login items")
                    return
                }
                for item in loginItemsArray {
                    if let resolvedURL = LSSharedFileListItemCopyResolvedURL(item, 0, nil)?.takeRetainedValue() as URL? {
                        if resolvedURL == itemURL {
                            LSSharedFileListItemRemove(loginItems, item)
                        }
                    }
                }
            }
        }
    }
}


// MARK: - System Sleep Observer
class SystemSleepObserver: NSObject, ObservableObject {
    @Published var isSystemAsleep: Bool = false

    override init() {
        super.init()
        setupObservers()
    }

    deinit {
        removeObservers()
    }

    private func setupObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(screenSaverStarted),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(screenSaverStopped),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    private func removeObservers() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func systemWillSleep(_ notification: Notification) {
        isSystemAsleep = true
    }

    @objc private func systemDidWake(_ notification: Notification) {
        isSystemAsleep = false
    }

    @objc private func screenSaverStarted(_ notification: Notification) {
        isSystemAsleep = true
    }

    @objc private func screenSaverStopped(_ notification: Notification) {
        isSystemAsleep = false
    }
}

// MARK: - ContentView
struct ContentView: View {
    @EnvironmentObject var appData: AppData
    @EnvironmentObject var appSettings: AppSettings

    @State private var isSleeping: Bool = false
    @State private var lastSleepToggleTime: Date = Date()
    @State private var sleepTimer: Timer? = nil
    @State private var mousePosition: NSPoint = .zero
    // --- Global Mouse Tracking ---
    @StateObject private var globalMouseTracker = GlobalMouseTracker()
    @StateObject private var systemSleepObserver = SystemSleepObserver()
    // --- ClipDrawer ---
    @StateObject private var clipDrawerManager = ClipDrawerManager()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // --- Place TimelineView directly ---
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let currentTime = timeline.date.timeIntervalSinceReferenceDate
                    let geometry = geometry // Ensure geometry is captured if it's not already in scope for the ZStack replacement
                    // Inner ZStack for fish
                    ZStack {
                    
                    if appSettings.pomodoroMode {
                        if !appData.tasks.isEmpty {
                            let index = appData.currentPomodoroTaskIndex % appData.tasks.count
                            let task = appData.tasks[index] // Get the task object
                            TaskSnakeView(task: task, // Use the task object
                                          taskIndex: index,
                                          totalTasks: 1,
                                          time: currentTime,
                                          size: geometry.size,
                                          isSleeping: isSleeping || systemSleepObserver.isSystemAsleep,
                                          mousePosition: mousePosition,
                                          useGlobalMouseTracking: appSettings.useGlobalMouseTracking,
                                          globalMousePosition: globalMouseTracker.globalMousePosition,
                                          appSettings: appSettings)
                                .id(task.id) // ADDED EXPLICIT ID
                        }
                        // No tasks in Pomodoro mode - nothing to display
                    } else {
                        ForEach(appData.tasks.indices, id: \.self) { index in
                            let task = appData.tasks[index]
                            TaskSnakeView(task: task,
                                          taskIndex: index,
                                          totalTasks: appData.tasks.count,
                                          time: currentTime,
                                          size: geometry.size,
                                          isSleeping: isSleeping || systemSleepObserver.isSystemAsleep,
                                          mousePosition: mousePosition,
                                          useGlobalMouseTracking: appSettings.useGlobalMouseTracking,
                                          globalMousePosition: globalMouseTracker.globalMousePosition,
                                          appSettings: appSettings)
                                .id(task.id)
                        }
                    }
                    }
                    .drawingGroup() // Composite the entire timeline view to reduce recursion
                } // End TimelineView
                // --- Apply TrackingAreaView as background ---
                .background(
                    TrackingAreaView(mousePosition: $mousePosition)
                )
                .allowsHitTesting(false) // Fish area ignores mouse clicks/drags

                // --- ClipDrawer Overlays ---
                if appSettings.clipDrawerEnabled {
                    HStack(spacing: 0) {
                        if appSettings.clipDrawerLeftEnabled {
                            ClipDrawer(side: .left, screenWidth: geometry.size.width, screenHeight: geometry.size.height, manager: clipDrawerManager)
                                .environmentObject(appSettings)
                        }
                        Spacer()
                        if appSettings.clipDrawerRightEnabled {
                            ClipDrawer(side: .right, screenWidth: geometry.size.width, screenHeight: geometry.size.height, manager: clipDrawerManager)
                                .environmentObject(appSettings)
                        }
                    }
                    .allowsHitTesting(true)
                }

                // Delete zone just below menu bar (30-60px from top) - only visible when dragging
                if clipDrawerManager.isDraggingClip {
                    DeleteZoneView(clipDrawerManager: clipDrawerManager)
                        .frame(height: 30)
                        .frame(maxWidth: .infinity)
                        .position(x: geometry.size.width / 2, y: 45) // Position at 30-60px from top
                        .allowsHitTesting(true)
                        .transition(.opacity)
                }
            } // End outer ZStack
            .onChange(of: globalMouseTracker.globalMousePosition) { oldValue, newValue in
                // Update clip drawer manager with mouse position for proximity zoom
                clipDrawerManager.globalMousePosition = newValue

                // Edge detection for drawer activation using global mouse position
                let smallEdgeZone = geometry.size.width * appSettings.clipEdgeSensitivity
                let expandedEdgeZone: CGFloat = 60  // Keep visible when drawer is out

                // Use larger zone when drawer is already visible
                let leftZoneWidth = clipDrawerManager.isLeftDrawerVisible ? expandedEdgeZone : smallEdgeZone
                let rightZoneWidth = clipDrawerManager.isRightDrawerVisible ? expandedEdgeZone : smallEdgeZone

                let isNearLeftEdge = newValue.x <= leftZoneWidth
                let isNearRightEdge = newValue.x >= geometry.size.width - rightZoneWidth

                if appSettings.clipDrawerEnabled {
                    // Update auto-hide delay from settings
                    clipDrawerManager.autoHideDelay = appSettings.clipDrawerAutoHideDelay

                    // Calculate parameters for proximity check
                    let topMargin: CGFloat = 100
                    let bottomMargin: CGFloat = 150
                    let usableHeight = geometry.size.height - topMargin - bottomMargin
                    let drawerWidth = appSettings.clipDrawerWidth

                    if appSettings.clipDrawerLeftEnabled {
                        // Calculate left drawer offset
                        let shouldBeExtended = clipDrawerManager.isLeftDrawerVisible || clipDrawerManager.isLeftClipsVisible
                        let offset: CGFloat = shouldBeExtended ? appSettings.clipSlideOutDistance : appSettings.clipPeekWidth
                        let xOffset: CGFloat = (-drawerWidth + offset) + appSettings.clipEdgeDistance

                        // Check if mouse is near clips using visible radius
                        let isNearClips = clipDrawerManager.isMouseNearClips(
                            side: .left,
                            screenWidth: geometry.size.width,
                            screenHeight: geometry.size.height,
                            drawerWidth: drawerWidth,
                            visibleRadius: appSettings.clipZoomRadiusVisible,
                            topMargin: topMargin,
                            usableHeight: usableHeight,
                            xOffset: xOffset
                        )

                        if isNearLeftEdge || isNearClips {
                            // Mouse near edge or clips - show drawer and clips immediately
                            clipDrawerManager.isLeftDrawerVisible = true
                            clipDrawerManager.isLeftClipsVisible = true
                            clipDrawerManager.cancelLeftClipsHide()
                        } else {
                            // Mouse moved away - hide drawer immediately, schedule clip fade out
                            clipDrawerManager.isLeftDrawerVisible = false
                            if clipDrawerManager.isLeftClipsVisible {
                                clipDrawerManager.scheduleLeftClipsHide()
                            }
                        }
                    }
                    if appSettings.clipDrawerRightEnabled {
                        // Calculate right drawer offset
                        let shouldBeExtended = clipDrawerManager.isRightDrawerVisible || clipDrawerManager.isRightClipsVisible
                        let offset: CGFloat = shouldBeExtended ? appSettings.clipSlideOutDistance : appSettings.clipPeekWidth
                        let xOffset: CGFloat = (drawerWidth - offset) - appSettings.clipEdgeDistance

                        // Check if mouse is near clips using visible radius
                        let isNearClips = clipDrawerManager.isMouseNearClips(
                            side: .right,
                            screenWidth: geometry.size.width,
                            screenHeight: geometry.size.height,
                            drawerWidth: drawerWidth,
                            visibleRadius: appSettings.clipZoomRadiusVisible,
                            topMargin: topMargin,
                            usableHeight: usableHeight,
                            xOffset: xOffset
                        )

                        if isNearRightEdge || isNearClips {
                            // Mouse near edge or clips - show drawer and clips immediately
                            clipDrawerManager.isRightDrawerVisible = true
                            clipDrawerManager.isRightClipsVisible = true
                            clipDrawerManager.cancelRightClipsHide()
                        } else {
                            // Mouse moved away - hide drawer immediately, schedule clip fade out
                            clipDrawerManager.isRightDrawerVisible = false
                            if clipDrawerManager.isRightClipsVisible {
                                clipDrawerManager.scheduleRightClipsHide()
                            }
                        }
                    }
                }
            }
        } // End GeometryReader
        .ignoresSafeArea()
        .onAppear {
            setupSleepTimer()
            if appSettings.useGlobalMouseTracking {
                globalMouseTracker.start()
            }
        }
        .onChange(of: systemSleepObserver.isSystemAsleep) { _, isAsleep in
            if isAsleep {
                sleepTimer?.invalidate()
            } else {
                // Reset sleep cycle timing after system wake
                lastSleepToggleTime = Date()
                setupSleepTimer()
            }
        }
        .onChange(of: appSettings.sleepIntervalMinutes) { _, _ in
            setupSleepTimer()
        }
        .onChange(of: appSettings.useGlobalMouseTracking) { _, enabled in
            if enabled {
                globalMouseTracker.start()
            } else {
                globalMouseTracker.stop()
            }
        }
        .onChange(of: appSettings.sleepDurationMinutes) { _, _ in
            // No immediate action needed, timer restart covers it
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) {
            _ in
            // Invalidate existing timers on screen change
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StartGlobalMouseTracking"))) { _ in
            globalMouseTracker.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("StopGlobalMouseTracking"))) { _ in
            globalMouseTracker.stop()
        }
        .onDisappear {
            globalMouseTracker.stop()
            sleepTimer?.invalidate()
            sleepTimer = nil
        }
    }

    func setupSleepTimer() {
        sleepTimer?.invalidate()
        // Check every minute
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            checkSleepState()
        }
        // Initial check
        checkSleepState()
    }
    
    func checkSleepState() {
        // Skip sleep cycling if system is asleep
        guard !systemSleepObserver.isSystemAsleep else { return }

        let now = Date()
        // Ensure settings are positive to prevent division by zero or negative intervals
        let intervalMinutes = max(1, appSettings.sleepIntervalMinutes)
        let durationMinutes = max(1, appSettings.sleepDurationMinutes)

        let intervalSeconds = TimeInterval(intervalMinutes * 60)
        let durationSeconds = TimeInterval(durationMinutes * 60)

        let timeSinceLastToggle = now.timeIntervalSince(lastSleepToggleTime)

        if isSleeping {
            // Currently sleeping, check if duration has passed
            if timeSinceLastToggle >= durationSeconds {
                isSleeping = false
                lastSleepToggleTime = now // Mark wake-up time
            }
        } else {
            // Currently awake, check if interval has passed
            if timeSinceLastToggle >= intervalSeconds {
                isSleeping = true
                lastSleepToggleTime = now // Mark sleep start time
            }
        }
    }

    
    func timeString(from seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}


// MARK: - TaskSnakeView (Fixed)
struct TaskSnakeView: View {
    let task: Task
    let taskIndex: Int
    let totalTasks: Int
    let time: TimeInterval // Current time from ContentView's TimelineView
    let size: CGSize
    let isSleeping: Bool
    let mousePosition: NSPoint
    let useGlobalMouseTracking: Bool
    let globalMousePosition: NSPoint
    let appSettings: AppSettings

    @State private var initialTime: TimeInterval? = nil
    @State private var lastUpdateTime: TimeInterval?
    @State private var currentPosition: CGFloat = 0
    @State private var speedMultiplier: Double = 2.0
    @State private var baseSpeedMultiplier: Double = 1.0
    @State private var targetBaseSpeed: Double = 1.0
    @State private var lastSpeedChangeTime: TimeInterval = 0
    @State private var hasStarted: Bool = false
    @State private var isMouseCurrentlyOver: Bool = false // Added for hit-testing
    @State private var startDelay: TimeInterval = 0
    @State private var shouldCompleteSwim: Bool = false
    @State private var hasCompletedSwim: Bool = false

    // Performance optimization: cache computed values
    @State private var cachedDisplayText: String = ""
    @State private var cachedTextWidth: CGFloat = 0
    @State private var cachedLetterSpacing: CGFloat = 0

    private let speedChangeInterval: TimeInterval = 5.0
    private let spawnStaggerInterval: TimeInterval = 1.0
    private let spawnJitter: TimeInterval = 0.25

    var body: some View {
        let elapsedTime = (initialTime != nil) ? (time - initialTime!) : 0

        // Update cache when necessary
        let newDisplayText = appSettings.pomodoroMode
            ? "\(task.title) (\(timeString(from: task.remainingTime)))"
            : task.title
        if newDisplayText != cachedDisplayText {
            DispatchQueue.main.async {
                cachedDisplayText = newDisplayText
                cachedLetterSpacing = appSettings.fontSize * FishConstants.letterSpacingMultiplier
                cachedTextWidth = cachedLetterSpacing * CGFloat(newDisplayText.count)
            }
        }

        return Group {
            // Show fish if: not completed swim OR (not sleeping and not should complete)
            if !hasCompletedSwim && (!isSleeping || shouldCompleteSwim) {
                fishBodyView(
                    task: task,
                    taskIndex: taskIndex,
                    totalTasks: totalTasks,
                    size: size,
                    elapsedTime: elapsedTime,
                    currentPosition: currentPosition,
                    isMouseCurrentlyOver: self.isMouseCurrentlyOver,
                    currentSpeedMultiplier: self.speedMultiplier,
                    currentBaseSpeed: self.baseSpeedMultiplier,
                    appSettings: appSettings,
                    cachedTextWidth: cachedTextWidth)
                    .opacity(hasStarted ? 1 : 0)
            } else {
                EmptyView()
            }
        }
        .onChange(of: time) { _, newTime in
            updatePositionAndSpeed(newTime: newTime)
        }
        .onChange(of: isSleeping) { _, nowSleeping in
            if nowSleeping && hasStarted && !hasCompletedSwim {
                // Start completing swim when sleep begins
                shouldCompleteSwim = true
            } else if !nowSleeping {
                // Reset for wake cycle - all fish should start fresh from right edge
                shouldCompleteSwim = false
                hasCompletedSwim = false
                // Always reset position and state when waking up
                currentPosition = size.width
                hasStarted = false
                // Reset timing for staggered spawn
                initialTime = time
                lastUpdateTime = time
                lastSpeedChangeTime = time
                // Recalculate spawn delay for proper staggering
                startDelay = spawnDelay(for: taskIndex)
            }
        }
        .onAppear {            if self.initialTime == nil {
                self.initialTime = time
                self.lastSpeedChangeTime = time
                self.currentPosition = self.size.width
                let delay = spawnDelay(for: taskIndex)
                self.startDelay = delay
            }
            updatePositionAndSpeed(newTime: time)
        }
    }

    func updatePositionAndSpeed(newTime: TimeInterval) {
        guard let initialTime else { return }

        let elapsed = newTime - initialTime
        if elapsed < startDelay {
            currentPosition = size.width
            lastUpdateTime = newTime
            return
        }
        if !hasStarted {
            let spacingOffset = size.width * 0.12 * CGFloat(taskIndex)
            currentPosition = size.width + spacingOffset
            hasStarted = true
            lastUpdateTime = newTime
            lastSpeedChangeTime = newTime
        }

        guard let previousUpdate = lastUpdateTime else {
            lastUpdateTime = newTime
            return
        }

        // If system is asleep (but not regular sleep), pause animation
        if isSleeping && !shouldCompleteSwim {
            lastUpdateTime = newTime
            return
        }

        let deltaTime = newTime - previousUpdate
        if deltaTime <= 0 { return }

        if newTime - lastSpeedChangeTime >= speedChangeInterval {
            targetBaseSpeed = Double.random(in: 0.6...1.4)
            lastSpeedChangeTime = newTime
        }

        let speedEaseRate = 0.5
        if abs(baseSpeedMultiplier - targetBaseSpeed) > 0.01 {
            let speedChangeAmount = speedEaseRate * deltaTime
            if baseSpeedMultiplier < targetBaseSpeed {
                baseSpeedMultiplier = min(baseSpeedMultiplier + speedChangeAmount, targetBaseSpeed)
            } else {
                baseSpeedMultiplier = max(baseSpeedMultiplier - speedChangeAmount, targetBaseSpeed)
            }
        }

        // Use cached width for better performance
        let textWidth = cachedTextWidth

        let effectiveMousePosition = appSettings.useGlobalMouseTracking ? self.globalMousePosition : mousePosition
        let fishCenterX = currentPosition + (textWidth / 2.0)
        let fishCenterY = FishAnimationUtils.wormPath(taskIndex: taskIndex,
                                                     totalTasks: totalTasks,
                                                     letterX: fishCenterX,
                                                     in: size)
        let flippedMouseY = size.height - effectiveMousePosition.y
        let adjustedMousePos = CGPoint(x: effectiveMousePosition.x, y: flippedMouseY)
        let hitTestRadiusX = textWidth / 2.0
        let hitTestRadiusY = appSettings.fontSize
        let dx = adjustedMousePos.x - fishCenterX
        let dy = adjustedMousePos.y - fishCenterY
        let normalizedDxSq = pow(dx / hitTestRadiusX, 2)
        let normalizedDySq = pow(dy / hitTestRadiusY, 2)
        self.isMouseCurrentlyOver = (normalizedDxSq + normalizedDySq) < 1.0

        var targetSpeedMultiplier = speedMultiplier
        if self.isMouseCurrentlyOver {
            task.accelerationEndTime = Date().addingTimeInterval(2.0)
            targetSpeedMultiplier = 2.5
        } else {
            if let endTime = task.accelerationEndTime, Date() < endTime {
                targetSpeedMultiplier = 2.5
            } else {
                targetSpeedMultiplier = 1.0
                if task.accelerationEndTime != nil {
                    task.accelerationEndTime = nil
                }
            }
        }

        let changeRate = 5.0
        if abs(speedMultiplier - targetSpeedMultiplier) > 0.01 {
            let changeAmount = changeRate * deltaTime
            if speedMultiplier < targetSpeedMultiplier {
                speedMultiplier = min(speedMultiplier + changeAmount, targetSpeedMultiplier)
            } else {
                speedMultiplier = max(speedMultiplier - changeAmount, targetSpeedMultiplier)
            }
        }

        let randomSpeedFactor = 0.9 + 0.2 * FishAnimationUtils.randomForLoop(taskIndex, seed: 2.0)
        let baseSpeed = task.speed * randomSpeedFactor * baseSpeedMultiplier
        let currentSpeed = baseSpeed * speedMultiplier
        let distanceThisFrame = currentSpeed * deltaTime

        currentPosition -= distanceThisFrame
        if currentPosition < -textWidth {
            if shouldCompleteSwim {
                // Fish has completed its swim off screen during sleep
                hasCompletedSwim = true
                currentPosition = size.width // Reset for next cycle
            } else if !isSleeping {
                // Normal wrap around when awake
                currentPosition = size.width
            }
        }

        lastUpdateTime = newTime
    }
    private func spawnDelay(for index: Int) -> TimeInterval {
        if index == 0 { return 0 }
        let jitterFactor = FishAnimationUtils.randomForLoop(index, seed: 42.0)
        let baseDelay = spawnStaggerInterval * Double(index)
        let jitter = (jitterFactor - 0.5) * spawnJitter
        return max(0, baseDelay + jitter)
    }
}

// MARK: - Fish Body View Struct Definition (Updated)
struct fishBodyView: View {
    let task: Task
    let taskIndex: Int
    let totalTasks: Int
    let size: CGSize
    let elapsedTime: TimeInterval
    let currentPosition: CGFloat
    let isMouseCurrentlyOver: Bool
    let currentSpeedMultiplier: Double
    let currentBaseSpeed: Double
    let appSettings: AppSettings
    let cachedTextWidth: CGFloat

    var body: some View {
        let displayText: String = appSettings.pomodoroMode
            ? "\(task.title) (\(timeString(from: task.remainingTime)))"
            : task.title
        let letters = Array(displayText)
        let letterSpacing = appSettings.fontSize * FishConstants.letterSpacingMultiplier
        let textWidth = cachedTextWidth > 0 ? cachedTextWidth : letterSpacing * CGFloat(letters.count)

        // Helper function to vary font scale based on letter index.
        func letterScale(for i: Int, total: Int) -> CGFloat {
            guard total > 1 else { return 1.0 }
            let norm = CGFloat(i) / CGFloat(total - 1)
            let pectoralNorm: CGFloat = 0.1
            let ventralNorm: CGFloat = 0.3
            if norm <= pectoralNorm {
                // Increase from 1.0 to 1.1 linearly.
                return 1.0 + 0.1 * (norm / pectoralNorm)
            } else if norm <= ventralNorm {
                // Decrease from 1.1 to 0.9 linearly.
                let factor = (norm - pectoralNorm) / (ventralNorm - pectoralNorm)
                return 1.1 - 0.2 * factor
            } else {
                // Decrease linearly from 0.9 at ventralNorm to 0.8 at tail.
                let factor = (norm - ventralNorm) / (1 - ventralNorm)
                return 0.9 - 0.4 * factor
            }
        }
        
        // Use currentPosition directly instead of calculating from elapsed time
        let headX = currentPosition
        
        // --- Distance calculation for mouse avoidance (elliptical, centered on fish middle) ---
        // REMOVE local calculation of nearMouse, dx, dy, ellipticalDistance, etc.
        // These are no longer needed as isMouseCurrentlyOver is passed in.
        // let fishCenterX = currentPosition + (textWidth / 2.0)
        // let fishCenterPoint = CGPoint(x: fishCenterX, y: wormPath(letterX: fishCenterX))
        // let flippedMouseY = size.height - mousePosition.y
        // let adjustedMousePos = CGPoint(x: mousePosition.x, y: flippedMouseY)
        // 
        // let dx = fishCenterPoint.x - adjustedMousePos.x
        // let dy = fishCenterPoint.y - adjustedMousePos.y
        // 
        // let avoidanceRadiusX = fishTotalWidth * 0.75 
        // let avoidanceRadiusY = max(appSettings.fontSize * 2.0, 60.0) 
        // 
        // let normalizedDx = dx / avoidanceRadiusX
        // let normalizedDy = dy / avoidanceRadiusY
        // let ellipticalDistance = sqrt(normalizedDx * normalizedDx + normalizedDy * normalizedDy)
        // let nearMouse = self.isMouseCurrentlyOver // Replaced above

        // --- Debug Prints (throttled) ---
        // Suppressed per-fish debug output to focus on spawn diagnostics.

        // Calculate wormPath positions outside of modifiers to reduce recursion

        return ZStack {
            // Fish head
            Image("koi-head")
                .resizable()
                .scaledToFit()
                .frame(width: appSettings.fontSize * FishConstants.headSizeMultiplier,
                       height: appSettings.fontSize * FishConstants.headSizeMultiplier)
                .rotationEffect(FishAnimationUtils.tangentAngle(taskIndex: taskIndex,
                                                                totalTasks: totalTasks,
                                                                at: headX,
                                                                in: size),
                               anchor: .trailing)
                .position(x: headX - appSettings.fontSize,
                          y: FishAnimationUtils.wormPath(taskIndex: taskIndex,
                                                          totalTasks: totalTasks,
                                                          letterX: headX,
                                                          in: size))

            // Pectoral fins
            Image("koi-fins-pectoral")
                .resizable()
                .scaledToFit()
                .frame(width: appSettings.fontSize * FishConstants.pectoralFinSizeMultiplier)
                .rotationEffect(FishAnimationUtils.tangentAngle(taskIndex: taskIndex,
                                                                totalTasks: totalTasks,
                                                                at: headX + FishConstants.pectoralFinPosition * textWidth,
                                                                in: size))
                .position(x: headX + FishConstants.pectoralFinPosition * textWidth,
                          y: FishAnimationUtils.wormPath(taskIndex: taskIndex,
                                                          totalTasks: totalTasks,
                                                          letterX: headX + FishConstants.pectoralFinPosition * textWidth,
                                                          in: size))

            // Ventral fins
            Image("koi-fins-ventral")
                .resizable()
                .scaledToFit()
                .frame(width: appSettings.fontSize * FishConstants.ventralFinSizeMultiplier)
                .rotationEffect(FishAnimationUtils.tangentAngle(taskIndex: taskIndex,
                                                                totalTasks: totalTasks,
                                                                at: headX + FishConstants.ventralFinPosition * textWidth,
                                                                in: size))
                .position(x: headX + FishConstants.ventralFinPosition * textWidth,
                          y: FishAnimationUtils.wormPath(taskIndex: taskIndex,
                                                          totalTasks: totalTasks,
                                                          letterX: headX + FishConstants.ventralFinPosition * textWidth,
                                                          in: size))

            // Tail
            Image("koi-tail")
                .resizable()
                .scaledToFit()
                .frame(width: appSettings.fontSize * FishConstants.tailSizeMultiplier,
                       height: appSettings.fontSize * FishConstants.tailSizeMultiplier)
                .rotationEffect(FishAnimationUtils.tangentAngle(taskIndex: taskIndex,
                                                                totalTasks: totalTasks,
                                                                at: headX + textWidth,
                                                                in: size),
                               anchor: .leading)
                .position(x: headX + textWidth + appSettings.fontSize * FishConstants.tailOffsetMultiplier,
                          y: FishAnimationUtils.wormPath(taskIndex: taskIndex,
                                                          totalTasks: totalTasks,
                                                          letterX: headX + textWidth,
                                                          in: size))

            // The text letters with variable font sizes
            ForEach(letters.indices, id: \.self) { i in
                let letterX = headX + CGFloat(i) * letterSpacing
                let letterY = FishAnimationUtils.wormPath(taskIndex: taskIndex,
                                                          totalTasks: totalTasks,
                                                          letterX: letterX,
                                                          in: size)
                let scale = FishAnimationUtils.letterScale(for: i, total: letters.count)
                Text(String(letters[i]))
                    .font(.system(size: appSettings.fontSize * scale, weight: .bold, design: .rounded))
                    .modifier(OutlineText(color: .black, lineWidth: FishConstants.outlineWidth))
                    .foregroundColor(appSettings.fontColor)
                    .position(x: letterX, y: letterY)
                    .rotationEffect(.degrees(0))
                    .animation(nil, value: elapsedTime)
            }
        }
        .drawingGroup() // Composite to reduce layout recursion
    }
}


    // MARK: - Pomodoro Timer & Controls

    // --- Removed duplicate global function definition ---

struct TaskListHeaderView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        HStack {
            Text("Task List")
                .font(.headline)
            Spacer()
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .padding(.bottom, 5)
    }
}


// MARK: - TaskListInputView
struct TaskListInputView: View {
    @Binding var newTaskTitle: String
    let onSubmit: () -> Void

    var body: some View {
        HStack {
            TextField("New Task", text: $newTaskTitle)
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: newTaskTitle) { _, newValue in
                    if newValue.count > FishConstants.maxTaskTitleLength {
                        newTaskTitle = String(newValue.prefix(FishConstants.maxTaskTitleLength))
                    }
                }
            Button("Add", action: onSubmit)
        }
    }
}


// MARK: - TaskListView
struct TaskListView: View {
    @EnvironmentObject var appData: AppData
    @EnvironmentObject var appSettings: AppSettings
    @State private var newTaskTitle: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TaskListHeaderView()
            
            TaskListContentView()
            
            TaskListInputView(newTaskTitle: $newTaskTitle, onSubmit: addTask)
        }
        .padding()
        .frame(minWidth: 300, minHeight: 400)
        .onAppear(perform: setupWindow)
        .onDisappear(perform: resetWindow)
    }
    
    private func setupWindow() {
        if let window = NSApp.keyWindow {
            window.ignoresMouseEvents = false
        }
    }
    
    private func resetWindow() {
        if let window = NSApp.keyWindow {
            window.ignoresMouseEvents = true
        }
    }
    
    private func addTask() {
        guard !newTaskTitle.isEmpty else { return }
        let newTask = Task(
            title: newTaskTitle,
            startOffset: Double.random(in: 0...1),
            speed: 50,
            remainingTime: appSettings.defaultPomodoroTime
        )
        withAnimation {
            appData.tasks.append(newTask)
        }
        newTaskTitle = ""
    }
}


// MARK: - TaskRowView
struct TaskRowView: View {
    @ObservedObject var task: Task
    @EnvironmentObject var appData: AppData
    @EnvironmentObject var appSettings: AppSettings
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.horizontal.3")
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Group {
                if isEditing {
                    TextField("Task", text: $task.title)
                        .focused($isFocused)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            isEditing = false
                        }
                        .onAppear {
                            isFocused = true
                        }
                } else {
                    Text(task.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isEditing = true
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if appSettings.pomodoroMode {
                Button(action: {
                    task.remainingTime = appSettings.defaultPomodoroTime
                }) {
                    Text("🍅")
                }
                .buttonStyle(.plain)
                
                Text(timeString(from: task.remainingTime))
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 60, alignment: .trailing)
            }
            
            Button(action: {
                withAnimation {
                    if let idx = appData.tasks.firstIndex(where: { $0.id == task.id }) {
                        appData.tasks.remove(at: idx)
                    }
                }
            }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .background(Color.clear)
    }
    
    func timeString(from seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}


struct TaskListContentView: View {
    @EnvironmentObject var appData: AppData
    @State private var draggedTaskId: UUID?
    
    var body: some View {
        List {
            ForEach(appData.tasks) { task in
                TaskRowContent(task: task, draggedTaskId: $draggedTaskId)
            }
        }
        .listStyle(PlainListStyle())
    }
}

// Separated component for task row content
struct TaskRowContent: View {
    let task: Task
    @Binding var draggedTaskId: UUID?
    @EnvironmentObject var appData: AppData
    
    var body: some View {
        TaskRowView(task: task)
            .id(task.id)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
            .listRowBackground(backgroundFor(taskId: task.id))
            .draggable(task.id) {
                DragPreviewView(title: task.title)
            }
            .dropDestination(for: UUID.self) { items, _ in
                handleDrop(of: items, onto: task.id)
            } isTargeted: { isTargeted in
                if isTargeted {
                    draggedTaskId = task.id
                }
            }
    }
    
    private func backgroundFor(taskId: UUID) -> Color {
        draggedTaskId == taskId ? Color.accentColor.opacity(0.1) : Color.clear
    }
    
    private func handleDrop(of items: [UUID], onto targetId: UUID) -> Bool {
        guard let droppedId = items.first,
              let fromIndex = appData.tasks.firstIndex(where: { $0.id == droppedId }),
              let toIndex = appData.tasks.firstIndex(where: { $0.id == targetId }) else {
            return false
        }
        
        if fromIndex != toIndex {
            withAnimation {
                let task = appData.tasks.remove(at: fromIndex)
                appData.tasks.insert(task, at: toIndex)
            }
        }
        draggedTaskId = nil
        return true
    }
}

// Drag preview component
struct DragPreviewView: View {
    let title: String
    
    var body: some View {
        HStack {
            Image(systemName: "line.horizontal.3")
            Text(title)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}


// MARK: - ClipBump View
struct ClipBump: View {
    let clip: Clip
    let side: DrawerSide
    let proximityScale: CGFloat
    let showAppIcon: Bool
    let isDrawerVisible: Bool
    @Binding var hoveredClipID: UUID?
    let onDragEnded: (Bool) -> Void // Receives: wasModifierKeyPressed
    @ObservedObject var manager: ClipDrawerManager
    @EnvironmentObject var appSettings: AppSettings

    @State private var isHovered: Bool = false
    @State private var showPreview: Bool = false
    @State private var hoverTimer: Timer?

    // Helper to load app icon
    private func loadAppIcon() -> NSImage? {
        guard let bundleID = clip.sourceAppBundleID else {
            // No bundle ID - return default document icon
            if let defaultIcon = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Document") {
                return defaultIcon
            }
            return nil
        }

        NSLog("📱 Loading icon for bundle ID: %@", bundleID)

        // Try to get app URL from bundle ID
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            NSLog("   ✓ Icon loaded from: %@", appURL.path)
            return icon
        }

        NSLog("   ✗ Could not find app URL for bundle ID: %@", bundleID)
        // Could not load app icon - return default document icon
        if let defaultIcon = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Document") {
            return defaultIcon
        }
        return nil
    }

    var body: some View {
        // Left drawer: rotate 90° (counterclockwise), Right drawer: rotate -90° (clockwise)
        let rotation: Double = side == .left ? 90 : -90

        // Icon positioning logic based on settings:
        // Left drawer (90° CCW): top = trailing (right) before rotation, bottom = leading (left)
        // Right drawer (-90° CW): top = leading (left) before rotation, bottom = trailing (right)
        let iconPosition = side == .left ? appSettings.clipLeftIconPosition : appSettings.clipRightIconPosition
        let alignment: Alignment = side == .left
            ? (iconPosition == "top" ? .trailing : .leading)
            : (iconPosition == "top" ? .leading : .trailing)

        // Add extra padding to make space for the icon
        let hasIcon = showAppIcon && loadAppIcon() != nil
        let iconSpacing: CGFloat = hasIcon ? appSettings.clipAppIconSize + 2 : 0

        // Dynamic corner radius based on drawer visibility
        let cornerRadius = isDrawerVisible ? appSettings.clipBumpCornerRadiusVisible : appSettings.clipBumpCornerRadiusHidden

        ZStack(alignment: alignment) {
            // Display image thumbnail or text based on content type
            if let image = clip.content.image {
                // Image clip - show thumbnail with counter-rotation to maintain original orientation
                Image(nsImage: image)
                    .renderingMode(.original) // Preserve transparency and original rendering
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: appSettings.clipBumpMinHeight * 1.5, height: appSettings.clipBumpMinHeight)
                    .clipped()
                    .cornerRadius(cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(appSettings.clipFontColor.opacity(0.3), lineWidth: 1)
                    )
                    .rotationEffect(.degrees(-rotation)) // Counter-rotate to keep image upright
            } else {
                // Text clip - show text
                Text(clip.preview)
                    .font(.system(size: appSettings.clipFontSize, weight: .medium, design: .rounded))
                    .foregroundColor(appSettings.clipFontColor)
                    .padding(.horizontal, appSettings.clipPaddingHorizontal)
                    .padding(.vertical, appSettings.clipPaddingVertical)
                    .padding(alignment == .trailing ? .trailing : .leading, iconSpacing) // Make space for icon
                    .frame(minHeight: appSettings.clipBumpMinHeight)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(appSettings.clipBackgroundColor)
                    )

                // App icon overlay (before rotation) - only if setting is enabled
                if showAppIcon, let appIcon = loadAppIcon() {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: appSettings.clipAppIconSize, height: appSettings.clipAppIconSize)
                        .cornerRadius(2)
                        .padding(2) // Small padding from edge
                }
            }
        }
        .rotationEffect(.degrees(rotation))
        .scaleEffect(proximityScale) // Dock-style zoom based on mouse proximity
        .shadow(
            color: appSettings.clipBumpShadowEnabled ? Color.black.opacity(0.1 * appSettings.clipShadowStrength / 3.0) : Color.clear,
            radius: appSettings.clipBumpShadowEnabled ? appSettings.clipShadowStrength : 0,
            x: 0,
            y: 0
        )
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: proximityScale)
        .onDrag {
            // Set drag state flag
            manager.isDraggingClip = true

            // Safety timer: reset flag after 10 seconds if drag doesn't complete
            // (handles cases where drag is cancelled or dropped outside app)
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                if manager.isDraggingClip {
                    NSLog("⚠️ Drag timeout - resetting isDraggingClip flag")
                    manager.isDraggingClip = false
                }
            }

            // Return the draggable content with custom preview
            NSLog("🎯 Starting drag for clip: %@", clip.preview)

            let provider: NSItemProvider

            // Create appropriate provider based on content type
            if let image = clip.content.image {
                // Image content - provide NSImage
                provider = NSItemProvider(object: image)
                provider.suggestedName = "image.png"
            } else {
                // Text content - provide NSString
                let words = clip.preview.components(separatedBy: .whitespaces)
                let previewText = words.isEmpty ? "..." : "\(words[0])..."
                provider = NSItemProvider(object: clip.content.fullText as NSString)
                provider.suggestedName = previewText
            }

            return provider
        }
        .onHover { hovering in
            isHovered = hovering
            hoveredClipID = hovering ? clip.id : nil

            // Handle preview timer
            if hovering {
                // Start 3-second timer for preview
                hoverTimer?.invalidate()
                hoverTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                    showPreview = true
                }
            } else {
                // Cancel timer and hide preview when hover ends
                hoverTimer?.invalidate()
                hoverTimer = nil
                showPreview = false
            }
        }
        .contextMenu {
            Button(action: {
                onDragEnded(false) // Trigger deletion without modifier key
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .overlay(
            Group {
                if showPreview {
                    // Preview bubble showing full clip content
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)

                        // Show image or text based on content type
                        if let image = clip.content.image {
                            Image(nsImage: image)
                                .renderingMode(.original) // Preserve transparency and original rendering
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 800, maxHeight: 600)
                                .cornerRadius(4)
                        } else {
                            Text(clip.content.fullText)
                                .font(.system(size: 12))
                                .foregroundColor(.primary)
                                .lineLimit(nil)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .frame(width: 800)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
                    )
                    .offset(x: side == .left ? 60 : -60, y: 0)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .animation(.easeInOut(duration: 0.2), value: showPreview)
                }
            }
        )
    }
}

// MARK: - Delete Zone View
struct DeleteZoneView: View {
    @ObservedObject var clipDrawerManager: ClipDrawerManager
    @State private var isTargeted: Bool = false

    var body: some View {
        ZStack {
            // Always show translucent red bar, brighter when targeted
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.red.opacity(isTargeted ? 0.7 : 0.25))
                .overlay(
                    HStack(spacing: 8) {
                        Image(systemName: isTargeted ? "trash.fill" : "trash")
                            .font(.system(size: isTargeted ? 18 : 14))
                        if isTargeted {
                            Text("Drop to Delete")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                )
                .padding(.horizontal, 20)
        }
        .onDrop(of: [.text, .plainText, .html, .rtf, .image, .png, .jpeg, .tiff], isTargeted: $isTargeted) { providers, location in
            print("🗑️ DELETE ZONE: Drop received at location \(location)")

            // Extract the dropped content to identify which clip
            for provider in providers {
                // Try image types first
                let imageTypes = ["public.png", "public.jpeg", "public.tiff", "public.image"]
                for typeId in imageTypes {
                    if provider.hasItemConformingToTypeIdentifier(typeId) {
                        provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, error in
                            if let error = error {
                                print("❌ Error loading dropped image: \(error)")
                                return
                            }

                            var imageData: Data?
                            if let data = item as? Data {
                                imageData = data
                            } else if let url = item as? URL {
                                imageData = try? Data(contentsOf: url)
                            }

                            if let imageData = imageData {
                                DispatchQueue.main.async {
                                    // Reset drag state
                                    self.clipDrawerManager.isDraggingClip = false

                                    // Find and delete the clip with matching image data
                                    if let clipToDelete = self.clipDrawerManager.clips.first(where: {
                                        if case .image(let data) = $0.content {
                                            return data == imageData
                                        }
                                        return false
                                    }) {
                                        print("🗑️ Deleting image clip in delete zone")

                                        // Play poof sound
                                        let poofPath = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/dock/poof.aif"
                                        if let poofSound = NSSound(contentsOfFile: poofPath, byReference: true) {
                                            poofSound.play()
                                        } else if let funkSound = NSSound(named: "Funk") {
                                            funkSound.play()
                                        }

                                        self.clipDrawerManager.removeClip(clipToDelete)
                                    }
                                }
                            }
                        }
                        break
                    }
                }

                // Try text types if no image found
                let textTypes = ["public.utf8-plain-text", "public.plain-text", "public.text"]
                for typeId in textTypes {
                    if provider.hasItemConformingToTypeIdentifier(typeId) {
                        provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, error in
                            if let error = error {
                                print("❌ Error loading dropped item: \(error)")
                                return
                            }

                            var text: String?
                            if let data = item as? Data {
                                text = String(data: data, encoding: .utf8)
                            } else if let string = item as? String {
                                text = string
                            }

                            if let text = text {
                                DispatchQueue.main.async {
                                    // Reset drag state
                                    self.clipDrawerManager.isDraggingClip = false

                                    // Find and delete the clip with matching text
                                    if let clipToDelete = self.clipDrawerManager.clips.first(where: { $0.content.fullText == text }) {
                                        print("🗑️ Deleting clip in delete zone: \(text.prefix(30))")

                                        // Play poof sound (try macOS dock poof first, fallback to Funk)
                                        let poofPath = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/dock/poof.aif"
                                        if let poofSound = NSSound(contentsOfFile: poofPath, byReference: true) {
                                            poofSound.play()
                                        } else if let funkSound = NSSound(named: "Funk") {
                                            funkSound.play()
                                        }

                                        self.clipDrawerManager.removeClip(clipToDelete)
                                    }
                                }
                            }
                        }
                        break
                    }
                }
            }

            return true
        }
        .onChange(of: isTargeted) { oldValue, newValue in
            print("🗑️ DELETE ZONE: isTargeted changed from \(oldValue) to \(newValue)")
        }
    }
}

// MARK: - ClipWithProximityZoom Helper View
struct ClipWithProximityZoom: View {
    let clip: Clip
    let side: DrawerSide
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let topMargin: CGFloat
    let zoneHeight: CGFloat
    let drawerWidth: CGFloat
    let bumpWidth: CGFloat
    let xOffset: CGFloat
    let showAppIcon: Bool
    let isDrawerVisible: Bool
    @ObservedObject var manager: ClipDrawerManager
    @EnvironmentObject var appSettings: AppSettings
    let handleClipDragEnd: (Bool) -> Void

    var body: some View {
        let clipY = topMargin + CGFloat(clip.dropZone) * zoneHeight

        // Calculate proximity-based zoom (dock-style)
        let clipScreenX: CGFloat = side == .left
            ? drawerWidth / 2 + xOffset
            : screenWidth - drawerWidth / 2 + xOffset

        // CRITICAL FIX: Convert clipY from view coords (top=0) to screen coords (bottom=0)
        // globalMousePosition Y is already in screen coords (flipped in GlobalMouseTracker)
        let clipScreenY = screenHeight - clipY

        let mouseX = manager.globalMousePosition.x
        let mouseY = manager.globalMousePosition.y

        let dx = mouseX - clipScreenX
        let dy = mouseY - clipScreenY
        let distance = sqrt(dx * dx + dy * dy)

        // Proximity zoom with sigmoid curve using settings
        // Only apply zoom when within the visible radius
        // The hidden radius controls the sigmoid steepness
        let zoomScale: CGFloat
        if distance > appSettings.clipZoomRadiusVisible {
            // Outside visible radius - no zoom, use minimum
            zoomScale = appSettings.clipZoomMin
        } else {
            // Within visible radius - apply sigmoid zoom using hidden radius for steepness
            let normalizedDistance = distance / appSettings.clipZoomRadiusHidden
            // Use power parameter for tunable sigmoid steepness
            let falloff = 1.0 / (1.0 + pow(normalizedDistance, appSettings.clipZoomPower))
            zoomScale = appSettings.clipZoomMin + (appSettings.clipZoomMax - appSettings.clipZoomMin) * falloff
        }

        // Calculate clip X position - clips always peek out the same amount
        // regardless of drawer visibility (drawer state shouldn't affect clip position)
        // Counter the drawer's offset so clips stay in the same screen position
        // Position clips at the center of the drawer
        let clipPeekOffset = appSettings.clipBumpPeekDistance
        let clipXPos: CGFloat = (side == .left
            ? drawerWidth / 2 + clipPeekOffset
            : drawerWidth / 2 - clipPeekOffset) - xOffset

        return ZStack {
            ClipBump(
                clip: clip,
                side: side,
                proximityScale: zoomScale,
                showAppIcon: showAppIcon,
                isDrawerVisible: isDrawerVisible,
                hoveredClipID: $manager.hoveredClipID,
                onDragEnded: handleClipDragEnd,
                manager: manager
            )
            .frame(width: bumpWidth)
            .position(x: clipXPos, y: clipY)

            // Debug circles showing BOTH zoom radiuses
            if appSettings.clipShowDebugCircles {
                // Hidden radius circle (blue)
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    .frame(width: appSettings.clipZoomRadiusHidden * 2, height: appSettings.clipZoomRadiusHidden * 2)
                    .position(x: clipXPos, y: clipY)
                    .allowsHitTesting(false)

                // Visible radius circle (red)
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    .frame(width: appSettings.clipZoomRadiusVisible * 2, height: appSettings.clipZoomRadiusVisible * 2)
                    .position(x: clipXPos, y: clipY)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - ClipDrawer View
struct ClipDrawer: View {
    let side: DrawerSide
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    @ObservedObject var manager: ClipDrawerManager
    @EnvironmentObject var appSettings: AppSettings

    @State private var isTargeted: Bool = false

    var isVisible: Bool {
        side == .left ? manager.isLeftDrawerVisible : manager.isRightDrawerVisible
    }

    var areClipsVisible: Bool {
        side == .left ? manager.isLeftClipsVisible : manager.isRightClipsVisible
    }

    var sideClips: [Clip] {
        manager.clipsForSide(side)
    }

    var body: some View {
        let drawerWidth: CGFloat = appSettings.clipDrawerWidth
        let bumpWidth: CGFloat = appSettings.clipBumpHeight

        let topMargin: CGFloat = 100
        let bottomMargin: CGFloat = 150
        let usableHeight = screenHeight - topMargin - bottomMargin
        let zoneHeight = usableHeight / 32

        // Calculate offset from edge using settings (includes edge distance)
        // Drawer extension is based only on isVisible
        let offset: CGFloat = isVisible ? appSettings.clipSlideOutDistance : appSettings.clipPeekWidth
        let cornerRadius: CGFloat = isVisible ? appSettings.clipDrawerCornerRadiusVisible : appSettings.clipDrawerCornerRadiusHidden
        let xOffset: CGFloat = (side == .left ? -drawerWidth + offset : drawerWidth - offset) +
                               (side == .left ? appSettings.clipEdgeDistance : -appSettings.clipEdgeDistance)

        return ZStack(alignment: .topLeading) {
            // Visual background with drop zone - accepts drops across entire drawer
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(appSettings.clipBackgroundColor)
                .shadow(
                    color: appSettings.clipDrawerShadowEnabled ? Color.black.opacity(0.1 * appSettings.clipShadowStrength / 3.0) : Color.clear,
                    radius: appSettings.clipDrawerShadowEnabled ? appSettings.clipShadowStrength : 0,
                    x: 0,
                    y: 0
                )
                .frame(width: drawerWidth, height: usableHeight)
                .offset(y: topMargin)
                .onDrop(of: [.text, .plainText, .html, .rtf, .image, .png, .jpeg, .tiff], isTargeted: $isTargeted) { providers, location in
                    handleDropOnDrawer(providers: providers, location: location, topMargin: topMargin, usableHeight: usableHeight)
                    return true
                }

            // Clips positioned by zone - draggable
            ForEach(sideClips) { clip in
                ClipWithProximityZoom(
                    clip: clip,
                    side: side,
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                    topMargin: topMargin,
                    zoneHeight: zoneHeight,
                    drawerWidth: drawerWidth,
                    bumpWidth: bumpWidth,
                    xOffset: xOffset,
                    showAppIcon: appSettings.clipDrawerShowAppIcons,
                    isDrawerVisible: isVisible,
                    manager: manager,
                    handleClipDragEnd: { modifierPressed in
                        manager.isDraggingClip = false
                        handleClipDragEnd(clip: clip, modifierPressed: modifierPressed)
                    }
                )
                .environmentObject(appSettings)
                .opacity(areClipsVisible ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3), value: areClipsVisible)
                .allowsHitTesting(areClipsVisible)
            }
        }
        .frame(width: drawerWidth, height: screenHeight)
        .offset(x: xOffset)
        .opacity(isVisible || areClipsVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: xOffset)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .animation(.easeInOut(duration: 0.3), value: areClipsVisible)
        .allowsHitTesting(isVisible || areClipsVisible)
    }

    private func handleDrop(providers: [NSItemProvider], dropSide: DrawerSide) {
        for provider in providers {
            print("📦 Provider types: \(provider.registeredTypeIdentifiers)")

            // Try multiple text type identifiers
            let textTypes = ["public.utf8-plain-text", "public.plain-text", "public.text"]
            for typeId in textTypes {
                if provider.hasItemConformingToTypeIdentifier(typeId) {
                    provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, error in
                        if let error = error {
                            print("❌ Error loading item: \(error)")
                            return
                        }

                        var text: String?
                        if let data = item as? Data {
                            text = String(data: data, encoding: .utf8)
                        } else if let string = item as? String {
                            text = string
                        }

                        if let text = text {
                            print("✅ Successfully extracted text: \(text.prefix(50))...")
                            print("   Creating clip for \(dropSide.rawValue) drawer")
                            DispatchQueue.main.async {
                                let clip = Clip(content: .text(text), side: dropSide)
                                print("   ✓ Clip created with side: \(clip.side.rawValue)")
                                self.manager.addClip(clip)
                                print("   ✓ Total clips now: \(self.manager.clips.count)")
                                print("   ✓ Clips on left: \(self.manager.clipsForSide(.left).count)")
                                print("   ✓ Clips on right: \(self.manager.clipsForSide(.right).count)")
                            }
                            return
                        }
                    }
                    break // Only process first matching type
                }
            }

            // Try URL
            if provider.hasItemConformingToTypeIdentifier("public.url") {
                provider.loadItem(forTypeIdentifier: "public.url", options: nil) { item, error in
                    var url: URL?
                    if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let urlItem = item as? URL {
                        url = urlItem
                    }

                    if let url = url {
                        print("✅ Successfully extracted URL: \(url)")
                        print("   Creating clip for \(dropSide.rawValue) drawer")
                        DispatchQueue.main.async {
                            let clip = Clip(content: .url(url), side: dropSide)
                            print("   ✓ Clip created with side: \(clip.side.rawValue)")
                            self.manager.addClip(clip)
                        }
                    }
                }
            }
        }
    }

    private func handleDropOnDrawer(providers: [NSItemProvider], location: CGPoint, topMargin: CGFloat, usableHeight: CGFloat) {
        for provider in providers {
            // Try image types first (they're more specific)
            let imageTypes = ["public.png", "public.jpeg", "public.tiff", "public.image"]
            for typeId in imageTypes {
                if provider.hasItemConformingToTypeIdentifier(typeId) {
                    provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, error in
                        if let error = error {
                            print("❌ Error loading dropped image: \(error)")
                            return
                        }

                        var imageData: Data?
                        if let data = item as? Data {
                            imageData = data
                        } else if let url = item as? URL {
                            imageData = try? Data(contentsOf: url)
                        }

                        if let imageData = imageData {
                            // Calculate drop zone based on Y position
                            let dropY = location.y - topMargin
                            let zoneHeight = usableHeight / 32
                            let dropZone = max(0, min(31, Int(dropY / zoneHeight)))

                            // Get frontmost app info - but NOT if dragging from BrainFish itself
                            let frontmostApp = NSWorkspace.shared.frontmostApplication
                            let isBrainFish = frontmostApp?.bundleIdentifier == Bundle.main.bundleIdentifier
                            let appBundleID = isBrainFish ? nil : frontmostApp?.bundleIdentifier
                            let appName = isBrainFish ? nil : frontmostApp?.localizedName

                            print("✅ Drop on drawer: zone=\(dropZone), image=\(imageData.count) bytes, fromBrainFish=\(isBrainFish)")

                            DispatchQueue.main.async {
                                // Reset drag state when dropping on drawer
                                self.manager.isDraggingClip = false

                                let clip = Clip(
                                    content: .image(imageData),
                                    side: self.side,
                                    dropZone: dropZone,
                                    sourceAppBundleID: appBundleID,
                                    sourceAppName: appName
                                )
                                self.manager.addClip(clip)
                            }
                            return
                        }
                    }
                    break
                }
            }

            // Try HTML types (from Apple Notes when dragging a note object)
            let htmlTypes = ["public.html", "com.apple.notes.html"]
            for typeId in htmlTypes {
                if provider.hasItemConformingToTypeIdentifier(typeId) {
                    provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, error in
                        if let error = error {
                            print("❌ Error loading dropped HTML: \(error)")
                            return
                        }

                        var text: String?
                        if let data = item as? Data {
                            // Convert HTML to plain text
                            let attributedString = try? NSAttributedString(
                                data: data,
                                options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
                                documentAttributes: nil
                            )
                            text = attributedString?.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        } else if let string = item as? String {
                            // If HTML came as string, try to parse it
                            if let htmlData = string.data(using: .utf8) {
                                let attributedString = try? NSAttributedString(
                                    data: htmlData,
                                    options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
                                    documentAttributes: nil
                                )
                                text = attributedString?.string.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }

                        if let text = text, !text.isEmpty {
                            // Calculate drop zone based on Y position
                            let dropY = location.y - topMargin
                            let zoneHeight = usableHeight / 32
                            let dropZone = max(0, min(31, Int(dropY / zoneHeight)))

                            // Get frontmost app info - but NOT if dragging from BrainFish itself
                            let frontmostApp = NSWorkspace.shared.frontmostApplication
                            let isBrainFish = frontmostApp?.bundleIdentifier == Bundle.main.bundleIdentifier
                            let appBundleID = isBrainFish ? nil : frontmostApp?.bundleIdentifier
                            let appName = isBrainFish ? nil : frontmostApp?.localizedName

                            print("✅ Drop on drawer (HTML/Note): zone=\(dropZone), text=\(text.prefix(30)), fromBrainFish=\(isBrainFish)")

                            DispatchQueue.main.async {
                                // Reset drag state when dropping on drawer
                                self.manager.isDraggingClip = false

                                let clip = Clip(
                                    content: .text(text),
                                    side: self.side,
                                    dropZone: dropZone,
                                    sourceAppBundleID: appBundleID,
                                    sourceAppName: appName
                                )
                                self.manager.addClip(clip)
                            }
                            return
                        }
                    }
                    break
                }
            }

            // Try RTF types (from TextEdit, etc.)
            let rtfTypes = ["public.rtf", "com.apple.rtf"]
            for typeId in rtfTypes {
                if provider.hasItemConformingToTypeIdentifier(typeId) {
                    provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, error in
                        if let error = error {
                            print("❌ Error loading dropped RTF: \(error)")
                            return
                        }

                        var text: String?
                        if let data = item as? Data {
                            // Convert RTF to plain text
                            let attributedString = try? NSAttributedString(
                                data: data,
                                options: [.documentType: NSAttributedString.DocumentType.rtf],
                                documentAttributes: nil
                            )
                            text = attributedString?.string
                        }

                        if let text = text {
                            // Calculate drop zone based on Y position
                            let dropY = location.y - topMargin
                            let zoneHeight = usableHeight / 32
                            let dropZone = max(0, min(31, Int(dropY / zoneHeight)))

                            // Get frontmost app info - but NOT if dragging from BrainFish itself
                            let frontmostApp = NSWorkspace.shared.frontmostApplication
                            let isBrainFish = frontmostApp?.bundleIdentifier == Bundle.main.bundleIdentifier
                            let appBundleID = isBrainFish ? nil : frontmostApp?.bundleIdentifier
                            let appName = isBrainFish ? nil : frontmostApp?.localizedName

                            print("✅ Drop on drawer (RTF): zone=\(dropZone), text=\(text.prefix(30)), fromBrainFish=\(isBrainFish)")

                            DispatchQueue.main.async {
                                // Reset drag state when dropping on drawer
                                self.manager.isDraggingClip = false

                                let clip = Clip(
                                    content: .text(text),
                                    side: self.side,
                                    dropZone: dropZone,
                                    sourceAppBundleID: appBundleID,
                                    sourceAppName: appName
                                )
                                self.manager.addClip(clip)
                            }
                            return
                        }
                    }
                    break
                }
            }

            // Try text types if no RTF or image was found
            let textTypes = ["public.utf8-plain-text", "public.plain-text", "public.text"]
            for typeId in textTypes {
                if provider.hasItemConformingToTypeIdentifier(typeId) {
                    provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, error in
                        if let error = error {
                            print("❌ Error loading dropped item: \(error)")
                            return
                        }

                        var text: String?
                        if let data = item as? Data {
                            text = String(data: data, encoding: .utf8)
                        } else if let string = item as? String {
                            text = string
                        }

                        if let text = text {
                            // Calculate drop zone based on Y position
                            let dropY = location.y - topMargin
                            let zoneHeight = usableHeight / 32
                            let dropZone = max(0, min(31, Int(dropY / zoneHeight)))

                            // Get frontmost app info - but NOT if dragging from BrainFish itself
                            let frontmostApp = NSWorkspace.shared.frontmostApplication
                            let isBrainFish = frontmostApp?.bundleIdentifier == Bundle.main.bundleIdentifier
                            let appBundleID = isBrainFish ? nil : frontmostApp?.bundleIdentifier
                            let appName = isBrainFish ? nil : frontmostApp?.localizedName

                            print("✅ Drop on drawer: zone=\(dropZone), text=\(text.prefix(30)), fromBrainFish=\(isBrainFish)")

                            DispatchQueue.main.async {
                                // Reset drag state when dropping on drawer
                                self.manager.isDraggingClip = false

                                let clip = Clip(
                                    content: .text(text),
                                    side: self.side,
                                    dropZone: dropZone,
                                    sourceAppBundleID: appBundleID,
                                    sourceAppName: appName
                                )
                                self.manager.addClip(clip)
                            }
                            return
                        }
                    }
                    break // Only process first matching type
                }
            }
        }
    }

    private func handleClipDragEnd(clip: Clip, modifierPressed: Bool) {
        let shouldDelete: Bool
        if appSettings.clipDrawerDeleteOnDragOut {
            // Default: delete on drag, keep with modifier
            shouldDelete = !modifierPressed
        } else {
            // Reversed: keep on drag, delete with modifier
            shouldDelete = modifierPressed
        }

        if shouldDelete {
            manager.removeClip(clip)
        }
    }
}

// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var appData: AppData
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab: Int = 0

    func copySettingsToClipboard() {
        let settings: [String: Any] = [
            "clipFontSize": appSettings.clipFontSize,
            "clipPaddingHorizontal": appSettings.clipPaddingHorizontal,
            "clipPaddingVertical": appSettings.clipPaddingVertical,
            "clipAppIconSize": appSettings.clipAppIconSize,
            "clipZoomRadiusHidden": appSettings.clipZoomRadiusHidden,
            "clipZoomRadiusVisible": appSettings.clipZoomRadiusVisible,
            "clipZoomMax": appSettings.clipZoomMax,
            "clipZoomMin": appSettings.clipZoomMin,
            "clipZoomPower": appSettings.clipZoomPower,
            "clipEdgeSensitivity": appSettings.clipEdgeSensitivity,
            "clipSlideOutDistance": appSettings.clipSlideOutDistance,
            "clipPeekWidth": appSettings.clipPeekWidth,
            "clipBumpPeekDistance": appSettings.clipBumpPeekDistance,
            "clipShowDebugCircles": appSettings.clipShowDebugCircles,
            "clipDrawerCornerRadiusHidden": appSettings.clipDrawerCornerRadiusHidden,
            "clipDrawerCornerRadiusVisible": appSettings.clipDrawerCornerRadiusVisible,
            "clipDrawerWidth": appSettings.clipDrawerWidth,
            "clipEdgeDistance": appSettings.clipEdgeDistance,
            "clipShadowStrength": appSettings.clipShadowStrength,
            "clipDrawerShadowEnabled": appSettings.clipDrawerShadowEnabled,
            "clipBumpShadowEnabled": appSettings.clipBumpShadowEnabled,
            "clipBumpHeight": appSettings.clipBumpHeight,
            "clipBumpMinHeight": appSettings.clipBumpMinHeight,
            "clipBumpCornerRadiusHidden": appSettings.clipBumpCornerRadiusHidden,
            "clipBumpCornerRadiusVisible": appSettings.clipBumpCornerRadiusVisible,
            "clipLeftIconPosition": appSettings.clipLeftIconPosition,
            "clipRightIconPosition": appSettings.clipRightIconPosition
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(jsonString, forType: .string)
        }
    }

    var body: some View {
        VStack {
            // Top bar with title and Close button
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding(.bottom, 5)

            TabView(selection: $selectedTab) {
                // Fish Tab
                Form {
                    ColorPicker("Font Color", selection: $appSettings.fontColor)
                    HStack {
                        Text("Font Size")
                        Slider(value: $appSettings.fontSize, in: 10...40, step: 1)
                        Text("\(Int(appSettings.fontSize))")
                    }
                    Toggle("Pomodoro Mode", isOn: $appSettings.pomodoroMode)
                    if appSettings.pomodoroMode {
                        HStack {
                            Text("Default Time (minutes)")
                            TextField("", value: Binding(
                                get: { appSettings.defaultPomodoroTime / 60 },
                                set: { appSettings.defaultPomodoroTime = $0 * 60 }
                            ), formatter: NumberFormatter())
                            .frame(width: 50)
                        }
                    }
                    Toggle("Global Mouse Tracking", isOn: $appSettings.useGlobalMouseTracking)
                        .onChange(of: appSettings.useGlobalMouseTracking) { _, enabled in
                            if enabled {
                                NotificationCenter.default.post(name: Notification.Name("StartGlobalMouseTracking"), object: nil)
                            } else {
                                NotificationCenter.default.post(name: Notification.Name("StopGlobalMouseTracking"), object: nil)
                            }
                        }
                    // --- Sleep Cycle Settings ---
                    Stepper("Sleep every \(appSettings.sleepIntervalMinutes) minutes",
                            value: $appSettings.sleepIntervalMinutes, in: 1...60)
                        .onChange(of: appSettings.sleepIntervalMinutes) { _, _ in
                            if appSettings.sleepIntervalMinutes < 1 { appSettings.sleepIntervalMinutes = 1 }
                        }
                    Stepper("Sleep for \(appSettings.sleepDurationMinutes) minutes",
                            value: $appSettings.sleepDurationMinutes, in: 1...60)
                        .onChange(of: appSettings.sleepDurationMinutes) { _, _ in
                            if appSettings.sleepDurationMinutes < 1 { appSettings.sleepDurationMinutes = 1 }
                        }

                    // --- Reminders Sync ---
                    Toggle("Sync with Apple Reminders", isOn: $appSettings.remindersSyncEnabled)
                        .onChange(of: appSettings.remindersSyncEnabled) { _, enabled in
                            if enabled {
                                _Concurrency.Task {
                                    let authorized = await appData.enableRemindersSync()
                                    if !authorized {
                                        // Permission denied, turn the toggle back off
                                        await MainActor.run {
                                            appSettings.remindersSyncEnabled = false
                                        }
                                    }
                                }
                            }
                        }

                    Toggle("Launch at Login", isOn: $appSettings.launchAtLogin)
                }
                .tabItem {
                    Label("Fish", systemImage: "fish.fill")
                }
                .tag(0)

                // ClipDrawer Tab
                Form {
                    Toggle("Enable ClipDrawer", isOn: $appSettings.clipDrawerEnabled)

                    if appSettings.clipDrawerEnabled {
                        Toggle("Left Edge", isOn: $appSettings.clipDrawerLeftEnabled)
                        Toggle("Right Edge", isOn: $appSettings.clipDrawerRightEnabled)
                        Toggle("Show App Icons", isOn: $appSettings.clipDrawerShowAppIcons)

                        Divider()

                        HStack {
                            Text("Auto-hide Delay")
                            Slider(value: $appSettings.clipDrawerAutoHideDelay, in: 1...10, step: 0.5)
                                .frame(width: 200)
                            Text("\(String(format: "%.1f", appSettings.clipDrawerAutoHideDelay))s")
                                .frame(width: 40)
                        }

                        Divider()

                        Picker("Drag Behavior", selection: $appSettings.clipDrawerDeleteOnDragOut) {
                            Text("Delete on drag out").tag(true)
                            Text("Keep on drag out").tag(false)
                        }
                        .pickerStyle(.radioGroup)

                        Text("Hold Shift/Alt to reverse behavior")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        Toggle("Show Advanced Settings", isOn: $appSettings.clipDrawerShowAdvancedSettings)

                        // Two column layout for advanced settings
                        if appSettings.clipDrawerShowAdvancedSettings {
                            HStack(alignment: .top, spacing: 20) {
                            // Left Column
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Visual Tuning").font(.headline)

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Font Size")
                                        Text("clipFontSize")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipFontSize, in: 4...16, step: 1)
                                        .frame(width: 150)
                                    Text("\(Int(appSettings.clipFontSize))")
                                        .frame(width: 30)
                                }

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("H Padding")
                                        Text("clipPaddingHorizontal")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipPaddingHorizontal, in: 2...30, step: 1)
                                        .frame(width: 150)
                                    Text("\(Int(appSettings.clipPaddingHorizontal))")
                                        .frame(width: 30)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("V Padding")
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .help("clipPaddingVertical")
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipPaddingVertical, in: 0...10, step: 1)
                                        .frame(width: 150)
                                    Text("\(Int(appSettings.clipPaddingVertical))")
                                        .frame(width: 30)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Icon Size")
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .help("clipAppIconSize")
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipAppIconSize, in: 8...24, step: 1)
                                        .frame(width: 150)
                                    Text("\(Int(appSettings.clipAppIconSize))")
                                        .frame(width: 30)
                                }

                                ColorPicker("BG Color", selection: $appSettings.clipBackgroundColor)
                                ColorPicker("Font Color", selection: $appSettings.clipFontColor)

                                Divider()
                                Text("Proximity Zoom").font(.headline)

                                HStack(spacing: 4) {
                                    Toggle("Debug Circles", isOn: $appSettings.clipShowDebugCircles)
                                    Image(systemName: "questionmark.circle")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .help("clipShowDebugCircles")
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Radius (Hidden)")
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .help("clipZoomRadiusHidden")
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipZoomRadiusHidden, in: 100...1200, step: 50)
                                        .frame(width: 120)
                                    Text("\(Int(appSettings.clipZoomRadiusHidden))")
                                        .frame(width: 40)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Radius (Visible)")
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .help("clipZoomRadiusVisible")
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipZoomRadiusVisible, in: 100...1200, step: 50)
                                        .frame(width: 120)
                                    Text("\(Int(appSettings.clipZoomRadiusVisible))")
                                        .frame(width: 40)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Power")
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .help("clipZoomPower")
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipZoomPower, in: 1.0...6.0, step: 0.5)
                                        .frame(width: 150)
                                    Text(String(format: "%.1f", appSettings.clipZoomPower))
                                        .frame(width: 30)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Max Zoom")
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .help("clipZoomMax")
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipZoomMax, in: 1.0...3.0, step: 0.1)
                                        .frame(width: 150)
                                    Text(String(format: "%.1fx", appSettings.clipZoomMax))
                                        .frame(width: 30)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Min Zoom")
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .help("clipZoomMin")
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipZoomMin, in: 0.5...1.5, step: 0.1)
                                        .frame(width: 150)
                                    Text(String(format: "%.1fx", appSettings.clipZoomMin))
                                        .frame(width: 30)
                                }
                            }

                            // Right Column
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Behavior").font(.headline)

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Edge Sensitivity")
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .help("clipEdgeSensitivity")
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipEdgeSensitivity, in: 0.005...0.05, step: 0.005)
                                        .frame(width: 120)
                                    Text(String(format: "%.1f%%", appSettings.clipEdgeSensitivity * 100))
                                        .frame(width: 40)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Slide Out Dist")
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .help("clipSlideOutDistance")
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipSlideOutDistance, in: 10...50, step: 2)
                                        .frame(width: 150)
                                    Text("\(Int(appSettings.clipSlideOutDistance))")
                                        .frame(width: 30)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Peek (Drawer)")
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .help("clipPeekWidth")
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipPeekWidth, in: 2...20, step: 2)
                                        .frame(width: 150)
                                    Text("\(Int(appSettings.clipPeekWidth))")
                                        .frame(width: 30)
                                }

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Peek (Clip)")
                                        Text("clipBumpPeekDistance")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipBumpPeekDistance, in: -20...30, step: 2)
                                        .frame(width: 150)
                                    Text("\(Int(appSettings.clipBumpPeekDistance))")
                                        .frame(width: 30)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Corner R (Hidden)")
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .help("clipDrawerCornerRadiusHidden")
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipDrawerCornerRadiusHidden, in: 0...20, step: 1)
                                        .frame(width: 120)
                                    Text("\(Int(appSettings.clipDrawerCornerRadiusHidden))")
                                        .frame(width: 30)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Corner R (Visible)")
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .help("clipDrawerCornerRadiusVisible")
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipDrawerCornerRadiusVisible, in: 0...20, step: 1)
                                        .frame(width: 120)
                                    Text("\(Int(appSettings.clipDrawerCornerRadiusVisible))")
                                        .frame(width: 30)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Drawer Width")
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .help("clipDrawerWidth")
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipDrawerWidth, in: 10...50, step: 2)
                                        .frame(width: 150)
                                    Text("\(Int(appSettings.clipDrawerWidth))")
                                        .frame(width: 30)
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Edge Distance")
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .help("clipEdgeDistance")
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipEdgeDistance, in: 0...100, step: 5)
                                        .frame(width: 150)
                                    Text("\(Int(appSettings.clipEdgeDistance))")
                                        .frame(width: 30)
                                }

                                Divider()
                                Text("Shadow").font(.headline)

                                HStack(spacing: 4) {
                                    Toggle("Drawer Shadow", isOn: $appSettings.clipDrawerShadowEnabled)
                                    Image(systemName: "questionmark.circle")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .help("clipDrawerShadowEnabled")
                                }

                                HStack(spacing: 4) {
                                    Toggle("Clip Shadow", isOn: $appSettings.clipBumpShadowEnabled)
                                    Image(systemName: "questionmark.circle")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .help("clipBumpShadowEnabled")
                                }

                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Strength")
                                        Image(systemName: "questionmark.circle")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .help("clipShadowStrength")
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipShadowStrength, in: 0...10, step: 0.5)
                                        .frame(width: 150)
                                    Text(String(format: "%.1f", appSettings.clipShadowStrength))
                                        .frame(width: 30)
                                }

                                Divider()
                                Text("Dimensions").font(.headline)

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Clip Height")
                                        Text("clipBumpHeight")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipBumpHeight, in: 30...100, step: 5)
                                        .frame(width: 150)
                                    Text("\(Int(appSettings.clipBumpHeight))")
                                        .frame(width: 30)
                                }

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Min Height")
                                        Text("clipBumpMinHeight")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipBumpMinHeight, in: 10...50, step: 5)
                                        .frame(width: 150)
                                    Text("\(Int(appSettings.clipBumpMinHeight))")
                                        .frame(width: 30)
                                }

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Radius (Hidden)")
                                        Text("clipBumpCornerRadiusHidden")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipBumpCornerRadiusHidden, in: 0...20, step: 1)
                                        .frame(width: 150)
                                    Text("\(Int(appSettings.clipBumpCornerRadiusHidden))")
                                        .frame(width: 30)
                                }

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Radius (Visible)")
                                        Text("clipBumpCornerRadiusVisible")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Slider(value: $appSettings.clipBumpCornerRadiusVisible, in: 0...20, step: 1)
                                        .frame(width: 150)
                                    Text("\(Int(appSettings.clipBumpCornerRadiusVisible))")
                                        .frame(width: 30)
                                }

                                HStack(spacing: 4) {
                                    Text("Left Icon Pos")
                                        .font(.caption)
                                    Image(systemName: "questionmark.circle")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .help("clipLeftIconPosition")
                                }
                                Picker("", selection: $appSettings.clipLeftIconPosition) {
                                    Text("Top").tag("top")
                                    Text("Bottom").tag("bottom")
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()

                                HStack(spacing: 4) {
                                    Text("Right Icon Pos")
                                        .font(.caption)
                                    Image(systemName: "questionmark.circle")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .help("clipRightIconPosition")
                                }
                                Picker("", selection: $appSettings.clipRightIconPosition) {
                                    Text("Top").tag("top")
                                    Text("Bottom").tag("bottom")
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                            }
                        }
                        }

                        Divider()

                        Button("Copy Settings as JSON") {
                            copySettingsToClipboard()
                        }
                    }
                }
                .tabItem {
                    Label("ClipDrawer", systemImage: "tray.fill")
                }
                .tag(1)
            }
        }
        .padding()
        .frame(minWidth: selectedTab == 1 ? 800 : 400, minHeight: 400)
        .onAppear {
            if let window = NSApplication.shared.windows.first {
                 window.ignoresMouseEvents = false
            }
        }
        .onDisappear {
            if let window = NSApplication.shared.windows.first {
                 window.ignoresMouseEvents = true
            }
        }
    }
}

// MARK: - Helper Views

struct TrackingAreaView: NSViewRepresentable {
    @Binding var mousePosition: NSPoint

    func makeNSView(context: Context) -> MouseTrackingNSView { 
        let view = MouseTrackingNSView(mousePosition: $mousePosition)
        
        // Still attempt to set acceptsMouseMovedEvents on the window
        DispatchQueue.main.async { 
            if let window = view.window {
                window.acceptsMouseMovedEvents = true
            } else {
                // This might still fail if the view isn't in a window yet
            }
        }
        return view
    }

    // Remove updateNSView - the custom view handles its own updates
    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {
        // No-op, bindings handle updates if needed, view handles tracking area
    }

    // Remove Coordinator and makeCoordinator
    // func makeCoordinator() -> Coordinator { ... }
    // class Coordinator: NSObject { ... }
}

// MARK: - Custom NSView Subclass for Tracking
class MouseTrackingNSView: NSView {
    @Binding var mousePosition: NSPoint
    private var trackingArea: NSTrackingArea?
    private weak var observedWindow: NSWindow?

    init(mousePosition: Binding<NSPoint>) {
        _mousePosition = mousePosition
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        mousePosition = location
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        guard !bounds.isEmpty else {
            trackingArea = nil
            return
        }

        let options: NSTrackingArea.Options = [.mouseMoved, .inVisibleRect, .activeInKeyWindow]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateTrackingAreas()
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let oldWindow = observedWindow {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: oldWindow)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: oldWindow)
            observedWindow = nil
        }

        guard let newWindow = window else { return }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowDidChangeKey(_:)),
                                               name: NSWindow.didBecomeKeyNotification,
                                               object: newWindow)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowDidChangeKey(_:)),
                                               name: NSWindow.didResignKeyNotification,
                                               object: newWindow)
        observedWindow = newWindow
        updateTrackingAreas()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil, let window = observedWindow {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: window)
            observedWindow = nil
        }
    }

    @objc private func windowDidChangeKey(_ notification: Notification) {
        guard let changedWindow = notification.object as? NSWindow, changedWindow === window else { return }
        updateTrackingAreas()
        let screenLocation = NSEvent.mouseLocation
        if let window = window {
            let windowLocation = window.convertPoint(fromScreen: screenLocation)
            let viewLocation = convert(windowLocation, from: nil)
            mousePosition = viewLocation
        }
    }
}

// Helper to wrap NSView in SwiftUI
struct MouseTrackingView: NSViewRepresentable {
    @Binding var mousePosition: NSPoint

    func makeNSView(context: Context) -> MouseTrackingNSView {
        MouseTrackingNSView(mousePosition: $mousePosition)
    }

    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {
    }
}
