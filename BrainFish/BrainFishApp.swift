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

// --- Global Mouse Tracker ---
class GlobalMouseTracker: ObservableObject {
    private var timer: Timer?
    @Published var globalMousePosition: NSPoint = .zero
    var pollingInterval: TimeInterval = 1.0 / 30.0

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let event = CGEvent(source: nil) {
                let loc = event.location
                let screenHeight = NSScreen.main?.frame.height ?? 0
                self.globalMousePosition = NSPoint(x: loc.x, y: screenHeight - loc.y)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}


// Make UUID conform to Transferable
extension UUID: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.uuidString)
    }
}

// MARK: - Helper Functions
func randomForLoop(_ loopIndex: Int, seed: Double) -> Double {
    let x = sin(Double(loopIndex) * 12.9898 + seed) * 43758.5453
    return x - floor(x)
}

func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    return a + (b - a) * t
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
            window.level = .screenSaver
            window.styleMask = [.borderless]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = true
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
        updateWindowFrame(for: window!)
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


// MARK: - Task Model
final class Task: Identifiable, ObservableObject {
    let id = UUID()
    @Published var title: String
    var startOffset: Double
    var speed: CGFloat
    @Published var remainingTime: TimeInterval
    @Published var accelerationEndTime: Date? = nil // Added for sustained speed
    
    init(title: String, startOffset: Double, speed: CGFloat, remainingTime: TimeInterval = 7200) {
        self.title = title
        self.startOffset = startOffset
        self.speed = speed
        self.remainingTime = remainingTime
    }
}

extension Task: Codable {
    enum CodingKeys: String, CodingKey {
        case title, startOffset, speed, remainingTime
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(startOffset, forKey: .startOffset)
        try container.encode(Double(speed), forKey: .speed)
        try container.encode(remainingTime, forKey: .remainingTime)
    }
    
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let title = try container.decode(String.self, forKey: .title)
        let startOffset = try container.decode(Double.self, forKey: .startOffset)
        let speedDouble = try container.decode(Double.self, forKey: .speed)
        let remainingTime = try container.decode(TimeInterval.self, forKey: .remainingTime)
        self.init(title: title, startOffset: startOffset, speed: CGFloat(speedDouble), remainingTime: remainingTime)
    }
}


// MARK: - AppData
class AppData: ObservableObject {
    @Published var tasks: [Task] = [
        Task(title: "Buy groceries", startOffset: 0, speed: 50)
    ]
    @Published var currentPomodoroTaskIndex: Int = 0
    var defaultPomodoroTime: TimeInterval = 7200  // 120 minutes
    
    private var timer: Timer?

