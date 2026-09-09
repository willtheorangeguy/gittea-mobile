import SwiftUI

@main @MainActor struct GiteaApp: App {
    @UIApplicationDelegateAdaptor(GiteaAppDelegate.self) private var delegate
    @StateObject private var session: AppSession
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearance = "system"
    init() {
        let session = AppSession()
        _session = StateObject(wrappedValue: session)
        NotificationService.shared.attach(session)
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if session.restoring { ProgressView("Opening Gitea…") }
                else if session.client != nil { MainTabs().id(session.accountGeneration) }
                else { ConnectView() }
            }
            .environmentObject(session)
            .tint(Brand.green)
            .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
            .task { NotificationService.shared.attach(session); await session.restore() }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                NotificationService.shared.attach(session)
                await session.restore()
                while !Task.isCancelled {
                    _ = await NotificationService.shared.checkNow()
                    do { try await Task.sleep(for: .seconds(60)) } catch { break }
                }
            }
            .onChange(of: scenePhase) { _, phase in if phase == .background { NotificationService.shared.schedule() } }
        }
    }
}

struct MainTabs: View {
    @EnvironmentObject private var session: AppSession
    @ObservedObject private var alerts = NotificationService.shared
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }.tabItem { Label("Home", systemImage: "house") }.tag(0)
            NavigationStack { NotificationsView() }.tabItem { Label("Notifications", systemImage: "bell") }.badge(session.unreadCount).tag(1)
            NavigationStack { ExploreView() }.tabItem { Label("Explore", systemImage: "safari") }.tag(2)
            NavigationStack { ProfileView() }.tabItem { Label("Profile", systemImage: "person.crop.circle") }.tag(3)
        }
        .sheet(item: $alerts.destination) { notification in
            NavigationStack {
                NotificationDestination(notification: notification)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { alerts.destination = nil } } }
            }
        }
    }
}
