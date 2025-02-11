/*
 __________               .__       ___________.__       .__
 \______   \____________  |__| ____ \_   _____/|__| _____|  |__
  |    |  _/\_  __ \__  \ |  |/    \ |    __)  |  |/  ___/  |  \
  |    |   \ |  | \// __ \|  |   |  \|     \   |  |\___ \|   Y  \
  |______  / |__|  (____  /__|___|  /\___  /   |__/____  >___|  /
         \/             \/        \/     \/            \/     \/

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

// MARK: - Helper Functions
func randomForLoop(_ loopIndex: Int, seed: Double) -> Double {
    let x = sin(Double(loopIndex) * 12.9898 + seed) * 43758.5453
    return x - floor(x)
}

func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    return a + (b - a) * t
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first, let screen = NSScreen.main {
            window.setFrame(screen.frame, display: true)
            window.level = .screenSaver
            window.styleMask = [.borderless]
            window.isOpaque = false
            window.backgroundColor = .clear
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        }
        statusBarController = StatusBarController()
    }
    
    @objc func showTaskListAction() {
        NotificationCenter.default.post(name: Notification.Name("ShowTaskList"), object: nil)
    }
    
    @objc func showSettingsAction() {
        NotificationCenter.default.post(name: Notification.Name("ShowSettings"), object: nil)
    }
}


// MARK: - Task Model
final class Task: Identifiable, ObservableObject {
    let id = UUID()
    @Published var title: String
    var startOffset: Double
    var speed: CGFloat
    @Published var remainingTime: TimeInterval
    
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
    
    public func encode(to encoder: Encoder) throws {
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
    
    init() {
        // Load saved settings if available.
        if let savedFontSize = UserDefaults.standard.object(forKey: "fontSize") as? CGFloat {
            fontSize = savedFontSize
        }
        if let savedPomodoroMode = UserDefaults.standard.object(forKey: "pomodoroMode") as? Bool {
            pomodoroMode = savedPomodoroMode
        }
        if let savedDefaultTime = UserDefaults.standard.object(forKey: "defaultPomodoroTime") as? TimeInterval {
            defaultPomodoroTime = savedDefaultTime
        }
        // (If you want to persist fontColor, you could convert it to/from a hex string or Data.)
    }
}


// MARK: - ContentView
struct ContentView: View {
    @EnvironmentObject var appData: AppData
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                let currentTime = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    if appSettings.pomodoroMode {
                        if !appData.tasks.isEmpty {
                            let index = appData.currentPomodoroTaskIndex % appData.tasks.count
                            TaskSnakeView(task: appData.tasks[index],
                                          taskIndex: index,
                                          totalTasks: 1,
                                          time: currentTime,
                                          size: geometry.size)
                        }
                    } else {
                        ForEach(appData.tasks.indices, id: \.self) { index in
                            let task = appData.tasks[index]
                            TaskSnakeView(task: task,
                                          taskIndex: index,
                                          totalTasks: appData.tasks.count,
                                          time: currentTime,
                                          size: geometry.size)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
        .background(Color.clear)
    }
    
    func timeString(from seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - TaskSnakeView
struct TaskSnakeView: View {
    @EnvironmentObject var appSettings: AppSettings
    
    let task: Task
    let taskIndex: Int
    let totalTasks: Int
    let time: TimeInterval
    let size: CGSize
    
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
    
    var body: some View {
        // In Pomodoro mode, combine the task title with the live timer.
        let displayText: String = appSettings.pomodoroMode
            ? "\(task.title) (\(timeString(from: task.remainingTime)))"
            : task.title
        
        let letters = Array(displayText)
        let letterSpacing = appSettings.fontSize * 0.6
        let textWidth = letterSpacing * CGFloat(letters.count)
        let totalDistance = size.width + textWidth
        
        let nominalCycleDuration = totalDistance / task.speed
        let loopIndex = Int(floor((time - delayAdjustment) / nominalCycleDuration))
        let localT = (time - delayAdjustment).truncatingRemainder(dividingBy: nominalCycleDuration)
        
        let randomSpeedFactor = CGFloat(lerp(1, 2, randomForLoop(loopIndex, seed: 1.0)))
        let randomHorizontalOffset = CGFloat(lerp(-Double(letterSpacing), Double(letterSpacing), randomForLoop(loopIndex, seed: 3.0)))
        
        let effectiveSpeed = task.speed * randomSpeedFactor
        let fraction = localT * effectiveSpeed / totalDistance
        
        // Right-to-left motion.
        let headX = size.width + textWidth - (fraction * totalDistance) - randomHorizontalOffset
        
        let topBandHeight = size.height * 0.05
        let baselineY = topBandHeight * (CGFloat(taskIndex) + 0.5) / CGFloat(totalTasks)
        
        // Worm path parameters.
        let wormAmplitude = lerp(5, 10, randomForLoop(loopIndex, seed: 4.0))
        let wormFrequency = lerp(10, 20, randomForLoop(loopIndex, seed: 5.0))
        let wormPhase = lerp(0, 2 * Double.pi, randomForLoop(loopIndex, seed: 6.0))
        let secondaryAmplitude = lerp(1.0, 3.0, randomForLoop(loopIndex, seed: 7.0))
        let secondaryFrequency = lerp(1.0, 2.0, randomForLoop(loopIndex, seed: 8.0))
        let secondaryPhase = lerp(0, 2 * Double.pi, randomForLoop(loopIndex, seed: 9.0))
        
        func wormPath(letterX: CGFloat) -> CGFloat {
            let normalizedX = Double(letterX + textWidth) / Double(totalDistance)
            let mod1 = wormAmplitude * sin(2 * .pi * wormFrequency * normalizedX + wormPhase)
            let mod2 = secondaryAmplitude * sin(2 * .pi * secondaryFrequency * normalizedX + secondaryPhase)
            return baselineY + CGFloat(mod1 + mod2)
        }
        
        // Helper to compute the tangent angle of the worm path at a given x.
        func tangentAngle(at x: CGFloat) -> Angle {
            let dx: CGFloat = 1.0
            let y1 = wormPath(letterX: x)
            let y2 = wormPath(letterX: x + dx)
            let angleRadians = atan2(y2 - y1, dx)
            // Adjust by 90° because our images originally point downward.
            return Angle(radians: Double(angleRadians))
        }
        
        // --- Calculate positions and sizes for fish images ---
        let headImageWidth = appSettings.fontSize * 2.0  // Current head size.
        let pectoralWidth = appSettings.fontSize * 1.4
        let ventralWidth = appSettings.fontSize * 1.1
        let tailImageWidth = appSettings.fontSize * 1.6
                
        // Fin positions
        let pectoralX = headX + 0.15 * textWidth
        let ventralX = headX + 0.4 * textWidth
        let tailX = headX + textWidth

        return ZStack {
            // Fish head
            Image("koi-head")
                .resizable()
                .scaledToFit()
                .frame(width: headImageWidth, height: headImageWidth)
                .rotationEffect(tangentAngle(at: headX), anchor: .trailing)
                // Adjust the position so that the right edge (trailing edge) remains fixed:
                .position(x: headX - headImageWidth/2, y: wormPath(letterX: headX))
            // Pectoral fins
            Image("koi-fins-pectoral")
                .resizable()
                .scaledToFit()
                .frame(width: pectoralWidth)
                .rotationEffect(tangentAngle(at: pectoralX))
                .position(x: pectoralX, y: wormPath(letterX: pectoralX))
            // Ventral fins
            Image("koi-fins-ventral")
                .resizable()
                .scaledToFit()
                .frame(width: ventralWidth)
                .rotationEffect(tangentAngle(at: ventralX))
                .position(x: ventralX, y: wormPath(letterX: ventralX))
            // Tail
            Image("koi-tail")
                .resizable()
                .scaledToFit()
                .frame(width: tailImageWidth, height: tailImageWidth)
                .rotationEffect(tangentAngle(at: tailX), anchor: .leading)
                .position(x: tailX + tailImageWidth/2, y: wormPath(letterX: tailX))
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
                    .animation(nil, value: time)
            }
        }
    }

    var delayAdjustment: TimeInterval {
        return 0.5 * Double(taskIndex)
    }
    
    func timeString(from seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        // let secs = Int(seconds) % 60
        return String(format: "%02d", minutes)
    }
}



// MARK: - TaskListHeaderView
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


// Make UUID conform to Transferable
extension UUID: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .plainText)
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

// MARK: - Main App Entry Point
@main
struct FloatingSnakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appData = AppData()
    @StateObject var appSettings = AppSettings()
    
    @State private var showTaskList = false
    @State private var showSettings = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appData)
                .environmentObject(appSettings)
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowTaskList"))) { _ in
                    showTaskList = true
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowSettings"))) { _ in
                    showSettings = true
                }
                .sheet(isPresented: $showTaskList) {
                    TaskListView()
                        .environmentObject(appData)
                        .environmentObject(appSettings)
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                        .environmentObject(appSettings)
                }
        }
        .commands {
            CommandMenu("Worms") {
                Button("Show Task List") { showTaskList = true }
                Button("Settings") { showSettings = true }
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}
