import SwiftUI

enum WorkKind: String, CaseIterable { case issues, pulls
    var title: String { self == .issues ? "Issues" : "Pull requests" }
}

struct WorkListView: View {
    @EnvironmentObject private var session: AppSession
    let kind: WorkKind
    var repo: Repository? = nil
    @StateObject private var model = PageModel<Issue>()
    @State private var state = "open"
    @State private var scope = "all"
    @State private var query = ""
    @State private var compose = false
    private var requestKey: String { state + ":" + scope + ":" + query }
    var body: some View {
        List {
            Section {
                Picker("State", selection: $state) { Text("Open").tag("open"); Text("Closed").tag("closed"); Text("All").tag("all") }.pickerStyle(.segmented)
                if repo == nil {
                    Picker("Involvement", selection: $scope) {
                        Text("All accessible").tag("all"); Text("Created by me").tag("created"); Text("Assigned to me").tag("assigned"); Text("Mentioning me").tag("mentioned")
                        if kind == .pulls { Text("Review requested").tag("review_requested") }
                    }.font(.subheadline)
                }
            }
            Section {
                ForEach(model.items.filter { repo == nil || kind != .pulls || query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }) { issue in
                    NavigationLink { IssueDestination(issue: issue, repo: repo) } label: { IssueRow(issue: issue, showRepository: repo == nil) }
                }
                PageFooter(model: model, emptyTitle: "No \(state == "all" ? "" : state + " ")\(kind.title.lowercased())", emptySymbol: kind == .issues ? "checkmark.circle" : "arrow.triangle.pull", emptyDescription: "Try another filter, or start a new conversation.", retry: reload, more: { await model.next(fetch) })
            }
                if repo != nil && kind == .pulls && !query.isEmpty {
                    Text("Filtering loaded pull requests. Load more to include older results.").font(.caption).foregroundStyle(.secondary)
                }
        }.navigationTitle(kind.title).searchable(text: $query, prompt: repo != nil && kind == .pulls ? "Filter loaded pull requests" : "Search \(kind.title.lowercased())")
            .task(id: requestKey) {
                do { if !query.isEmpty { try await Task.sleep(for: .milliseconds(300)) }; await reload() } catch { }
            }.refreshable { await reload() }
            .toolbar { if let repo, repo.archived != true { Button { compose = true } label: { Image(systemName: "plus") }.accessibilityLabel(kind == .issues ? "New issue" : "New pull request") } }
            .sheet(isPresented: $compose) { if let repo { ComposeWorkView(repo: repo, kind: kind) { Task { await reload() } } } }
    }
    private func fetch(_ page: Int) async throws -> [Issue] {
        guard let api = session.client else { return [] }
        var params = APIClient.page(page) + [.init(name: "state", value: state)]
        if let repo {
            if kind == .pulls {
                let pulls: [PullRequest] = try await api.get(repo.path + "/pulls", query: params)
                // The repository pulls endpoint has no text search parameter.
                return pulls.map(\.issue)
            }
            params += [.init(name: "type", value: "issues"), .init(name: "q", value: query)]
            return try await api.get(repo.path + "/issues", query: params)
        }
        params += [.init(name: "type", value: kind.rawValue), .init(name: "q", value: query)]
        if scope != "all" { params.append(.init(name: scope, value: "true")) }
        return try await api.get("repos/issues/search", query: params)
    }
    private func reload() async { await model.reload(fetch) }
}

struct IssueDestination: View {
    @EnvironmentObject private var session: AppSession
    let issue: Issue
    var repo: Repository?
    @State private var resolved: Repository?
    @State private var error: String?
    var body: some View {
        Group {
            if let target = repo ?? resolved { IssueDetailView(repo: target, number: issue.number, isPull: issue.isPull) }
            else if let error { ErrorNotice(message: error) { Task { await resolve() } }.padding() }
            else { ProgressView("Opening conversation…") }
        }.task { if repo == nil { await resolve() } }
    }
    private func resolve() async {
        guard let api = session.client else { return }
        error = nil
        do {
            let owner: String
            let name: String
            if let ref = issue.repository, let o = ref.owner, let n = ref.name { owner = o; name = n }
            else if let fullName = issue.repository?.full_name, fullName.split(separator: "/").count == 2 {
                owner = String(fullName.split(separator: "/")[0]); name = String(fullName.split(separator: "/")[1])
            } else { throw GiteaError.invalidResponse }
            resolved = try await api.get("repos/\(APIClient.segment(owner))/\(APIClient.segment(name))")
        } catch { self.error = error.localizedDescription }
    }
}

