import SwiftUI
import FirebaseCore

@main
struct FiresaleApp: App {
    init() {
        FirebaseApp.configure()
        print("Firebase initialized at \(Date())")
    }

    var body: some Scene {
        WindowGroup {
            HomePageView() // Or ContentView if different
        }
    }
}
