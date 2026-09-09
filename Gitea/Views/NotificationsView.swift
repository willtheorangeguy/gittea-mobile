import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var model = PageModel<NotificationThread>()
    @State private var filter = "unread"
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        List {
            Section { Picker("Notifications", selection: $filter) { Text("Unread").tag("unread"); Text("All").tag("all") }.pickerStyle(.segmented) }
            Section {
                ForEach(model.items) { notification in
                    NavigationLink { NotificationDestination(notification: notification) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: notification.subject.type == "Pull" ? "arrow.triangle.pull" : "smallcircle.filled.circle")
                                .foregroundStyle(notification.subject.state == "open" ? Brand.green : .purple).padding(.top, 2)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(notification.repository.full_name).font(.caption).foregroundStyle(.secondary)
                                Text(notification.subject.title).font(.subheadline.weight(notification.unread ? .semibold : .regular)).foregroundStyle(.primary)
                                Text(DateText.relative(notification.updated_at)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if notification.unread { Circle().fill(.blue).frame(width: 7, height: 7).padding(.top, 7).accessibilityLabel("Unread") }
                        }.padding(.vertical, 6)
                    }.swipeActions { if notification.unread { Button { Task { await markRead(notification) } } label: { Label("Read", systemImage: "checkmark") }.tint(Brand.green) } }
                }
                PageFooter(model: model, emptyTitle: "You’re all caught up", emptySymbol: "checkmark.circle", emptyDescription: "A little quiet. New mentions and updates will land here.", retry: reload, more: { await model.next(fetch) })
            }
        }.navigationTitle("Notifications")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { Task { await markAllRead() } } label: { Image(systemName: "checkmark.circle") }.accessibilityLabel("Mark all as read").disabled(busy || !model.items.contains(where: \.unread)) } }
            .task(id: filter) { await reload() }.refreshable { await reload() }
            .alert("Couldn’t update notifications", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK", role: .cancel) { } } message: { Text(error ?? "") }
    }
    private func fetch(_ page: Int) async throws -> [NotificationThread] {
        guard let api = session.client else { return [] }
        return try await api.get("notifications", query: APIClient.page(page) + [.init(name: "all", value: filter == "all" ? "true" : "false")])
    }
    private func reload() async { await model.reload(fetch); if model.error == nil { session.notifications = model.items } }
    private func markRead(_ item: NotificationThread) async {
        guard let api = session.client else { return }
        do { try await api.mutate("notifications/threads/\(item.id)", method: "PATCH", query: [.init(name: "to-status", value: "read")]); await reload() }
        catch { self.error = error.localizedDescription }
    }
    private func markAllRead() async {
        guard let api = session.client else { return }
        busy = true; defer { busy = false }
        do {
            // Bound the operation to the time the user tapped, preserving later notifications.
            try await api.mutate("notifications", method: "PUT", query: [.init(name: "to-status", value: "read"), .init(name: "last_read_at", value: ISO8601DateFormatter().string(from: Date()))])
            await reload()
        } catch { self.error = error.localizedDescription }
    }
}

struct NotificationDestination: View {
    let notification: NotificationThread
    var body: some View {
        if ["Issue", "Pull"].contains(notification.subject.type), let number = notification.subject.number {
            IssueDetailView(repo: notification.repository, number: number, isPull: notification.subject.type == "Pull")
        } else {
            List {
                Text(notification.subject.title).font(.headline)
                WebLink(title: "Open notification", url: notification.subject.html_url)
                NavigationLink("View repository") { RepositoryDetailView(repo: notification.repository) }
            }.navigationTitle("Notification")
        }
    }
}
