import Foundation

struct GiteaUser: Codable, Identifiable, Hashable {
    var id: Int
    var login: String
    var full_name: String?
    var avatar_url: String?
    var description: String?
    var location: String?
    var website: String?
    var html_url: String?
    var followers_count: Int?
    var following_count: Int?
    var displayName: String { full_name.flatMap { $0.isEmpty ? nil : $0 } ?? login }
}

struct Repository: Codable, Identifiable, Hashable {
    var id: Int
    var name: String
    var full_name: String
    var owner: GiteaUser
    var description: String?
    var html_url: String?
    var language: String?
    var `private`: Bool?
    var fork: Bool?
    var archived: Bool?
    var empty: Bool?
    var default_branch: String?
    var stars_count: Int?
    var forks_count: Int?
    var open_issues_count: Int?
    var open_pr_counter: Int?
    var updated_at: String?
    var permissions: Permissions?
    var allow_merge_commits: Bool?
    var allow_squash_merge: Bool?
    var allow_rebase: Bool?
    var path: String { "repos/\(APIClient.segment(owner.login))/\(APIClient.segment(name))" }
    struct Permissions: Codable, Hashable { var admin: Bool?; var push: Bool?; var pull: Bool? }
}

struct Issue: Codable, Identifiable, Hashable {
    var id: Int
    var number: Int
    var title: String
    var body: String?
    var state: String
    var user: GiteaUser?
    var labels: [IssueLabel]?
    var comments: Int?
    var created_at: String?
    var updated_at: String?
    var html_url: String?
    var repository: IssueRepository?
    var pull_request: PullReference?
    var isPull: Bool { pull_request != nil }
    struct PullReference: Codable, Hashable { var merged: Bool?; var draft: Bool? }
    struct IssueRepository: Codable, Hashable { var id: Int?; var name: String?; var owner: String?; var full_name: String? }
}

struct IssueLabel: Codable, Identifiable, Hashable {
    var id: Int
    var name: String
    var color: String
}

struct IssueComment: Codable, Identifiable {
    var id: Int
    var body: String
    var user: GiteaUser?
    var created_at: String?
}

struct PullRequest: Codable, Identifiable {
    var id: Int
    var number: Int
    var title: String
    var body: String?
    var state: String
    var user: GiteaUser?
    var html_url: String?
    var created_at: String?
    var labels: [IssueLabel]?
    var merged: Bool?
    var mergeable: Bool?
    var draft: Bool?
    var additions: Int?
    var deletions: Int?
    var changed_files: Int?
    var head: BranchInfo?
    var base: BranchInfo?
    struct BranchInfo: Codable { var label: String?; var ref: String?; var sha: String? }
    var issue: Issue {
        Issue(id: id, number: number, title: title, body: body, state: state, user: user,
              labels: labels, created_at: created_at, html_url: html_url,
              pull_request: .init(merged: merged, draft: draft))
    }
}

struct PullReview: Codable, Identifiable {
    var id: Int
    var user: GiteaUser?
    var body: String?
    var state: String?
    var submitted_at: String?
}

struct ChangedFile: Codable, Identifiable {
    var filename: String
    var additions: Int?
    var deletions: Int?
    var status: String?
    var id: String { filename }
}

struct RepositoryContent: Codable, Identifiable, Hashable {
    var name: String
    var path: String
    var type: String
    var size: Int?
    var content: String?
    var encoding: String?
    var html_url: String?
    var id: String { path }
    var decodedText: String? {
        guard let content, encoding == "base64", let data = Data(base64Encoded: content, options: .ignoreUnknownCharacters) else { return nil }
        guard !data.contains(0) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct Branch: Codable, Identifiable { var name: String; var id: String { name } }
struct Commit: Codable, Identifiable {
    var sha: String
    var html_url: String?
    var commit: Details
    var author: GiteaUser?
    var id: String { sha }
    struct Details: Codable {
        var message: String
        var author: Signature?
        struct Signature: Codable { var name: String?; var date: String? }
    }
}
struct Release: Codable, Identifiable {
    var id: Int
    var name: String?
    var tag_name: String
    var body: String?
    var html_url: String?
    var published_at: String?
    var prerelease: Bool?
    var assets: [Asset]?
    struct Asset: Codable, Identifiable { var id: Int; var name: String; var browser_download_url: String?; var size: Int? }
}
struct Organization: Codable, Identifiable, Hashable {
    var id: Int
    var name: String
    var full_name: String?
    var description: String?
    var avatar_url: String?
}
struct NotificationThread: Codable, Identifiable {
    var id: Int
    var unread: Bool
    var pinned: Bool?
    var updated_at: String?
    var repository: Repository
    var subject: Subject
    struct Subject: Codable {
        var title: String
        var type: String
        var state: String?
        var url: String?
        var html_url: String?
        var number: Int? { url.flatMap(URL.init(string:))?.lastPathComponent.flatMapInt }
    }
}
private extension String { var flatMapInt: Int? { Int(self) } }
struct SearchResults<T: Decodable>: Decodable { var data: [T]?; var ok: Bool? }

enum GiteaError: LocalizedError {
    case invalidURL, insecureURL, invalidResponse, server(Int, String), keychain(Int32), unsupportedDemo
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Enter a valid server URL, such as https://git.example.com. A subpath is supported."
        case .insecureURL: return "Use HTTPS to protect your access token. Local servers can use HTTP on localhost or a private network."
        case .invalidResponse: return "The server returned an unexpected response. Check that this is a Gitea server URL."
        case .server(let code, let message):
            if code == 401 { return "Your Gitea session is invalid or expired. Sign out and connect again." }
            if code == 403 { return "Your account or access token doesn’t have permission for this action. Check its scopes in Gitea." }
            if code == 404 { return "This item is unavailable. It may have been removed, or your account may not have access." }
            return "\(message) (HTTP \(code))"
        case .keychain: return "Your credentials couldn’t be saved securely. Please try again."
        case .unsupportedDemo: return "This action isn’t available in the demo account. Connect your Gitea server to continue."
        }
    }
}

enum DateText {
    static func date(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: string)
    }
    static func relative(_ string: String?) -> String {
        guard let date = date(string) else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