    private let tasksKey = "SavedTasks"
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadTasks()  // Attempt to load saved tasks
        #if DEBUG
        print("DEBUG: AppData initialized with \(tasks.count) tasks: \(tasks.map { $0.title })")
        #endif
        startTimer()
        // Save tasks whenever the tasks array changes.
        $tasks
            .sink { [weak self] _ in
                self?.saveTasks()
            }
            .store(in: &cancellables)
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
        if let data = try? encoder.encode(tasks) {
            UserDefaults.standard.set(data, forKey: tasksKey)
        }
    }

    func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: tasksKey) {
            let decoder = JSONDecoder()
            if let savedTasks = try? decoder.decode([Task].self, from: data) {
                tasks = savedTasks
            }
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


// MARK: - Add a think black line around the font (for visibility)
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
    // --- Sleep Cycle Settings ---
    @Published var sleepIntervalMinutes: Int = 5 {
        didSet { UserDefaults.standard.set(sleepIntervalMinutes, forKey: "sleepIntervalMinutes") }
    }
    @Published var sleepDurationMinutes: Int = 5 {
        didSet { UserDefaults.standard.set(sleepDurationMinutes, forKey: "sleepDurationMinutes") }
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
        // --- Load Sleep Cycle Settings ---
        if let interval = UserDefaults.standard.object(forKey: "sleepIntervalMinutes") as? Int {
            sleepIntervalMinutes = interval
        }
        if let duration = UserDefaults.standard.object(forKey: "sleepDurationMinutes") as? Int {
            sleepDurationMinutes = duration
        }
        // (If you want to persist fontColor, you could convert it to/from a hex string or Data.)
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

    var body: some View {
        GeometryReader { geometry in
            #if DEBUG
            let _ = print("ContentView Geometry: local=\(geometry.frame(in: .local)), global=\(geometry.frame(in: .global))")
            #endif
            
            // --- Place TimelineView directly --- 
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let currentTime = timeline.date.timeIntervalSinceReferenceDate
                let geometry = geometry // Ensure geometry is captured if it's not already in scope for the ZStack replacement
                // Inner ZStack for fish
                ZStack {
                    #if DEBUG
                    let _ = print("DEBUG: ContentView - isSleeping=\(isSleeping), pomodoroMode=\(appSettings.pomodoroMode), tasksCount=\(appData.tasks.count)")
                    #endif
                    
                    if appSettings.pomodoroMode {
                        #if DEBUG
                        let _ = print("DEBUG: Pomodoro mode enabled")
                        #endif
                        if !appData.tasks.isEmpty {
                            let index = appData.currentPomodoroTaskIndex % appData.tasks.count
                            let task = appData.tasks[index] // Get the task object
                            #if DEBUG
                            let _ = print("DEBUG: Creating Pomodoro TaskSnakeView for task \(index): '\(task.title)'")
                            #endif
                            TaskSnakeView(task: task, // Use the task object
                                          taskIndex: index,
                                          totalTasks: 1,
                                          time: currentTime,
                                          size: geometry.size,
                                          isSleeping: isSleeping,
                                          mousePosition: mousePosition,
                                          useGlobalMouseTracking: appSettings.useGlobalMouseTracking,
                                          globalMousePosition: globalMouseTracker.globalMousePosition,
                                          appSettings: appSettings)
                                .id(task.id) // ADDED EXPLICIT ID
                        } else {
                            #if DEBUG
                            let _ = print("DEBUG: No tasks available for Pomodoro mode")
                            #endif
                        }
                    } else {
                        #if DEBUG
                        let _ = print("DEBUG: Regular mode enabled, creating \(appData.tasks.count) fish")
                        #endif
                        ForEach(appData.tasks.indices, id: \.self) { index in
                            let task = appData.tasks[index]
                            #if DEBUG
                            let _ = print("DEBUG: Creating TaskSnakeView \(index) for task: '\(task.title)'")
                            #endif
                            TaskSnakeView(task: task,
                                          taskIndex: index,
                                          totalTasks: appData.tasks.count,
                                          time: currentTime,
                                          size: geometry.size,
                                          isSleeping: isSleeping,
                                          mousePosition: mousePosition,
                                          useGlobalMouseTracking: appSettings.useGlobalMouseTracking,
                                          globalMousePosition: globalMouseTracker.globalMousePosition,
                                          appSettings: appSettings)
                                .id(task.id)
                        }
                    }
                }
            } // End TimelineView
            // --- Apply TrackingAreaView as background --- 
            .background(
                TrackingAreaView(mousePosition: $mousePosition)
            )
             
        } // End GeometryReader
        .ignoresSafeArea()
        .onAppear {
            setupSleepTimer()
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
        .onChange(of: mousePosition) { oldValue, newValue in // UPDATED for macOS 14+ compatibility
            #if DEBUG
            print("DIAGNOSTIC: ContentView.mousePosition changed from \(oldValue) to: \(newValue)")
            #endif
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
                #if DEBUG
                print("Waking up fish...")
                #endif
                isSleeping = false
                lastSleepToggleTime = now // Mark wake-up time
            }
        } else {
            // Currently awake, check if interval has passed
            if timeSinceLastToggle >= intervalSeconds {
                #if DEBUG
                print("Putting fish to sleep...")
                #endif
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
    @State private var lastUpdateTime: TimeInterval = 0
    @State private var currentPosition: CGFloat = 0
    @State private var speedMultiplier: Double = 2.0
    @State private var baseSpeedMultiplier: Double = 1.0
    @State private var targetBaseSpeed: Double = 1.0
    @State private var lastSpeedChangeTime: TimeInterval = 0
    @State private var startDelay: Double = 0
    @State private var hasStarted: Bool = false
    @State private var lastPrintTime: TimeInterval = 0
    @State private var isMouseCurrentlyOver: Bool = false // Added for hit-testing

    private let speedChangeInterval: TimeInterval = 5.0
    private let printInterval: TimeInterval = 2.0

    var body: some View {
        let elapsedTime = (initialTime != nil) ? (time - initialTime!) : 0
        Group {
            if isSleeping || !hasStarted {
                EmptyView()
            } else {
                fishBodyView(
                    task: task,
                    taskIndex: taskIndex,
                    totalTasks: totalTasks,
                    size: size,
                    elapsedTime: elapsedTime,
                    currentPosition: currentPosition,
                    isMouseCurrentlyOver: self.isMouseCurrentlyOver, // Pass new state
                    currentSpeedMultiplier: self.speedMultiplier,
                    currentBaseSpeed: self.baseSpeedMultiplier,
                    updateLastPrintTime: self.updateLastPrintTime,
                    lastPrintTime: self.lastPrintTime,
                    printInterval: self.printInterval,
                    // mousePosition: mousePosition, // REMOVED
                    appSettings: appSettings)
            }
        }
        .onChange(of: time) { _, newTime in
            updatePositionAndSpeed(newTime: newTime)
        }
        .onAppear { 
            #if DEBUG
            print("DEBUG: TaskSnakeView Group ONAPPEAR - Task: \(taskIndex), Title: \(task.title), ViewSize: \(size), isSleeping: \(isSleeping), initialTime: \(String(describing: initialTime))") 
            #endif
            #if DEBUG
            print("DEBUG: TaskSnakeView ONAPPEAR - Initial currentPosition: \(self.currentPosition), size.width: \(self.size.width)") // DEBUG
            #endif

            if self.initialTime == nil { 
                self.initialTime = time
                self.currentPosition = self.size.width // EXPLICITLY SET POSITION
                #if DEBUG
                print("DEBUG: TaskSnakeView ONAPPEAR - Set currentPosition to size.width: \(self.currentPosition)") // DEBUG
                #endif
            }
            if self.startDelay == 0 { 
                // Calculate the new delay range
                let maxDelay = max(1.0, Double(totalTasks * 3)) // Ensure maxDelay is at least 1.0
                self.startDelay = Double.random(in: 1.0...maxDelay) // MODIFIED
                #if DEBUG
                print("DEBUG: TaskSnakeView Group ONAPPEAR - Task: \(taskIndex), Set startDelay: \(self.startDelay) (Range: 1.0...\(maxDelay))") // MODIFIED to show new range
                #endif
            }
            updatePositionAndSpeed(newTime: time) // Initial call
        }
    }
    
    func updatePositionAndSpeed(newTime: TimeInterval) {
        // Log the mousePosition as TaskSnakeView sees it at this moment
        if taskIndex == 0 {
            #if DEBUG
            print("DIAGNOSTIC_TSV_UPDATE: Fish(0) updatePositionAndSpeed - mousePos: \(self.mousePosition), currentFishX: \(currentPosition)")
            #endif
        }
        let elapsedTime = (initialTime != nil) ? (newTime - initialTime!) : 0
        let deltaTime = newTime - lastUpdateTime
        
        // Check if we should start swimming (after random delay)
        if !hasStarted {
            if elapsedTime >= startDelay {
                hasStarted = true
                lastUpdateTime = newTime
                lastSpeedChangeTime = newTime
                #if DEBUG
                print("DEBUG: TaskSnakeView updatePositionAndSpeed - Task: \(taskIndex) HAS STARTED. elapsedTime: \(elapsedTime), startDelay: \(startDelay)")
                #endif
            }
            return
        }
        
        guard lastUpdateTime > 0 else {
            lastUpdateTime = newTime
            return
        }
        
        // Handle periodic speed changes every 5 seconds
        if newTime - lastSpeedChangeTime >= speedChangeInterval {
            // Generate new random target speed (0.6x to 1.4x)
            targetBaseSpeed = Double.random(in: 0.6...1.4)
            lastSpeedChangeTime = newTime
        }
        
        // Smoothly ease towards target base speed
        let speedEaseRate = 0.5 // How fast to transition between speeds
        if abs(baseSpeedMultiplier - targetBaseSpeed) > 0.01 {
            let speedChangeAmount = speedEaseRate * deltaTime
            if baseSpeedMultiplier < targetBaseSpeed {
                baseSpeedMultiplier = min(baseSpeedMultiplier + speedChangeAmount, targetBaseSpeed)
            } else {
                baseSpeedMultiplier = max(baseSpeedMultiplier - speedChangeAmount, targetBaseSpeed)
            }
        }
        
        // Calculate fish dimensions for wraparound and avoidance
        let displayText: String = appSettings.pomodoroMode
            ? "\(task.title) (\(timeString(from: task.remainingTime)))"
            : task.title
        let letters = Array(displayText)
        let letterSpacing = appSettings.fontSize * 0.6
        let textWidth = letterSpacing * CGFloat(letters.count)

        // DEBUG PRINT for mouse state BEFORE interaction logic
        if taskIndex == 0 && Date().timeIntervalSinceReferenceDate - self.lastPrintTime > 0.5 { 
            #if DEBUG
            print("DEBUG_MOUSE_STATE Pre: Fish(0) - isMouseOver: \(isMouseCurrentlyOver), mousePos: \(mousePosition), currentFishPos: \(currentPosition), speedMult: \(speedMultiplier), baseSpeedMult: \(baseSpeedMultiplier)")
            #endif
            self.lastPrintTime = Date().timeIntervalSinceReferenceDate // Update lastPrintTime for this log
        }

        // --- Use global mouse position if enabled ---
        let effectiveMousePosition = appSettings.useGlobalMouseTracking ? self.globalMousePosition : mousePosition

        // Hit-testing logic
        let fishCenterX = currentPosition + (textWidth / 2.0)
        let fishCenterY = wormPath(letterX: fishCenterX)

        // Flip mousePosition.y to match SwiftUI coordinate system
        let flippedMouseY = size.height - effectiveMousePosition.y
        let adjustedMousePos = CGPoint(x: effectiveMousePosition.x, y: flippedMouseY)

        let hitTestRadiusX = textWidth / 2.0
        let hitTestRadiusY = appSettings.fontSize

        let dx = adjustedMousePos.x - fishCenterX
        let dy = adjustedMousePos.y - fishCenterY
        let normalizedDxSq = pow(dx / hitTestRadiusX, 2)
        let normalizedDySq = pow(dy / hitTestRadiusY, 2)
        self.isMouseCurrentlyOver = (normalizedDxSq + normalizedDySq) < 1.0
        
        // Keep a single concise log for fish 0 only
        if taskIndex == 0 {
            #if DEBUG
            print("Fish(0) hit-test: adjustedMousePos=\(adjustedMousePos), fishCenter=(\(String(format: "%.1f", fishCenterX)), \(String(format: "%.1f", fishCenterY))), isMouseCurrentlyOver=\(self.isMouseCurrentlyOver)")
            #endif
        }

        // Calculate distance-based speed multiplier (SPEED UP when mouse is near)
        var targetSpeedMultiplier: Double
        // 'task' is already available as a property of TaskSnakeView (self.task)

        if self.isMouseCurrentlyOver {
            task.accelerationEndTime = Date().addingTimeInterval(2.0) // Set/extend acceleration end time
            targetSpeedMultiplier = 2.5 // Speed up more significantly
        } else {
            if let endTime = task.accelerationEndTime, Date() < endTime {
                targetSpeedMultiplier = 2.5 // Maintain accelerated speed
            } else {
                targetSpeedMultiplier = 1.0 // Revert to normal speed
                if task.accelerationEndTime != nil {
                    task.accelerationEndTime = nil // Clear end time only if it was previously set
                }
            }
        }
        
        let changeRate = 5.0 // Fast transitions for responsive escape behavior

        if abs(speedMultiplier - targetSpeedMultiplier) > 0.01 {
            let changeAmount = changeRate * deltaTime
            if speedMultiplier < targetSpeedMultiplier {
                speedMultiplier = min(speedMultiplier + changeAmount, targetSpeedMultiplier)
            } else {
                speedMultiplier = max(speedMultiplier - changeAmount, targetSpeedMultiplier)
            }
        }
        
        // Update position incrementally based on current speed
        let randomSpeedFactor = 0.9 + 0.2 * randomForLoop(taskIndex, seed: 2.0)
        let baseSpeed = task.speed * randomSpeedFactor * baseSpeedMultiplier // Include natural speed variation
        let currentSpeed = baseSpeed * speedMultiplier
        let distanceThisFrame = currentSpeed * deltaTime
        
        // Always move fish to the left (never backwards)
        currentPosition -= distanceThisFrame
        // Wrap fish to right edge if off left side
        if currentPosition < -textWidth {
            currentPosition = size.width
            #if DEBUG
            print("DEBUG: Fish wrapped to right edge. taskIndex=\(taskIndex), textWidth=\(textWidth), newCurrentPosition=\(currentPosition)")
            #endif
        }
        
        lastUpdateTime = newTime
        #if DEBUG
        let _ = print("DEBUG: TaskSnakeView updatePositionAndSpeed END - Task: \(taskIndex), newPos: \(currentPosition), newSpeedMult: \(speedMultiplier), newBaseSpeedMult: \(baseSpeedMultiplier), deltaTime: \(deltaTime)")
        #endif
    }
    
    // Helper function for wormPath calculation (needed in updatePositionAndSpeed)
    private func wormPath(letterX: CGFloat) -> CGFloat {
        let topBandHeight = size.height * 0.05
        let baselineY = topBandHeight * (CGFloat(taskIndex) + 0.5) / CGFloat(totalTasks)
        let wormAmplitude = lerp(5, 10, randomForLoop(taskIndex, seed: 4.0))
        let wormFrequency = lerp(10, 20, randomForLoop(taskIndex, seed: 5.0))
        let wormPhase = lerp(0, 2 * Double.pi, randomForLoop(taskIndex, seed: 6.0))
        let secondaryAmplitude = lerp(1.0, 3.0, randomForLoop(taskIndex, seed: 7.0))
        let secondaryFrequency = lerp(1.0, 2.0, randomForLoop(taskIndex, seed: 8.0))
        let secondaryPhase = lerp(0, 2 * Double.pi, randomForLoop(taskIndex, seed: 9.0))
        let normalizedX = Double(letterX + size.width) / Double(size.width + size.width)
        let mod1 = wormAmplitude * sin(2 * .pi * wormFrequency * normalizedX + wormPhase)
        let mod2 = secondaryAmplitude * sin(2 * .pi * secondaryFrequency * normalizedX + secondaryPhase)
        return baselineY + CGFloat(mod1 + mod2)
    }
    
    func updateLastPrintTime() {
        lastPrintTime = Date().timeIntervalSinceReferenceDate
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
    let isMouseCurrentlyOver: Bool // Added
    let currentSpeedMultiplier: Double
    let currentBaseSpeed: Double
    let updateLastPrintTime: () -> Void
    @State var lastPrintTime: TimeInterval // Made @State as it's modified locally for debug
    let printInterval: TimeInterval
    // let mousePosition: CGPoint // REMOVED
    let appSettings: AppSettings

    var body: some View {
        let displayText: String = appSettings.pomodoroMode
            ? "\(task.title) (\(timeString(from: task.remainingTime)))"
            : task.title
        let letters = Array(displayText)
        let letterSpacing = appSettings.fontSize * 0.6
        let textWidth = letterSpacing * CGFloat(letters.count)

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
        let now = Date()
        if taskIndex == 0 && (lastPrintTime == 0 || now.timeIntervalSinceReferenceDate - lastPrintTime > printInterval) { // MODIFIED: Only for taskIndex == 0
            #if DEBUG
            print("Fish \(taskIndex): HeadX=\(String(format: "%.1f", headX)), nearMouse=\(isMouseCurrentlyOver), speedMult=\(String(format: "%.2f", currentSpeedMultiplier)), baseSpeed=\(String(format: "%.2f", currentBaseSpeed))")
            #endif
            DispatchQueue.main.async {
                updateLastPrintTime()
            }
        }

        // --- Local Helper Functions ---
        func wormPath(letterX: CGFloat) -> CGFloat {
            let topBandHeight = size.height * 0.05
            let baselineY = topBandHeight * (CGFloat(taskIndex) + 0.5) / CGFloat(totalTasks)
            let wormAmplitude = lerp(5, 10, randomForLoop(taskIndex, seed: 4.0))
            let wormFrequency = lerp(10, 20, randomForLoop(taskIndex, seed: 5.0))
            let wormPhase = lerp(0, 2 * Double.pi, randomForLoop(taskIndex, seed: 6.0))
            let secondaryAmplitude = lerp(1.0, 3.0, randomForLoop(taskIndex, seed: 7.0))
            let secondaryFrequency = lerp(1.0, 2.0, randomForLoop(taskIndex, seed: 8.0))
            let secondaryPhase = lerp(0, 2 * Double.pi, randomForLoop(taskIndex, seed: 9.0))
            let normalizedX = Double(letterX + size.width) / Double(size.width + size.width)
            let mod1 = wormAmplitude * sin(2 * .pi * wormFrequency * normalizedX + wormPhase)
            let mod2 = secondaryAmplitude * sin(2 * .pi * secondaryFrequency * normalizedX + secondaryPhase)
            return baselineY + CGFloat(mod1 + mod2)
        }
        
        // Helper function to calculate tangent angle.
        func tangentAngle(at x: CGFloat) -> Angle {
            let dx: CGFloat = 1.0
            let y1 = wormPath(letterX: x)
            let y2 = wormPath(letterX: x + dx)
            let angleRadians = atan2(y2 - y1, dx)
            return Angle(radians: Double(angleRadians))
        }
        
        return ZStack {
            // Fish head
            Image("koi-head")
                .resizable()
                .scaledToFit()
                .frame(width: appSettings.fontSize * 2.0, height: appSettings.fontSize * 2.0)
                .rotationEffect(tangentAngle(at: headX), anchor: .trailing)
                .position(x: headX - appSettings.fontSize, y: wormPath(letterX: headX))
            // Pectoral fins
            Image("koi-fins-pectoral")
                .resizable()
                .scaledToFit()
                .frame(width: appSettings.fontSize * 1.4)
                .rotationEffect(tangentAngle(at: headX + 0.15 * textWidth))
                .position(x: headX + 0.15 * textWidth, y: wormPath(letterX: headX + 0.15 * textWidth))
            // Ventral fins
            Image("koi-fins-ventral")
                .resizable()
                .scaledToFit()
                .frame(width: appSettings.fontSize * 1.1)
                .rotationEffect(tangentAngle(at: headX + 0.4 * textWidth))
                .position(x: headX + 0.4 * textWidth, y: wormPath(letterX: headX + 0.4 * textWidth))
            // Tail
            Image("koi-tail")
                .resizable()
                .scaledToFit()
                .frame(width: appSettings.fontSize * 1.6, height: appSettings.fontSize * 1.6)
                .rotationEffect(tangentAngle(at: headX + textWidth), anchor: .leading)
                .position(x: headX + textWidth + appSettings.fontSize * 0.8, y: wormPath(letterX: headX + textWidth))
            // The text letters with variable font sizes
            ForEach(letters.indices, id: \.self) { i in
                let letterX = headX + CGFloat(i) * letterSpacing
                let letterY = wormPath(letterX: letterX)
                let scale = letterScale(for: i, total: letters.count)
                Text(String(letters[i]))
                    .font(.system(size: appSettings.fontSize * scale, weight: .bold, design: .rounded))
                    .modifier(OutlineText(color: .black, lineWidth: 1))
                    .foregroundColor(appSettings.fontColor)
                    .position(x: letterX, y: letterY)
                    .rotationEffect(.degrees(0))
                    .animation(nil, value: elapsedTime)
            }
        }
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


// MARK: - SettingsView
struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    @Environment(\.presentationMode) var presentationMode
    
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
            }
        }
        .padding()
        .frame(minWidth: 300)
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
        #if DEBUG
        print("--- TrackingAreaView: makeNSView CALLED ---")
        #endif
        let view = MouseTrackingNSView(mousePosition: $mousePosition)
        
        // Still attempt to set acceptsMouseMovedEvents on the window
        DispatchQueue.main.async { 
            if let window = view.window {
                #if DEBUG
                print("--- TrackingAreaView: Setting acceptsMouseMovedEvents=true on window ---")
                #endif
                window.acceptsMouseMovedEvents = true
            } else {
                // This might still fail if the view isn't in a window yet
                #if DEBUG
                print("--- TrackingAreaView: Could not get window in makeNSView ---")
                #endif
            }
        }
        return view
    }

    // Remove updateNSView - the custom view handles its own updates
    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {
         #if DEBUG
         print("--- TrackingAreaView: updateNSView CALLED (NO-OP) ---")
         #endif
        // No-op, bindings handle updates if needed, view handles tracking area
    }

    // Remove Coordinator and makeCoordinator
    // func makeCoordinator() -> Coordinator { ... }
    // class Coordinator: NSObject { ... }
}

// MARK: - Custom NSView Subclass for Tracking
class MouseTrackingNSView: NSView {
    @Binding var mousePosition: NSPoint
    var trackingArea: NSTrackingArea?
    private weak var observedWindow: NSWindow?

    init(mousePosition: Binding<NSPoint>) {
        _mousePosition = mousePosition
        super.init(frame: .zero) // Initial frame doesn't matter much here
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor // Keep it transparent
         #if DEBUG
         print("DIAGNOSTIC: MouseTrackingNSView.init() called.") // ENSURED PRINT
         #endif
        // For observing window key status changes
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidChangeKey(_:)), name: NSWindow.didBecomeKeyNotification, object: self.window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidChangeKey(_:)), name: NSWindow.didResignKeyNotification, object: self.window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        #if DEBUG
        print("DIAGNOSTIC: MouseTrackingNSView.deinit() called.")
        #endif
    }

    override func mouseMoved(with event: NSEvent) {
        let locationInWindow = event.locationInWindow
        let convertedPoint = self.convert(locationInWindow, from: nil)
        #if DEBUG
        print("DIAGNOSTIC_IMMEDIATE: MouseTrackingNSView.mouseMoved called. Window: \(locationInWindow), Converted: \(convertedPoint)") // Log immediately
        #endif
        
        // Update the binding directly, as mouseMoved is usually on the main thread.
        self.mousePosition = convertedPoint
        // Log to confirm the binding was set. This will be synchronous now.
        #if DEBUG
        print("DIAGNOSTIC_SYNC_UPDATE: MouseTrackingNSView.mouseMoved - mousePosition binding updated to: \(self.mousePosition)")
        #endif
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        #if DEBUG
        print("DIAGNOSTIC: MouseTrackingNSView.updateTrackingAreas() called. Current Bounds: \(self.bounds)") // DIAGNOSTIC PRINT
        #endif

        if let existingTrackingArea = self.trackingArea {
            self.removeTrackingArea(existingTrackingArea)
            self.trackingArea = nil // Clear the reference
            #if DEBUG
            print("DIAGNOSTIC: MouseTrackingNSView - Removed existing tracking area.")
            #endif
        }
        
        // Only add tracking area if bounds are valid (non-empty)
        if !self.bounds.isEmpty {
            let options: NSTrackingArea.Options = [
                .mouseMoved, 
                .activeInKeyWindow, // Only track when window is key
                .inVisibleRect
            ]
            
            trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
            if let ta = trackingArea {
                self.addTrackingArea(ta)
                #if DEBUG
                print("DIAGNOSTIC: MouseTrackingNSView - Added new tracking area for bounds \(self.bounds).")
                #endif
            } else {
                #if DEBUG
                print("DIAGNOSTIC_ERROR: MouseTrackingNSView - Failed to create NSTrackingArea.")
                #endif
            }
        } else {
            #if DEBUG
            print("DIAGNOSTIC: MouseTrackingNSView - Bounds are empty, skipping new tracking area creation.")
            #endif
        }
    }

    // Called when the view is added to a window or its frame changes
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        #if DEBUG
        print("--- MouseTrackingNSView: setFrameSize called. New size: \(newSize). Bounds: \(self.bounds) ---")
        #endif
        self.updateTrackingAreas() // Directly call updateTrackingAreas()
    }

    // It's good practice for custom views that handle mouse events
    override var acceptsFirstResponder: Bool { true }
    
    // MARK: - Additional NSView Overrides

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        #if DEBUG
        print("--- MouseTrackingNSView: viewDidMoveToWindow. Window: \(String(describing: self.window)), Bounds: \(self.bounds) ---")
        #endif

        // Remove observer from old window if any
        if let oldWindow = observedWindow {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: oldWindow)
            observedWindow = nil
        }

        if let newWindow = self.window {
            NotificationCenter.default.addObserver(self,
                                               selector: #selector(windowDidChangeKey(_:)),
                                               name: NSWindow.didBecomeKeyNotification,
                                               object: newWindow)
            observedWindow = newWindow
            #if DEBUG
            print("--- MouseTrackingNSView: Added didBecomeKeyNotification observer for window: \(newWindow) ---")
            #endif
            // Initial setup of tracking area when view is added to a window
            self.updateTrackingAreas()
        } else {
            #if DEBUG
            print("--- MouseTrackingNSView: viewDidMoveToWindow - No window to observe or setup tracking for. ---")
            #endif
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        #if DEBUG
        print("--- MouseTrackingNSView: viewWillMoveToWindow. New Window: \(String(describing: newWindow)) ---")
        #endif
        // If the view is being removed from its current window (newWindow is nil)
        // and it was previously in a window (self.window is not nil yet, or use observedWindow)
        if newWindow == nil, let currentWindow = self.window ?? observedWindow {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: currentWindow)
            observedWindow = nil // Clear the observed window reference
            #if DEBUG
            print("--- MouseTrackingNSView: Removed didBecomeKeyNotification observer from window: \(currentWindow) as view is being removed. ---")
            #endif
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        #if DEBUG
        print("--- MouseTrackingNSView: viewDidChangeEffectiveAppearance. Bounds: \(self.bounds) ---")
        #endif
        // self.needsUpdateTrackingAreas = true // Consider if appearance changes affect tracking needs
    }

    @objc func windowDidChangeKey(_ notification: Notification) {
        guard let notificationWindow = notification.object as? NSWindow, notificationWindow === self.window else {
            // print("--- MouseTrackingNSView: windowDidChangeKey notification for other window or no window. Ignored. ---")
            return
        }
        #if DEBUG
        print("--- MouseTrackingNSView: WindowDidBecomeKey notification received for OUR window. Updating tracking areas. Bounds: \(self.bounds) ---")
        #endif
        self.updateTrackingAreas()
        // Immediately update mouse position when regaining focus
        let mouseLocationInScreen = NSEvent.mouseLocation
        if let window = self.window {
            let mouseLocationInWindow = window.convertPoint(fromScreen: mouseLocationInScreen)
            let mouseLocationInView = self.convert(mouseLocationInWindow, from: nil)
            self.mousePosition = mouseLocationInView
            #if DEBUG
            print("DIAGNOSTIC: MouseTrackingNSView.windowDidBecomeKey - Updated mousePosition to: \(mouseLocationInView)")
            #endif
        }
    }
}

// Helper to wrap NSView in SwiftUI
struct MouseTrackingView: NSViewRepresentable {
    @Binding var mousePosition: NSPoint

    func makeNSView(context: Context) -> MouseTrackingNSView {
        let nsView = MouseTrackingNSView(mousePosition: $mousePosition)
        #if DEBUG
        print("MouseTrackingView: makeNSView called, NSView created")
        #endif
        return nsView
    }

    func updateNSView(_ nsView: MouseTrackingNSView, context: Context) {
        #if DEBUG
        print("DIAGNOSTIC: TrackingAreaView.updateNSView called. mousePosition from binding: \(mousePosition), nsView.mousePosition: \(nsView.mousePosition)")
        #endif
    }
}