struct IssueDetailView: View {
    @EnvironmentObject private var session: AppSession
    let repo: Repository
    let number: Int
    var isPull = false
    @State private var issue: Issue?
    @State private var pull: PullRequest?
    @StateObject private var comments = PageModel<IssueComment>()
    @StateObject private var reviews = PageModel<PullReview>()
    @State private var error: String?
    @State private var actionError: String?
    @State private var busy = false
    @State private var compose = false
    @State private var review = false
    @State private var merge = false
    @State private var changeState = false
    private var canEdit: Bool { repo.archived != true && (repo.permissions?.push == true || issue?.user?.id == session.user?.id) }
    var body: some View {
        List {
            if let issue {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(repo.full_name).font(.subheadline).foregroundStyle(.secondary)
                        Text(issue.title).font(.system(.title2, design: .rounded, weight: .bold)).textSelection(.enabled)
                        HStack(spacing: 10) {
                            Label(pull?.merged == true ? "Merged" : issue.state.capitalized, systemImage: isPull ? "arrow.triangle.pull" : "smallcircle.filled.circle")
                                .font(.caption.weight(.semibold)).foregroundStyle(.white).padding(.horizontal, 11).padding(.vertical, 6)
                                .background(issue.state == "open" ? Brand.green : .purple, in: Capsule())
                            Text("#\(number)").foregroundStyle(.secondary)
                            if pull?.draft == true { Text("Draft").font(.caption).foregroundStyle(.secondary) }
                        }
                        HStack { Avatar(name: issue.user?.login ?? "", url: issue.user?.avatar_url, size: 24); Text(issue.user?.login ?? "Unknown"); Text("opened \(DateText.relative(issue.created_at))") }.font(.caption).foregroundStyle(.secondary)
                        if let labels = issue.labels, !labels.isEmpty { ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(labels) { LabelPill(label: $0) } } } }
                    }.padding(.vertical, 8)
                }
                if let pull {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(pull.head?.ref ?? "branch") → \(pull.base?.ref ?? "base")").font(.caption.monospaced()).foregroundStyle(.secondary)
                            HStack { Text("+\(pull.additions ?? 0)").foregroundStyle(Brand.green); Text("−\(pull.deletions ?? 0)").foregroundStyle(.red); Text("in \(pull.changed_files ?? 0) files").foregroundStyle(.secondary) }.font(.caption.weight(.semibold))
                        }
                        NavigationLink { PullFilesView(repo: repo, number: number) } label: { Label("Files changed", systemImage: "doc.on.doc") }
                        if pull.state == "open" && repo.archived != true {
                            Button { review = true } label: { Label("Review changes", systemImage: "text.bubble") }
                            if repo.permissions?.push == true && pull.draft != true {
                                Button { merge = true } label: { Label("Merge pull request", systemImage: "arrow.triangle.merge") }
                                    .disabled(pull.mergeable != true)
                                if pull.mergeable != true { Text("This pull request can’t be merged yet. Resolve conflicts or check its status on your server.").font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
                Section("Description") { MarkdownView(text: issue.body?.isEmpty == false ? issue.body! : "No description provided.").padding(.vertical, 8) }
                Section("Conversation") {
                    ForEach(comments.items) { comment in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Avatar(name: comment.user?.login ?? "", url: comment.user?.avatar_url, size: 28); Text(comment.user?.login ?? "Unknown").font(.subheadline.weight(.semibold)); Spacer(); Text(DateText.relative(comment.created_at)).font(.caption).foregroundStyle(.secondary) }
                            MarkdownView(text: comment.body)
                        }.padding(.vertical, 8)
                    }
                    PageFooter(model: comments, emptyTitle: "Start the conversation", emptySymbol: "bubble.left.and.bubble.right", emptyDescription: "Share an idea, ask a question, or leave some feedback.", retry: reloadComments, more: { await comments.next(fetchComments) })
                    if repo.archived != true { Button { compose = true } label: { Label("Add a comment", systemImage: "square.and.pencil").fontWeight(.semibold) }.accessibilityIdentifier("addComment") }
                }
                if isPull {
                    Section("Reviews") {
                        ForEach(reviews.items) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Label("\(item.user?.login ?? "Someone") · \((item.state ?? "COMMENT").replacingOccurrences(of: "_", with: " ").capitalized)", systemImage: item.state == "APPROVED" ? "checkmark.seal" : "text.bubble").font(.subheadline.weight(.semibold))
                                if let body = item.body, !body.isEmpty { MarkdownView(text: body) }
                            }.padding(.vertical, 6)
                        }
                        PageFooter(model: reviews, emptyTitle: "No reviews yet", emptySymbol: "text.bubble", emptyDescription: "Submitted reviews will appear here.", retry: { await reviews.reload(fetchReviews) }, more: { await reviews.next(fetchReviews) })
                    }
                }
                Section {
                    WebLink(title: "Open in browser", url: issue.html_url)
                    if canEdit && pull?.merged != true {
                        Button(issue.state == "open" ? "Close \(isPull ? "pull request" : "issue")" : "Reopen \(isPull ? "pull request" : "issue")") { changeState = true }.disabled(busy)
                    }
                }
            } else if let error { ErrorNotice(message: error) { Task { await load() } } }
            else { ProgressView("Loading conversation…").frame(maxWidth: .infinity) }
        }.navigationTitle("\(isPull ? "Pull request" : "Issue") #\(number)").navigationBarTitleDisplayMode(.inline)
            .task { await load() }.refreshable { await load() }
            .sheet(isPresented: $compose) { CommentComposer(repo: repo, number: number) { Task { await reloadComments() } } }
            .sheet(isPresented: $review) { ReviewComposer(repo: repo, number: number, commitID: pull?.head?.sha) { Task { await reviews.reload(fetchReviews) } } }
            .sheet(isPresented: $merge) { if let pull { MergeView(repo: repo, pull: pull) { Task { await load() } } } }
            .confirmationDialog(issue?.state == "open" ? "Close this conversation?" : "Reopen this conversation?", isPresented: $changeState, titleVisibility: .visible) {
                Button(issue?.state == "open" ? "Close conversation" : "Reopen conversation") { Task { await updateState() } }
            }
            .alert("Couldn’t complete action", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) { Button("OK", role: .cancel) { } } message: { Text(actionError ?? "") }
    }
    private func load() async {
        guard let api = session.client else { return }
        do {
            if isPull { let value: PullRequest = try await api.get(repo.path + "/pulls/\(number)"); pull = value; issue = value.issue }
            else { issue = try await api.get(repo.path + "/issues/\(number)") }
            error = nil
        } catch { if issue == nil { self.error = error.localizedDescription } else { actionError = error.localizedDescription } }
        await reloadComments()
        if isPull { await reviews.reload(fetchReviews) }
    }
    private func fetchComments(_ page: Int) async throws -> [IssueComment] { guard let api = session.client else { return [] }; return try await api.get(repo.path + "/issues/\(number)/comments", query: APIClient.page(page)) }
    private func reloadComments() async { await comments.reload(fetchComments) }
    private func fetchReviews(_ page: Int) async throws -> [PullReview] { guard let api = session.client else { return [] }; return try await api.get(repo.path + "/pulls/\(number)/reviews", query: APIClient.page(page)) }
    private func updateState() async {
        guard let api = session.client, let issue else { return }
        busy = true
        defer { busy = false }
        do {
            try await api.mutate(repo.path + "/issues/\(number)", method: "PATCH", body: ["state": issue.state == "open" ? "closed" : "open"])
            await load()
        } catch { actionError = error.localizedDescription }
    }
}

