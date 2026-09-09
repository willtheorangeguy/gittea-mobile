import SwiftUI

enum RepositorySource: String { case mine, starred, organization }

struct RepositoryListView: View {
    @EnvironmentObject private var session: AppSession
    var source: RepositorySource = .mine
    var organization: String = ""
    @StateObject private var model = PageModel<Repository>()
    @State private var query = ""
    private var title: String { source == .starred ? "Starred" : source == .organization ? organization : "Repositories" }
    var body: some View {
        List {
            ForEach(model.items.filter { query.isEmpty || $0.full_name.localizedCaseInsensitiveContains(query) }) { repo in
                NavigationLink { RepositoryDetailView(repo: repo) } label: { RepositoryRow(repo: repo) }
            }
            if !query.isEmpty && !model.items.isEmpty && !model.items.contains(where: { $0.full_name.localizedCaseInsensitiveContains(query) }) {
                Text("No matches in the loaded repositories. Load more below, or search the whole server in Explore.").font(.subheadline).foregroundStyle(.secondary)
            }
            PageFooter(model: model, emptyTitle: source == .starred ? "Your favorites belong here" : "No repositories yet", emptySymbol: "books.vertical", emptyDescription: source == .starred ? "Star a repository to keep it close." : "Repositories you can access will appear here.", retry: reload, more: { await model.next(fetch) })
        }.navigationTitle(title).searchable(text: $query, prompt: "Filter loaded repositories")
            .task { await reload() }.refreshable { await reload() }
    }
    private func fetch(_ page: Int) async throws -> [Repository] {
        guard let api = session.client else { return [] }
        let path = source == .starred ? "user/starred" : source == .organization ? "orgs/\(APIClient.segment(organization))/repos" : "user/repos"
        return try await api.get(path, query: APIClient.page(page))
    }
    private func reload() async { await model.reload(fetch) }
}

struct RepositoryDetailView: View {
    @EnvironmentObject private var session: AppSession
    let repo: Repository
    @State private var starred = false
    @State private var starLoaded = false
    @State private var busy = false
    @State private var error: String?
    @State private var readme: String?
    @State private var readmeError: String?
    @State private var loading = true
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack { Avatar(name: repo.owner.login, url: repo.owner.avatar_url, size: 28); Text(repo.owner.login).foregroundStyle(.secondary); Spacer(); Text(repo.private == true ? "Private" : "Public").font(.caption).padding(.horizontal, 9).padding(.vertical, 4).background(Brand.background, in: Capsule()) }
                    Text(repo.name).font(.system(.title, design: .rounded, weight: .bold)).textSelection(.enabled)
                    if let description = repo.description, !description.isEmpty { Text(description).font(.subheadline).foregroundStyle(.secondary).lineSpacing(3) }
                    HStack(spacing: 18) {
                        Label("\(repo.stars_count ?? 0) stars", systemImage: "star")
                        Label("\(repo.forks_count ?? 0) forks", systemImage: "arrow.triangle.branch")
                    }.font(.caption).foregroundStyle(.secondary)
                    Button {
                        Task { await toggleStar() }
                    } label: {
                        Label(starred ? "Starred" : "Star repository", systemImage: starred ? "star.fill" : "star")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 4)
                    }.buttonStyle(.bordered).disabled(busy || !starLoaded).accessibilityIdentifier("starRepository")
                }.padding(.vertical, 8)
            }
            Section {
                NavigationLink { CodeBrowserView(repo: repo) } label: { detailRow("Code", "chevron.left.forwardslash.chevron.right", .indigo) }
                NavigationLink { WorkListView(kind: .issues, repo: repo) } label: { detailRow("Issues", "smallcircle.filled.circle", Brand.green, repo.open_issues_count) }
                NavigationLink { WorkListView(kind: .pulls, repo: repo) } label: { detailRow("Pull requests", "arrow.triangle.pull", .blue, repo.open_pr_counter) }
                NavigationLink { CommitListView(repo: repo) } label: { detailRow("Commits", "clock.arrow.circlepath", .orange) }
                NavigationLink { ReleaseListView(repo: repo) } label: { detailRow("Releases", "tag", .purple) }
                WebLink(title: "Open in browser", url: repo.html_url)
            }
            Section {
                if loading { ProgressView().frame(maxWidth: .infinity) }
                else if let readme { MarkdownView(text: readme).padding(.vertical, 10) }
                else if let readmeError { ErrorNotice(message: readmeError) { Task { await load() } } }
                else { Text("This repository doesn’t have a README.md on its default branch.").font(.subheadline).foregroundStyle(.secondary) }
            } header: { Label("README.md", systemImage: "doc.text") }
        }.navigationTitle(repo.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { if let url = URL(string: repo.html_url ?? "") { ShareLink(item: url) } }
            .task { await load() }.refreshable { await load() }
            .alert("Couldn’t update repository", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) { } } message: { Text(error ?? "") }
    }
    private func detailRow(_ title: String, _ symbol: String, _ color: Color, _ count: Int? = nil) -> some View {
        HStack(spacing: 12) { SymbolTile(symbol: symbol, color: color); Text(title); Spacer(); if let count { Text(count.formatted()).font(.subheadline).foregroundStyle(.secondary) } }
    }
    private func load() async {
        guard let api = session.client else { return }
        loading = true
        defer { loading = false }
        do { starred = try await api.isStarred(repo); starLoaded = true }
        catch { self.error = error.localizedDescription }
        do {
            let file: RepositoryContent = try await api.get(repo.path + "/contents/README.md", query: [.init(name: "ref", value: repo.default_branch ?? "main")])
            readme = file.decodedText; readmeError = nil
        } catch GiteaError.server(404, _) { readme = nil; readmeError = nil }
        catch { readmeError = error.localizedDescription }
    }
    private func toggleStar() async {
        guard let api = session.client, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            try await api.mutate("user/starred/\(APIClient.segment(repo.owner.login))/\(APIClient.segment(repo.name))", method: starred ? "DELETE" : "PUT")
            starred.toggle()
        } catch { self.error = error.localizedDescription }
    }
}

