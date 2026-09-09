import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: AppSession
    @State private var error: String?
    @State private var loading = false
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(session.isDemo ? "DEMO WORKSPACE" : "YOUR WORKSPACE", systemImage: "circle.fill")
                            .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(Brand.green)
                        Spacer()
                        Image(systemName: "cup.and.saucer").font(.title2).foregroundStyle(Brand.green)
                    }
                    Text("Let’s build something good.").font(.system(.title2, design: .rounded, weight: .bold)).tracking(-0.5)
                    Text(session.isDemo ? "Welcome back, Alex. Your projects are right here." : "Welcome back, \(session.user?.displayName ?? "friend"). Pick up where you left off.")
                        .font(.subheadline).foregroundStyle(.secondary).lineSpacing(3)
                }.padding(.vertical, 10)
            }.listRowBackground(Brand.green.opacity(0.065))
            Section("My work") {
                NavigationLink { WorkListView(kind: .issues) } label: { workRow("Issues", "smallcircle.filled.circle", .green) }
                NavigationLink { WorkListView(kind: .pulls) } label: { workRow("Pull requests", "arrow.triangle.pull", .blue) }
                NavigationLink { RepositoryListView() } label: { workRow("Repositories", "books.vertical", .indigo) }
                NavigationLink { OrganizationListView() } label: { workRow("Organizations", "building.2", .orange) }
                NavigationLink { RepositoryListView(source: .starred) } label: { workRow("Starred", "star", .yellow) }
            }
            Section {
                if let error { ErrorNotice(message: error) { Task { await load() } } }
                if loading && session.repositories.isEmpty { ProgressView().frame(maxWidth: .infinity) }
                ForEach(session.repositories.prefix(4)) { repo in
                    NavigationLink { RepositoryDetailView(repo: repo) } label: { RepositoryRow(repo: repo) }
                }
                if !loading && error == nil && session.repositories.isEmpty {
                    ContentUnavailableView("Your next project starts here", systemImage: "books.vertical", description: Text("Repositories you can access will appear here."))
                }
                NavigationLink("View all repositories") { RepositoryListView() }.font(.subheadline.weight(.semibold)).foregroundStyle(Brand.green)
            } header: { Text("Your repositories") }
            if session.isDemo {
                Section { Label("You’re exploring sample projects. Connect your server from Profile when you’re ready.", systemImage: "sparkles").font(.caption).foregroundStyle(.secondary) }
            }
        }.navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { NavigationLink { ExploreView() } label: { Image(systemName: "magnifyingglass") }.accessibilityLabel("Search Gitea") }
            }
            .task { await load() }.refreshable { await load() }
    }
    private func workRow(_ title: String, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 12) { SymbolTile(symbol: symbol, color: color); Text(title).font(.body.weight(.medium)) }.padding(.vertical, 2)
    }
    private func load() async {
        guard let api = session.client else { return }
        loading = true
        defer { loading = false }
        do { session.repositories = try await api.get("user/repos", query: APIClient.page(1)); error = nil }
        catch is CancellationError { }
        catch { self.error = error.localizedDescription }
        do { session.notifications = try await api.get("notifications", query: APIClient.page(1)) }
        catch { /* Notification failures are surfaced by the Notifications tab. */ }
    }
}