struct ComposeWorkView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let repo: Repository
    let kind: WorkKind
    let onComplete: () -> Void
    @State private var title = ""
    @State private var bodyText = ""
    @State private var head = ""
    @State private var base = ""
    @State private var busy = false
    @State private var error: String?
    @State private var preview = false
    var body: some View {
        NavigationStack {
            Form {
                Section { Label(repo.full_name, systemImage: "books.vertical").font(.subheadline).foregroundStyle(.secondary); TextField("Title", text: $title).accessibilityIdentifier("workTitle") }
                if kind == .pulls {
                    Section("Branches in this repository") {
                        TextField("Base branch", text: $base).textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("Compare branch", text: $head).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                }
                Section {
                    if preview { MarkdownView(text: bodyText.isEmpty ? "Nothing to preview yet." : bodyText) }
                    else { TextEditor(text: $bodyText).frame(minHeight: 220).accessibilityLabel("Description").accessibilityIdentifier("workBody") }
                } header: { HStack { Text("Description · Markdown supported"); Spacer(); Button(preview ? "Edit" : "Preview") { preview.toggle() } } }
                if let error { Section { Text(error).foregroundStyle(.red).font(.subheadline) } }
            }.navigationTitle(kind == .issues ? "New issue" : "New pull request").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) }
                    ToolbarItem(placement: .confirmationAction) { Button(busy ? "Creating…" : "Create") { Task { await submit() } }.fontWeight(.semibold).disabled(busy || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (kind == .pulls && (head.isEmpty || base.isEmpty || head == base))).accessibilityIdentifier("createWork") }
                }.interactiveDismissDisabled(busy).onAppear { base = repo.default_branch ?? "main" }
        }
    }
    private func submit() async {
        guard let api = session.client else { return }
        busy = true; defer { busy = false }
        do {
            var payload: [String: Any] = ["title": title.trimmingCharacters(in: .whitespacesAndNewlines), "body": bodyText]
            if kind == .pulls { payload["head"] = head.trimmingCharacters(in: .whitespacesAndNewlines); payload["base"] = base.trimmingCharacters(in: .whitespacesAndNewlines) }
            try await api.mutate(repo.path + "/" + kind.rawValue, method: "POST", body: payload)
            onComplete(); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct CommentComposer: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let repo: Repository
    let number: Int
    let onComplete: () -> Void
    @State private var bodyText = ""
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("\(repo.full_name) #\(number)") { TextEditor(text: $bodyText).frame(minHeight: 220).accessibilityLabel("Comment").accessibilityIdentifier("commentBody") }
                Section { Text("Markdown is supported.").font(.caption).foregroundStyle(.secondary) }
                if let error { Text(error).foregroundStyle(.red).font(.subheadline) }
            }.navigationTitle("Add a comment").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) }
                    ToolbarItem(placement: .confirmationAction) { Button(busy ? "Sending…" : "Send") { Task { await submit() } }.disabled(busy || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("sendComment") }
                }.interactiveDismissDisabled(busy)
        }
    }
    private func submit() async {
        guard let api = session.client else { return }
        busy = true; defer { busy = false }
        do { try await api.mutate(repo.path + "/issues/\(number)/comments", method: "POST", body: ["body": bodyText]); onComplete(); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}

struct ReviewComposer: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let repo: Repository
    let number: Int
    let commitID: String?
    let onComplete: () -> Void
    @State private var event = "COMMENT"
    @State private var bodyText = ""
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section { Picker("Review", selection: $event) { Text("Comment").tag("COMMENT"); Text("Approve").tag("APPROVED"); Text("Request changes").tag("REQUEST_CHANGES") }.pickerStyle(.inline) }
                Section("Feedback") { TextEditor(text: $bodyText).frame(minHeight: 180).accessibilityLabel("Review feedback") }
                if let error { Text(error).font(.subheadline).foregroundStyle(.red) }
            }.navigationTitle("Review changes").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) }
                    ToolbarItem(placement: .confirmationAction) { Button(busy ? "Submitting…" : "Submit") { Task { await submit() } }.disabled(busy || (event != "APPROVED" && bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)) }
                }.interactiveDismissDisabled(busy)
        }
    }
    private func submit() async {
        guard let api = session.client else { return }
        busy = true; defer { busy = false }
        do {
            var payload = ["event": event, "body": bodyText]
            if let commitID { payload["commit_id"] = commitID }
            try await api.mutate(repo.path + "/pulls/\(number)/reviews", method: "POST", body: payload)
            onComplete(); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct MergeView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let repo: Repository
    let pull: PullRequest
    let onComplete: () -> Void
    @State private var method = "merge"
    @State private var busy = false
    @State private var error: String?
    private var methods: [String] {
        var values: [String] = []
        if repo.allow_merge_commits != false { values.append("merge") }
        if repo.allow_squash_merge == true { values.append("squash") }
        if repo.allow_rebase == true { values.append("rebase") }
        return values
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(pull.title).font(.headline)
                    Text("Merge #\(pull.number) into \(pull.base?.ref ?? "the base branch") in \(repo.full_name).").font(.subheadline).foregroundStyle(.secondary)
                    Picker("Method", selection: $method) { ForEach(methods, id: \.self) { Text($0.capitalized).tag($0) } }
                }
                Section { Button(busy ? "Merging…" : "Confirm merge") { Task { await submit() } }.disabled(busy || methods.isEmpty).fontWeight(.semibold) }
                if let error { Text(error).foregroundStyle(.red).font(.subheadline) }
            }.navigationTitle("Merge pull request").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) } }
                .onAppear { method = methods.first ?? "merge" }.interactiveDismissDisabled(busy)
        }
    }
    private func submit() async {
        guard let api = session.client else { return }
        busy = true; defer { busy = false }
        do {
            var payload: [String: Any] = ["Do": method, "delete_branch_after_merge": false]
            if let sha = pull.head?.sha { payload["head_commit_id"] = sha }
            try await api.mutate(repo.path + "/pulls/\(pull.number)/merge", method: "POST", body: payload)
            onComplete(); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct PullFilesView: View {
    @EnvironmentObject private var session: AppSession
    let repo: Repository
    let number: Int
    @StateObject private var model = PageModel<ChangedFile>()
    var body: some View {
        List {
            Section { NavigationLink { PullDiffView(repo: repo, number: number) } label: { Label("Read unified diff", systemImage: "text.alignleft") } }
            Section {
                ForEach(model.items) { file in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(file.filename).font(.subheadline.monospaced()).textSelection(.enabled)
                        HStack { Text(file.status ?? "modified").foregroundStyle(.secondary); Spacer(); Text("+\(file.additions ?? 0)").foregroundStyle(Brand.green); Text("−\(file.deletions ?? 0)").foregroundStyle(.red) }.font(.caption)
                    }.padding(.vertical, 6)
                }
                PageFooter(model: model, emptyTitle: "No changed files", retry: reload, more: { await model.next(fetch) })
            }
        }.navigationTitle("Files changed").task { await reload() }.refreshable { await reload() }
    }
    private func fetch(_ page: Int) async throws -> [ChangedFile] { guard let api = session.client else { return [] }; return try await api.get(repo.path + "/pulls/\(number)/files", query: APIClient.page(page)) }
    private func reload() async { await model.reload(fetch) }
}

struct PullDiffView: View {
    @EnvironmentObject private var session: AppSession
    let repo: Repository
    let number: Int
    @State private var text: String?
    @State private var error: String?
    var body: some View {
        Group {
            if let text { SourceCodeView(text: text, diff: true) }
            else if let error { ErrorNotice(message: error) { Task { await load() } }.padding() }
            else { ProgressView("Loading diff…") }
        }.navigationTitle("Diff #\(number)").navigationBarTitleDisplayMode(.inline).task { await load() }
    }
    private func load() async {
        guard let api = session.client else { return }
        error = nil
        do {
            let data = try await api.data(repo.path + "/pulls/\(number).diff")
            guard data.count <= 1_000_000 else { throw GiteaError.server(413, "This diff is too large to preview. Open the pull request in your browser.") }
            guard let value = String(data: data, encoding: .utf8) else { throw GiteaError.invalidResponse }
            text = value
        } catch { self.error = error.localizedDescription }
    }
}
