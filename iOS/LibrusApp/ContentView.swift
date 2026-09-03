import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PhoneScheduleView()
                .tabItem {
                    Label("Plan lekcji", systemImage: "calendar")
                }

            LoginSettingsView()
                .tabItem {
                    Label("Ustawienia", systemImage: "gear")
                }
        }
    }
}
