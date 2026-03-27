import SwiftUI

@main
struct ClaudeWorkApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appState)
                .focusable(false)
                .task {
                    await appState.initialize()
                }
        }
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("새 대화") {
                    appState.startNewChat()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
