import SwiftUI

@main
struct LibrusWatchApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                WatchScheduleView()
            }
        }
    }
}
