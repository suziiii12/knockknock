import SwiftUI

@main
struct FocusBetApp: App {
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
                .preferredColorScheme(.light)
                .background(AppColors.bgPrimary)
                .environment(authViewModel)
                .task {
                    // Restore JWT from Keychain on every launch so returning
                    // users skip the World ID flow if their token is still valid.
                    authViewModel.restoreAuthState()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
    }
}