struct CodeBrowserView: View {
    @EnvironmentObject private var session: AppSession
    let repo: Repository
    var path = ""
    var initialBranch: String? = nil
    @State private var branch = ""
    @State private var branches: [Branch] = []
    @State private var files: [RepositoryContent] = []
    @State private var loading = true
    @State private var error: String?
    @State private var showBranches = false
    var body: some View {
        List {
            Section {
                Button { showBranches = true } label: {
                    HStack { Label(branch.isEmpty ? repo.default_branch ?? "main" : branch, systemImage: "arrow.triangle.branch"); Spacer(); Image(systemName: "chevron.down").font(.caption) }
                }.accessibilityIdentifier("branchPicker")
                if !path.isEmpty { Text(path).font(.caption.monospaced()).foregroundStyle(.secondary) }
            }
            Section {
                if loading { ProgressView().frame(maxWidth: .infinity) }
                else if let error { ErrorNotice(message: error) { Task { await load() } } }
                else if files.isEmpty { ContentUnavailableView("No files yet", systemImage: "folder", description: Text("This branch is empty.")) }
                ForEach(files.sorted {
                    if ($0.type == "dir") != ($1.type == "dir") { return $0.type == "dir" }
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }) { file in
                    NavigationLink {
                        if file.type == "dir" { CodeBrowserView(repo: repo, path: file.path, initialBranch: branch) }
                        else { FileView(repo: repo, file: file, branch: branch) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: file.type == "dir" ? "folder.fill" : "doc.text").foregroundStyle(file.type == "dir" ? .blue : .secondary)
                            Text(file.name).font(.subheadline.monospaced())
                            Spacer()
                            if file.type != "dir", let size = file.size { Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)).font(.caption).foregroundStyle(.tertiary) }
                        }.padding(.vertical, 5)
                    }
                }
            }
        }.navigationTitle(path.isEmpty ? "Code" : path.components(separatedBy: "/").last ?? "Code").navigationBarTitleDisplayMode(.inline)
            .task { branch = initialBranch ?? repo.default_branch ?? "main"; await load() }
            .refreshable { await load() }
            .sheet(isPresented: $showBranches) {
                BranchPicker(repo: repo, selection: $branch).onDisappear { Task { await load() } }
            }
    }
    private func load() async {
        guard let api = session.client else { return }
        loading = true
        error = nil
        defer { loading = false }
        if repo.empty == true { files = []; return }
        do {
            let encodedPath = path.split(separator: "/").map { APIClient.segment(String($0)) }.joined(separator: "/")
            files = try await api.get(repo.path + "/contents" + (encodedPath.isEmpty ? "" : "/" + encodedPath), query: [.init(name: "ref", value: branch)])
        } catch { self.error = error.localizedDescription; files = [] }
    }
}

struct BranchPicker: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let repo: Repository
    @Binding var selection: String
    @StateObject private var model = PageModel<Branch>()
    var body: some View {
        NavigationStack {
            List {
                ForEach(model.items) { branch in
                    Button { selection = branch.name; dismiss() } label: {
                        HStack { Label(branch.name, systemImage: "arrow.triangle.branch"); Spacer(); if selection == branch.name { Image(systemName: "checkmark") } }
                    }
                }
                PageFooter(model: model, retry: reload, more: { await model.next(fetch) })
            }.navigationTitle("Switch branch").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
                .task { await reload() }
        }
    }
    private func fetch(_ page: Int) async throws -> [Branch] { guard let api = session.client else { return [] }; return try await api.get(repo.path + "/branches", query: APIClient.page(page)) }
    private func reload() async { await model.reload(fetch) }
}

