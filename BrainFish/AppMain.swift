import SwiftUI

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
