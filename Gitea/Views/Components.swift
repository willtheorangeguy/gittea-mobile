import SwiftUI

enum Brand {
    static let green = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.30, green: 0.80, blue: 0.53, alpha: 1)
            : UIColor(red: 0.12, green: 0.57, blue: 0.36, alpha: 1)
    })
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static func language(_ name: String?) -> Color {
        switch name?.lowercased() {
        case "swift": return .orange
        case "typescript": return .blue
        case "javascript": return .yellow
        case "go": return .cyan
        case "python": return .indigo
        case "rust": return .brown
        case "css": return .purple
        default: return green
        }
    }
}

struct Avatar: View {
    let name: String
    var url: String? = nil
    var size: CGFloat = 36
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32).fill(Brand.green.opacity(0.13))
            Text(String(name.prefix(2)).uppercased()).font(.system(size: size * 0.34, weight: .bold, design: .rounded)).foregroundStyle(Brand.green)
            if let url = URL(string: url ?? ""), url.scheme == "https" {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
            }
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.32))
        .accessibilityHidden(true)
    }
}

struct SymbolTile: View {
    let symbol: String
    var color: Color = Brand.green
    var body: some View {
        Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(color)
            .frame(width: 34, height: 34).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

struct RepositoryRow: View {
    let repo: Repository
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Avatar(name: repo.owner.login, url: repo.owner.avatar_url, size: 30)
                Text(repo.owner.login).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if repo.private == true { Image(systemName: "lock").font(.caption).foregroundStyle(.secondary) }
                if repo.archived == true { Text("Archived").font(.caption).foregroundStyle(.secondary) }
            }
            Text(repo.name).font(.headline).foregroundStyle(.primary)
            if let description = repo.description, !description.isEmpty {
                Text(description).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            HStack(spacing: 18) {
                if let language = repo.language, !language.isEmpty {
                    HStack(spacing: 5) { Circle().fill(Brand.language(language)).frame(width: 8, height: 8); Text(language) }
                }
                Label((repo.stars_count ?? 0).formatted(), systemImage: "star")
                if repo.fork == true { Label("Fork", systemImage: "arrow.triangle.branch") }
            }.font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 7)
    }
}

struct IssueRow: View {
    let issue: Issue
    var showRepository = false
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: issue.isPull ? "arrow.triangle.pull" : issue.state == "open" ? "smallcircle.filled.circle" : "checkmark.circle")
                .font(.system(size: 19)).foregroundStyle(issue.state == "open" ? Brand.green : .purple).padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                if showRepository, let repo = issue.repository {
                    Text(repo.full_name ?? "\(repo.owner ?? "")/\(repo.name ?? "")").font(.caption).foregroundStyle(.secondary)
                }
                Text(issue.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                Text("#\(issue.number) · \(issue.user?.login ?? "unknown") · \(DateText.relative(issue.created_at))")
                    .font(.caption).foregroundStyle(.secondary)
                if let labels = issue.labels, !labels.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        HStack { ForEach(labels.prefix(3)) { LabelPill(label: $0) } }
                        LabelPill(label: labels[0])
                    }
                }
            }
        }.padding(.vertical, 7)
    }
}
struct LabelPill: View {
    let label: IssueLabel
    var body: some View {
        Text(label.name).font(.caption2.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(Color(hex: label.color)).background(Color(hex: label.color).opacity(0.12), in: Capsule())
    }
}
extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x238636
        self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
}

struct ErrorNotice: View {
    let message: String
    var retry: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Couldn’t load this", systemImage: "wifi.exclamationmark").font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
            if let retry { Button("Try again", action: retry).font(.subheadline.weight(.semibold)) }
        }.padding(.vertical, 8).accessibilityElement(children: .contain)
    }
}

@MainActor final class PageModel<Item: Identifiable>: ObservableObject {
    @Published var items: [Item] = []
    @Published var loading = false
    @Published var error: String?
    @Published var hasMore = false
    private var page = 0
    private var generation = UUID()
    func reload(_ fetch: @escaping (Int) async throws -> [Item]) async {
        generation = UUID()
        page = 0
        hasMore = false
        await load(fetch, reset: true)
    }
    func next(_ fetch: @escaping (Int) async throws -> [Item]) async {
        guard !loading, hasMore else { return }
        await load(fetch, reset: false)
    }
    private func load(_ fetch: (Int) async throws -> [Item], reset: Bool) async {
        let request = generation
        loading = true
        error = nil
        defer { if generation == request { loading = false } }
        do {
            let results = try await fetch(reset ? 1 : page + 1)
            try Task.checkCancellation()
            guard generation == request else { return }
            let existing = reset ? [] : items
            let ids = Set(existing.map { AnyHashable($0.id) })
            items = existing + results.filter { !ids.contains(AnyHashable($0.id)) }
            page = reset ? 1 : page + 1
            hasMore = results.count == APIClient.pageSize
        } catch is CancellationError { }
        catch let failure as URLError where failure.code == .cancelled { }
        catch { if generation == request { self.error = error.localizedDescription; if reset { items = [] } } }
    }
}

struct PageFooter<Item: Identifiable>: View {
    @ObservedObject var model: PageModel<Item>
    var emptyTitle: String = "Nothing here yet"
    var emptySymbol: String = "tray"
    var emptyDescription: String = "New items will appear here."
    let retry: () async -> Void
    let more: () async -> Void
    var body: some View {
        if model.loading { HStack { Spacer(); ProgressView().padding(); Spacer() } }
        else if let error = model.error { ErrorNotice(message: error) { Task { await retry() } } }
        else if model.items.isEmpty {
            ContentUnavailableView(emptyTitle, systemImage: emptySymbol, description: Text(emptyDescription))
        } else if model.hasMore { Button("Load more") { Task { await more() } }.frame(maxWidth: .infinity) }
    }
}

struct MarkdownView: View {
    let text: String
    private var blocks: [String] { text.components(separatedBy: "\n\n") }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                if block.hasPrefix("```") {
                    Text(block.split(separator: "\n", omittingEmptySubsequences: false).dropFirst().filter { !$0.hasPrefix("```") }.joined(separator: "\n"))
                        .font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12).background(Brand.background, in: RoundedRectangle(cornerRadius: 10))
                } else if block.hasPrefix("# ") {
                    Text(String(block.dropFirst(2))).font(.title2.bold())
                } else if block.hasPrefix("## ") {
                    Text(String(block.dropFirst(3))).font(.headline)
                } else if block.hasPrefix("### ") {
                    Text(String(block.dropFirst(4))).font(.subheadline.bold())
                } else {
                    Text((try? AttributedString(markdown: block, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(block))
                        .font(.subheadline).lineSpacing(4)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
    }
}

struct WebLink: View {
    let title: String
    let url: String?
    var body: some View {
        if let url = URL(string: url ?? ""), ["https", "http"].contains(url.scheme ?? "") {
            Link(destination: url) { Label(title, systemImage: "arrow.up.right.square") }
        }
    }
}