struct FileView: View {
    @EnvironmentObject private var session: AppSession
    let repo: Repository
    let file: RepositoryContent
    let branch: String
    @State private var text: String?
    @State private var error: String?
    @State private var loading = true
    @State private var preview = true
    var body: some View {
        Group {
            if loading { ProgressView("Loading file…") }
            else if let error { ErrorNotice(message: error) { Task { await load() } }.padding() }
            else if let text {
                if file.name.lowercased().hasSuffix(".md") && preview { ScrollView { MarkdownView(text: text).padding(20) } }
                else { SourceCodeView(text: text) }
            } else {
                ContentUnavailableView { Label("Preview unavailable", systemImage: "doc") } description: { Text("This file is binary, isn’t UTF-8 text, or is larger than the 1 MB preview limit.") } actions: { WebLink(title: "Open file in browser", url: file.html_url) }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Brand.card)
            .navigationTitle(file.name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if file.name.lowercased().hasSuffix(".md") { Button(preview ? "Source" : "Preview") { preview.toggle() } }
                if let text { ShareLink(item: text) }
            }.task { await load() }
    }
    private func load() async {
        guard let api = session.client else { return }
        loading = true; error = nil
        defer { loading = false }
        guard (file.size ?? 0) <= 1_000_000 else { return }
        do {
            let route = file.path.split(separator: "/").map { APIClient.segment(String($0)) }.joined(separator: "/")
            let content: RepositoryContent = try await api.get(repo.path + "/contents/" + route, query: [.init(name: "ref", value: branch)])
            text = (content.size ?? 0) <= 1_000_000 ? content.decodedText : nil
        } catch { self.error = error.localizedDescription }
    }
}

struct SourceCodeView: View {
    let text: String
    var diff = false
    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .top, spacing: 16) {
                        Text("\(index + 1)").foregroundStyle(.tertiary).frame(width: 40, alignment: .trailing).accessibilityHidden(true)
                        Text(line.isEmpty ? " " : line).foregroundStyle(lineColor(line)).textSelection(.enabled)
                    }.font(.system(size: 12, design: .monospaced)).padding(.vertical, 3).padding(.trailing, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(diff && line.hasPrefix("+") ? Brand.green.opacity(0.08) : diff && line.hasPrefix("-") ? Color.red.opacity(0.08) : .clear)
                }
            }.padding(.vertical, 12)
        }.background(Brand.card)
    }
    private func lineColor(_ line: String) -> Color {
        if diff { return line.hasPrefix("+") ? Brand.green : line.hasPrefix("-") ? .red : line.hasPrefix("@@") ? .blue : .primary }
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") { return .secondary }
        return .primary
    }
}

struct CommitListView: View {
    @EnvironmentObject private var session: AppSession
    let repo: Repository
    @StateObject private var model = PageModel<Commit>()
    var body: some View {
        List {
            ForEach(model.items) { commit in
                VStack(alignment: .leading, spacing: 10) {
                    Text(commit.commit.message).font(.subheadline.weight(.semibold)).textSelection(.enabled)
                    HStack { Avatar(name: commit.author?.login ?? commit.commit.author?.name ?? "", url: commit.author?.avatar_url, size: 22); Text(commit.commit.author?.name ?? "Unknown"); Spacer(); Text(String(commit.sha.prefix(7))).monospaced() }.font(.caption).foregroundStyle(.secondary)
                    Text(DateText.relative(commit.commit.author?.date)).font(.caption).foregroundStyle(.tertiary)
                    WebLink(title: "View commit", url: commit.html_url).font(.caption)
                }.padding(.vertical, 6)
            }
            PageFooter(model: model, emptyTitle: "No commits yet", retry: reload, more: { await model.next(fetch) })
        }.navigationTitle("Commits").task { await reload() }.refreshable { await reload() }
    }
    private func fetch(_ page: Int) async throws -> [Commit] { guard let api = session.client, repo.empty != true else { return [] }; return try await api.get(repo.path + "/commits", query: APIClient.page(page)) }
    private func reload() async { await model.reload(fetch) }
}

struct ReleaseListView: View {
    @EnvironmentObject private var session: AppSession
    let repo: Repository
    @StateObject private var model = PageModel<Release>()
    var body: some View {
        List {
            ForEach(model.items) { release in
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Label(release.tag_name, systemImage: "tag").font(.caption.weight(.semibold)).foregroundStyle(Brand.green)
                        Text(release.name?.isEmpty == false ? release.name! : release.tag_name).font(.title3.bold())
                        if release.prerelease == true { Text("Pre-release").font(.caption).foregroundStyle(.orange) }
                        Text(DateText.relative(release.published_at)).font(.caption).foregroundStyle(.secondary)
                        MarkdownView(text: release.body ?? "No release notes.")
                        ForEach(release.assets ?? []) { asset in WebLink(title: asset.name, url: asset.browser_download_url).font(.subheadline) }
                        WebLink(title: "View release", url: release.html_url).font(.subheadline)
                    }.padding(.vertical, 8)
                }
            }
            PageFooter(model: model, emptyTitle: "No releases yet", emptySymbol: "tag", retry: reload, more: { await model.next(fetch) })
        }.navigationTitle("Releases").task { await reload() }.refreshable { await reload() }
    }
    private func fetch(_ page: Int) async throws -> [Release] { guard let api = session.client else { return [] }; return try await api.get(repo.path + "/releases", query: APIClient.page(page)) }
    private func reload() async { await model.reload(fetch) }
}
