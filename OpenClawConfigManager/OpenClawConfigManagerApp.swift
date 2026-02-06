import SwiftUI

@main
struct OpenClawConfigManagerApp: App {
    var body: some Scene {
        WindowGroup("OpenClaw Config Manager") {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 500, height: 450)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About OpenClaw Config Manager") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [NSApplication.AboutPanelOptionKey.init(rawValue: "Copyright"): "© 2026 OpenClaw Team"]
                    )
                }
            }
        }
    }
}
