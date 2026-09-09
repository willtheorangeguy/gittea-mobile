import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    @AppStorage("appearance") private var appearance = "system"
    @State private var signOut = false
    var body: some View {
        List {
            if let user = session.user {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Avatar(name: user.login, url: user.avatar_url, size: 76)
                        VStack(alignment: .leading, spacing: 4) { Text(user.displayName).font(.system(.title, design: .rounded, weight: .bold)); Text("@\(user.login)").font(.body).foregroundStyle(.secondary) }
                        if let bio = user.description, !bio.isEmpty { Text(bio).font(.subheadline).lineSpacing(3) }
                        if let location = user.location, !location.isEmpty { Label(location, systemImage: "mappin.and.ellipse").font(.subheadline).foregroundStyle(.secondary) }
                        HStack(spacing: 20) { Label("\(user.followers_count ?? 0) followers", systemImage: "person.2"); Text("\(user.following_count ?? 0) following") }.font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 10)
                }
            }
            Section {
                NavigationLink { RepositoryListView() } label: { Label("Repositories", systemImage: "books.vertical") }
                NavigationLink { RepositoryListView(source: .starred) } label: { Label("Starred repositories", systemImage: "star") }
                NavigationLink { OrganizationListView() } label: { Label("Organizations", systemImage: "building.2") }
                WebLink(title: "View Gitea profile", url: session.user?.html_url)
            }
            Section("Your instance") {
                LabeledContent("Server", value: session.isDemo ? "Demo account" : session.client?.baseURL.absoluteString ?? "").font(.subheadline).textSelection(.enabled)
                if session.isDemo { Text("Sample data lives on this device. Try comments, reviews, stars, and issues without affecting a real server.").font(.caption).foregroundStyle(.secondary) }
                else { Label("Access token secured in Keychain", systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary) }
                Button(session.isDemo ? "Connect your Gitea server" : "Sign out / change server", role: session.isDemo ? nil : .destructive) {
                    if session.isDemo { session.signOut() } else { signOut = true }
                }.accessibilityIdentifier("signOut")
                if let error = session.error { Text(error).font(.caption).foregroundStyle(.red) }
            }
            Section("Preferences") {
                NavigationLink { NotificationSettingsView() } label: { Label("Device alerts", systemImage: "bell.badge") }
                Picker(selection: $appearance) {
                    Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark")
                } label: { Label("Appearance", systemImage: "circle.lefthalf.filled") }
            }
            Section {
                HStack { Image(systemName: "cup.and.saucer.fill").foregroundStyle(Brand.green); Text("Gitea Mobile").fontWeight(.semibold); Spacer(); Text("1.0.0").foregroundStyle(.secondary) }.font(.subheadline)
                Text("An independent client for Gitea. Built for your own little corner of the internet.").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Profile")
            .confirmationDialog("Sign out of this Gitea server?", isPresented: $signOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { session.signOut() }
            } message: { Text("Your access token will be removed from this device.") }
    }
}

struct OrganizationListView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var model = PageModel<Organization>()
    var body: some View {
        List {
            ForEach(model.items) { org in
                NavigationLink { RepositoryListView(source: .organization, organization: org.name) } label: {
                    HStack(spacing: 14) {
                        Avatar(name: org.name, url: org.avatar_url, size: 44)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(org.full_name?.isEmpty == false ? org.full_name! : org.name).font(.headline)
                            Text("@\(org.name)").font(.caption).foregroundStyle(.secondary)
                            if let description = org.description, !description.isEmpty { Text(description).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
                        }
                    }.padding(.vertical, 6)
                }
            }
            PageFooter(model: model, emptyTitle: "Better together", emptySymbol: "building.2", emptyDescription: "Organizations you belong to will appear here.", retry: reload, more: { await model.next(fetch) })
        }.navigationTitle("Organizations").task { await reload() }.refreshable { await reload() }
    }
    private func fetch(_ page: Int) async throws -> [Organization] { guard let api = session.client else { return [] }; return try await api.get("user/orgs", query: APIClient.page(page)) }
    private func reload() async { await model.reload(fetch) }
}
