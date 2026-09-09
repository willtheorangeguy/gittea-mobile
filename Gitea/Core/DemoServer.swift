import Foundation

/// An isolated, mutable sample account. Demo actions never leave the device.
actor DemoServer {
    static let user = GiteaUser(id: 1, login: "alex", full_name: "Alex Morgan", description: "Building little things for the open web. ☕", location: "Vancouver, Canada", followers_count: 28, following_count: 42)
    static let teammate = GiteaUser(id: 2, login: "sarah", full_name: "Sarah Chen")
    static let org = GiteaUser(id: 3, login: "studio", full_name: "Studio")
    static let readme = """
    # A little space for big ideas.

    **Orbit** is a thoughtfully crafted workspace for your team's next project. Built in the open, made to feel at home.

    ## Getting started

    Clone the repository, install dependencies, and start your development server.

    ```sh
    git clone https://git.example.com/studio/orbit.git
    cd orbit
    npm install
    npm run dev
    ```

    ## What’s inside

    - A fast, accessible interface
    - Real-time collaboration
    - A small, composable design system
    - Your data, on your infrastructure

    ## Contributing

    Good ideas come from everywhere. Open an issue to share yours, or pick up something labeled **good first issue**.

    ## License

    MIT. Make something wonderful.
    """
    static var repositories: [Repository] {
        [Repository(id: 1, name: "orbit", full_name: "studio/orbit", owner: org, description: "A calmer place for your team to build something great.", language: "TypeScript", private: false, default_branch: "main", stars_count: 128, forks_count: 16, open_issues_count: 12, open_pr_counter: 3, permissions: .init(admin: true, push: true, pull: true), allow_merge_commits: true, allow_squash_merge: true, allow_rebase: true),
         Repository(id: 2, name: "gitea-mobile", full_name: "alex/gitea-mobile", owner: user, description: "Your code. Your community. Wherever you are.", language: "Swift", private: false, default_branch: "main", stars_count: 64, forks_count: 8, open_issues_count: 6, open_pr_counter: 2, permissions: .init(admin: true, push: true, pull: true)),
         Repository(id: 3, name: "homelab", full_name: "alex/homelab", owner: user, description: "Notes and configurations for a tiny, self-hosted corner of the internet.", language: "Shell", private: true, default_branch: "main", stars_count: 12, forks_count: 2, open_issues_count: 3, open_pr_counter: 1),
         Repository(id: 4, name: "seed", full_name: "studio/seed", owner: org, description: "Small components. Endless possibilities. Our open-source design system.", language: "CSS", private: false, default_branch: "main", stars_count: 256, forks_count: 32, open_issues_count: 8, open_pr_counter: 4)]
    }
    private var issues: [Issue] = [
        Issue(id: 101, number: 42, title: "Make the workspace feel right at home on mobile", body: "Let’s give the mobile layout a little more breathing room.\n\n## Checklist\n\n- Increase touch targets to 44pt\n- Keep navigation within reach\n- Support Dynamic Type\n\nWould love your thoughts on the new direction!", state: "open", user: teammate, labels: [.init(id: 1, name: "enhancement", color: "3b82f6"), .init(id: 2, name: "design", color: "a855f7")], comments: 2, created_at: "2026-09-07T14:30:00Z", repository: .init(id: 1, name: "orbit", owner: "studio", full_name: "studio/orbit")),
        Issue(id: 102, number: 38, title: "Add keyboard shortcuts to the command menu", body: "A quick way to move between projects without leaving the keyboard.\n\n**Proposed shortcut:** ⌘K", state: "open", user: user, labels: [.init(id: 3, name: "good first issue", color: "16a34a")], comments: 1, created_at: "2026-09-06T10:00:00Z", repository: .init(id: 1, name: "orbit", owner: "studio", full_name: "studio/orbit")),
        Issue(id: 103, number: 35, title: "Remember the selected color scheme", body: "The selected appearance should persist across launches.", state: "closed", user: teammate, labels: [.init(id: 4, name: "bug", color: "e5534b")], comments: 0, created_at: "2026-09-04T10:00:00Z", repository: .init(id: 1, name: "orbit", owner: "studio", full_name: "studio/orbit"))]
    private var pulls: [PullRequest] = [
        PullRequest(id: 201, number: 47, title: "A fresh look for the project overview", body: "A little polish goes a long way. This brings the new cards, spacing, and typography into the project overview.\n\n## Changes\n\n- Simplified project cards\n- Better contrast in dark mode\n- More comfortable spacing on mobile\n\nReady for a fresh pair of eyes.", state: "open", user: teammate, created_at: "2026-09-08T08:00:00Z", labels: [.init(id: 2, name: "design", color: "a855f7")], merged: false, mergeable: true, draft: false, additions: 86, deletions: 24, changed_files: 2, head: .init(label: "studio:feature/project-overview", ref: "feature/project-overview", sha: "a1b2c3d4"), base: .init(label: "studio:main", ref: "main", sha: "e5f6a7b8")),
        PullRequest(id: 202, number: 44, title: "Speed up the initial workspace load", body: "Load independent resources concurrently and cache the last workspace.", state: "open", user: user, created_at: "2026-09-07T12:00:00Z", merged: false, mergeable: true, additions: 34, deletions: 12, changed_files: 1, head: .init(ref: "perf/workspace", sha: "b2c3d4e5"), base: .init(ref: "main"))]
    private var comments: [Int: [IssueComment]] = [42: [
        .init(id: 1, body: "The extra spacing looks great. Let’s make sure this works with larger text sizes too.", user: DemoServer.user, created_at: "2026-09-07T16:00:00Z"),
        .init(id: 2, body: "Absolutely! I’ll add that to the checklist.", user: DemoServer.teammate, created_at: "2026-09-07T16:30:00Z")]]
    private var reviews: [Int: [PullReview]] = [:]
    private var stars: Set<String> = ["studio/seed"]
    private var readNotifications: Set<Int> = []

    func respond(path: String, method: String, query: [URLQueryItem], body: [String: Any]?) throws -> Data {
        let p = path.split(separator: "/").map { String($0).removingPercentEncoding ?? String($0) }
        let q = Dictionary(query.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { _, last in last })
        func encode<T: Encodable>(_ value: T) throws -> Data { try JSONEncoder().encode(value) }
        func page<T>(_ items: [T]) -> [T] {
            let start = max(0, ((Int(q["page"] ?? "1") ?? 1) - 1) * APIClient.pageSize)
            return Array(items.dropFirst(start).prefix(APIClient.pageSize))
        }
        if path == "user" { return try encode(Self.user) }
        if path == "user/orgs" { return try encode([Organization(id: 3, name: "studio", full_name: "Studio", description: "Good tools, built together.")]) }
        if path == "user/repos" { return try encode(page(Self.repositories)) }
        if path == "user/starred" { return try encode(page(Self.repositories.filter { stars.contains($0.full_name) })) }
        if p.starts(with: ["user", "starred"]), p.count == 4 {
            let key = p[2] + "/" + p[3]
            if method == "PUT" { stars.insert(key) }
            else if method == "DELETE" { stars.remove(key) }
            else if !stars.contains(key) { throw GiteaError.server(404, "Not starred") }
            return Data()
        }
        if p.first == "orgs", p.last == "repos" { return try encode(page(Self.repositories.filter { $0.owner.login == p[1] })) }
        if path == "repos/search" {
            let repos = Self.repositories.filter { q["q", default: ""].isEmpty || ($0.full_name + ($0.description ?? "")).localizedCaseInsensitiveContains(q["q"]!) }
            return try JSONSerialization.data(withJSONObject: ["ok": true, "data": JSONSerialization.jsonObject(with: encode(page(repos)))])
        }
        if path == "repos/issues/search" {
            var list = q["type"] == "pulls" ? pulls.map { pull -> Issue in
                var issue = pull.issue
                issue.repository = .init(id: 1, name: "orbit", owner: "studio", full_name: "studio/orbit")
                return issue
            } : issues
            if q["state"] != "all" { list = list.filter { $0.state == q["state", default: "open"] } }
            if let search = q["q"], !search.isEmpty { list = list.filter { $0.title.localizedCaseInsensitiveContains(search) } }
            if q["created"] == "true" { list = list.filter { $0.user?.id == Self.user.id } }
            return try encode(page(list))
        }
        if path == "notifications" {
            if method == "PUT" { readNotifications = [1, 2, 3]; return Data() }
            let titles = ["A fresh look for the project overview", "Make the workspace feel right at home on mobile", "Add keyboard shortcuts to the command menu"]
            let numbers = [47, 42, 38]
            let list = titles.enumerated().map { index, title in
                NotificationThread(id: index + 1, unread: !readNotifications.contains(index + 1), updated_at: "2026-09-08T10:00:00Z", repository: Self.repositories[0], subject: .init(title: title, type: index == 0 ? "Pull" : "Issue", state: "open", url: "https://demo.gitea.local/api/v1/repos/studio/orbit/issues/\(numbers[index])"))
            }
            return try encode(page(q["all"] == "true" ? list : list.filter(\.unread)))
        }
        if p.starts(with: ["notifications", "threads"]), let id = Int(p.last ?? ""), method == "PATCH" {
            readNotifications.insert(id); return Data()
        }
        if p.first == "repos", p.count >= 3 {
            let repo = Self.repositories.first { $0.full_name == p[1] + "/" + p[2] } ?? Self.repositories[0]
            if p.count == 3 { return try encode(repo) }
            let resource = p[3]
            let number = p.count > 4 ? Int(p[4]) ?? 0 : 0
            if resource == "branches" { return try encode([Branch(name: "main"), Branch(name: "develop"), Branch(name: "feature/project-overview")]) }
            if resource == "contents" {
                if p.count == 4 {
                    return try encode([RepositoryContent(name: "src", path: "src", type: "dir"), .init(name: "public", path: "public", type: "dir"), .init(name: "README.md", path: "README.md", type: "file", size: 1024), .init(name: "package.json", path: "package.json", type: "file", size: 340), .init(name: "LICENSE", path: "LICENSE", type: "file", size: 1068)])
                }
                let filePath = p.dropFirst(4).joined(separator: "/")
                if filePath == "src" || filePath == "public" { return try encode([RepositoryContent(name: "index.ts", path: filePath + "/index.ts", type: "file", size: 180)]) }
                let text = filePath == "README.md" ? Self.readme : filePath == "package.json" ? "{\n  \"name\": \"orbit\",\n  \"version\": \"1.4.0\",\n  \"private\": true,\n  \"scripts\": {\n    \"dev\": \"vite\",\n    \"build\": \"vite build\"\n  }\n}" : filePath == "LICENSE" ? "MIT License\n\nCopyright (c) 2026 Studio\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software to use, copy, modify, and distribute the Software." : "// A small beginning.\nexport function greet(name: string): string {\n  return `Hello, ${name}. Welcome to Orbit.`;\n}\n\nconsole.log(greet('world'));"
                return try encode(RepositoryContent(name: p.last!, path: filePath, type: "file", size: text.utf8.count, content: Data(text.utf8).base64EncodedString(), encoding: "base64"))
            }
            if resource == "commits" {
                return try encode(page([Commit(sha: "a1b2c3d4e5f6", commit: .init(message: "Polish the project overview", author: .init(name: "Sarah Chen", date: "2026-09-08T08:00:00Z")), author: Self.teammate), Commit(sha: "b2c3d4e5f6a7", commit: .init(message: "Add accessible keyboard navigation", author: .init(name: "Alex Morgan", date: "2026-09-07T10:00:00Z")), author: Self.user)]))
            }
            if resource == "releases" { return try encode(page([Release(id: 1, name: "A little more room to create", tag_name: "v1.4.0", body: "## What’s new\n\n- A refreshed project overview\n- Faster workspace loading\n- Improved keyboard navigation\n\nThanks to everyone who helped make this release happen.", published_at: "2026-09-06T12:00:00Z", prerelease: false, assets: [])])) }
            if resource == "pulls", p.count == 4 {
                if method == "POST" {
                    let pull = PullRequest(id: Int.random(in: 1000...999999), number: (pulls.map(\.number).max() ?? 50) + 1, title: body?["title"] as? String ?? "", body: body?["body"] as? String, state: "open", user: Self.user, created_at: ISO8601DateFormatter().string(from: Date()), merged: false, mergeable: true, head: .init(ref: body?["head"] as? String, sha: "demo-head"), base: .init(ref: body?["base"] as? String))
                    pulls.insert(pull, at: 0); return try encode(pull)
                }
                return try encode(page(pulls.filter { q["state"] == "all" || $0.state == q["state", default: "open"] }))
            }
            if resource == "pulls", p.last?.hasSuffix(".diff") == true {
                return Data("diff --git a/src/components/ProjectCard.tsx b/src/components/ProjectCard.tsx\n--- a/src/components/ProjectCard.tsx\n+++ b/src/components/ProjectCard.tsx\n@@ -1,4 +1,7 @@\n export function ProjectCard({ project }) {\n-  return <div>{project.name}</div>;\n+  return (\n+    <article className=\"project-card\">\n+      <h2>{project.name}</h2>\n+    </article>\n+  );\n }".utf8)
            }
            if resource == "pulls", p.count == 5, let pull = pulls.first(where: { $0.number == number }) { return try encode(pull) }
            if resource == "pulls", p.last == "files" { return try encode(page([ChangedFile(filename: "src/components/ProjectCard.tsx", additions: 62, deletions: 18, status: "modified"), ChangedFile(filename: "src/styles/theme.css", additions: 24, deletions: 6, status: "modified")])) }
            if resource == "pulls", p.last == "reviews" {
                if method == "POST" {
                    let review = PullReview(id: Int.random(in: 1000...999999), user: Self.user, body: body?["body"] as? String, state: body?["event"] as? String, submitted_at: ISO8601DateFormatter().string(from: Date()))
                    reviews[number, default: []].append(review)
                    return try encode(review)
                }
                return try encode(page(reviews[number, default: []]))
            }
            if resource == "pulls", p.last == "merge", let index = pulls.firstIndex(where: { $0.number == number }) {
                pulls[index].merged = true; pulls[index].state = "closed"; return Data()
            }
            if resource == "issues", p.last == "comments" {
                if method == "POST" {
                    let comment = IssueComment(id: Int.random(in: 1000...999999), body: body?["body"] as? String ?? "", user: Self.user, created_at: ISO8601DateFormatter().string(from: Date()))
                    comments[number, default: []].append(comment)
                    return try encode(comment)
                }
                return try encode(page(comments[number, default: []]))
            }
            if resource == "issues", p.count == 4 {
                if method == "POST" {
                    let issue = Issue(id: Int.random(in: 1000...999999), number: (issues.map(\.number).max() ?? 50) + 1, title: body?["title"] as? String ?? "", body: body?["body"] as? String, state: "open", user: Self.user, created_at: ISO8601DateFormatter().string(from: Date()), repository: .init(id: repo.id, name: repo.name, owner: repo.owner.login, full_name: repo.full_name))
                    issues.insert(issue, at: 0); return try encode(issue)
                }
                return try encode(page(issues.filter { q["state"] == "all" || $0.state == q["state", default: "open"] }))
            }
            if resource == "issues", p.count == 5 {
                if let index = issues.firstIndex(where: { $0.number == number }) {
                    if method == "PATCH", let state = body?["state"] as? String { issues[index].state = state }
                    return try encode(issues[index])
                }
                if let index = pulls.firstIndex(where: { $0.number == number }) {
                    if method == "PATCH", let state = body?["state"] as? String { pulls[index].state = state }
                    return try encode(pulls[index].issue)
                }
            }
        }
        throw GiteaError.unsupportedDemo
    }
}
