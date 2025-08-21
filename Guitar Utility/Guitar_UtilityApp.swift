import SwiftUI

@main
struct Guitar_UtilityApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 500, height: 800)
    }
}
