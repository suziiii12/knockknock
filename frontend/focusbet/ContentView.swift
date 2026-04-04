import SwiftUI

enum Route: Hashable {
    case home
    case start
    case session(duration: Int, buildingId: String)
    case result(focusScore: Int, buildingId: String, duration: Int)
    case map
    case building(id: String)
    case history
    case profile
    case howItWorks
}

// MARK: - Root view with auth gate

struct ContentView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    @AppStorage("isProfileComplete") private var isProfileComplete = false
    @AppStorage("isAdmin") private var isAdmin = false
    @State private var showWorldID = false

    var body: some View {
        Group {
            if isAdmin {
                AdminDashboardView()
            } else if !isLoggedIn && !showWorldID {
                WelcomeView(onSignIn: { showWorldID = true })
            } else if !isLoggedIn && showWorldID {
                WorldIDView()
            } else if !isProfileComplete {
                ProfileSetupView()
            } else {
                MainAppView()
            }
        }
    }
}

// MARK: - Main app (existing navigation)

struct MainAppView: View {
    @State private var navigationPath = NavigationPath()
    @State private var activeTab: String = "focus"

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(
                activeTab: $activeTab,
                onNavigate: { route in
                    navigationPath = NavigationPath()
                    navigationPath.append(route)
                }
            )

            NavigationStack(path: $navigationPath) {
                HomeView(onNavigate: { route in
                    activeTab = tabForRoute(route)
                    navigationPath.append(route)
                })
                .navigationDestination(for: Route.self) { route in
                    destinationView(for: route)
                }
            }
        }
        .background(AppColors.bgPrimary)
    }

    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .home:
            HomeView(onNavigate: { r in
                activeTab = tabForRoute(r)
                navigationPath.append(r)
            })
        case .start:
            StartSessionView(onNavigate: { r in
                navigationPath.append(r)
            })
        case .session(let duration, let buildingId):
            SessionView(duration: duration, buildingId: buildingId, onNavigate: { r in
                navigationPath.append(r)
            })
        case .result(let focusScore, let buildingId, let duration):
            ResultView(focusScore: focusScore, buildingId: buildingId, duration: duration, onNavigate: { r in
                navigationPath = NavigationPath()
                activeTab = tabForRoute(r)
                navigationPath.append(r)
            })
        case .map:
            CampusMapView(onNavigate: { r in
                navigationPath.append(r)
            })
        case .building(let id):
            BuildingDetailView(buildingId: id)
        case .history:
            HistoryView()
        case .profile:
            ProfileView()
        case .howItWorks:
            HowItWorksView(onNavigate: { r in
                navigationPath.append(r)
            })
        }
    }

    private func tabForRoute(_ route: Route) -> String {
        switch route {
        case .home, .start, .session, .result, .howItWorks: return "focus"
        case .history: return "history"
        case .map, .building: return "map"
        case .profile: return "profile"
        }
    }
}
