import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var session: AppSession
    @State private var query = ""
    @State private var kind = "repositories"
    @StateObject private var repos = PageModel<Repository>()
    @StateObject private var work = PageModel<Issue>()
    var body: some View {
        List {
            Section {
                Picker("Search category", selection: $kind) { Text("Repositories").tag("repositories"); Text("Issues").tag("issues"); Text("Pull requests").tag("pulls") }.pickerStyle(.segmented)
            }
            if query.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "safari").font(.system(size: 36, weight: .light)).foregroundStyle(Brand.green)
                        Text("Find your next rabbit hole.").font(.system(.title2, design: .rounded, weight: .bold))
                        Text("Explore projects and conversations on your Gitea server.").font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 12)
                }.listRowBackground(Brand.green.opacity(0.065))
            }
            if kind == "repositories" {
                Section(query.isEmpty ? "Discover repositories" : "Repositories") {
                    ForEach(repos.items) { repo in NavigationLink { RepositoryDetailView(repo: repo) } label: { RepositoryRow(repo: repo) } }
                    PageFooter(model: repos, emptyTitle: "No repositories found", emptySymbol: "magnifyingglass", emptyDescription: "Try a different name or keyword.", retry: reload, more: { await repos.next(fetchRepos) })
                }
            } else {
                Section {
                    ForEach(work.items) { issue in NavigationLink { IssueDestination(issue: issue) } label: { IssueRow(issue: issue, showRepository: true) } }
                    PageFooter(model: work, emptyTitle: "No conversations found", emptySymbol: "magnifyingglass", emptyDescription: "Try a different name or keyword.", retry: reload, more: { await work.next(fetchWork) })
                }
            }
        }.navigationTitle("Explore").searchable(text: $query, prompt: "Search your Gitea server")
            .task(id: kind + ":" + query) {
                do { try await Task.sleep(for: .milliseconds(300)); await reload() } catch { }
            }.refreshable { await reload() }
    }
    private func fetchRepos(_ page: Int) async throws -> [Repository] {
        guard let api = session.client else { return [] }
        let result: SearchResults<Repository> = try await api.get("repos/search", query: APIClient.page(page) + [.init(name: "q", value: query), .init(name: "sort", value: "updated"), .init(name: "order", value: "desc")])
        return result.data ?? []
    }
    private func fetchWork(_ page: Int) async throws -> [Issue] {
        guard let api = session.client else { return [] }
        return try await api.get("repos/issues/search", query: APIClient.page(page) + [.init(name: "q", value: query), .init(name: "type", value: kind), .init(name: "state", value: "all")])
    }
    private func reload() async { if kind == "repositories" { await repos.reload(fetchRepos) } else { await work.reload(fetchWork) } }
}
