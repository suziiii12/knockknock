import SwiftUI

@main
struct FocusBetApp: App {
    init() {
        // TEMPORARY: reset auth for testing — comment out after confirming flow works
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        UserDefaults.standard.set(false, forKey: "isProfileComplete")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(.dark)
                .background(AppColors.bgPrimary)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
    }
}
