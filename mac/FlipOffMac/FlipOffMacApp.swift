import SwiftUI
import WidgetKit

@main
struct FlipOffMacApp: App {
    var body: some Scene {
        WindowGroup("FlipOff") {
            MacContentView()
                .onOpenURL { url in
                    if url.scheme == "flipoff" && url.host == "refresh" {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
        }
        .windowResizability(.contentSize)
    }
}
