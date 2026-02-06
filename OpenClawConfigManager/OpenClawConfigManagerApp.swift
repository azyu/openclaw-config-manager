import SwiftUI

@main
struct OpenClawConfigManagerApp: App {
    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Image("LobsterIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.window)
    }
}
