import BackgroundTasks
import CryptoKit
import SwiftUI
import UserNotifications

/// Stores only thread IDs and timestamps, never notification titles or bodies.
struct NotificationLedger: Codable {
    var versions: [String: String] = [:]
    var initialized = false
    func changes(in threads: [NotificationThread]) -> [NotificationThread] {
        guard initialized else { return [] }
        return threads.filter { $0.unread && versions[String($0.id)] != ($0.updated_at ?? "initial") }
    }
    mutating func record(_ threads: [NotificationThread]) {
        for thread in threads { versions[String(thread.id)] = thread.updated_at ?? "initial" }
        initialized = true
        if versions.count > 1000 {
            versions = Dictionary(uniqueKeysWithValues: versions.sorted { $0.value > $1.value }.prefix(1000).map { ($0.key, $0.value) })
        }
    }
    static func accountKey(server: String, login: String) -> String {
        SHA256.hash(data: Data((server + "\n" + login).utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor final class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    static let taskIdentifier = "app.gitea.mobile.refresh-notifications"
    @Published private(set) var enabled = UserDefaults.standard.bool(forKey: "notificationChecksEnabled")
    @Published private(set) var checking = false
    @Published private(set) var lastChecked = UserDefaults.standard.object(forKey: "notificationLastCheck") as? Date
    @Published private(set) var permission: UNAuthorizationStatus = .notDetermined
    @Published var error: String?
    @Published var destination: NotificationThread?
    private weak var session: AppSession?
    private var generation = UUID()
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    func attach(_ session: AppSession) {
        self.session = session
        center.delegate = self
    }
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
            let work = Task { @MainActor in
                let service = NotificationService.shared
                await service.session?.restore()
                guard !Task.isCancelled else { task.setTaskCompleted(success: false); return }
                let success = await service.checkNow()
                service.schedule()
                task.setTaskCompleted(success: success)
            }
            task.expirationHandler = { work.cancel() }
        }
    }
    func refreshPermission() async { permission = await center.notificationSettings().authorizationStatus }
    func setEnabled(_ desired: Bool) async {
        guard let session, !session.isDemo, session.client != nil else {
            error = "Connect a Gitea account before enabling device alerts."
            return
        }
        error = nil
        let account = session.accountGeneration
        do {
            if desired {
                let allowed = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                await refreshPermission()
                guard session.accountGeneration == account else { return }
                guard allowed else { error = "Notifications are disabled in iOS Settings. Allow notifications there, then enable checks here."; return }
                // This change is explicitly described next to the user's opt-in control.
                try CredentialStore.allowBackgroundAccess(true)
                enabled = true
                defaults.set(true, forKey: "notificationChecksEnabled")
                _ = await checkNow()
                schedule()
            } else {
                try CredentialStore.allowBackgroundAccess(false)
                reset()
            }
        } catch { self.error = error.localizedDescription }
    }
    func reset() {
        generation = UUID()
        enabled = false
        destination = nil
        error = nil
        lastChecked = nil
        defaults.removeObject(forKey: "notificationChecksEnabled")
        defaults.removeObject(forKey: "notificationLastCheck")
        defaults.removeObject(forKey: "notificationLedger")
        defaults.removeObject(forKey: "notificationLedgerAccount")
        defaults.removeObject(forKey: "notificationPreviews")
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        Task { try? await center.setBadgeCount(0) }
    }
    func schedule() {
        guard enabled, session?.isDemo != true else { return }
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.taskIdentifier)
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do { try BGTaskScheduler.shared.submit(request) }
        catch { self.error = "Background refresh is unavailable. Checks still run when you open the app. Enable Background App Refresh in iOS Settings to allow background checks." }
    }
    @discardableResult func checkNow() async -> Bool {
        guard enabled, !checking, let session, !session.isDemo, let api = session.client, let login = session.user?.login else { return false }
        let operation = generation
        let account = session.accountGeneration
        let key = NotificationLedger.accountKey(server: api.baseURL.absoluteString, login: login)
        checking = true
        error = nil
        defer { checking = false }
        do {
            await refreshPermission()
            guard [.authorized, .provisional, .ephemeral].contains(permission) else {
                error = "Allow notifications in iOS Settings to receive alerts."; return false
            }
            var threads: [NotificationThread] = []
            // Bound each background task. The newest 300 unread threads are checked.
            for page in 1...10 {
                try Task.checkCancellation()
                let batch: [NotificationThread] = try await api.get("notifications", query: APIClient.page(page))
                threads += batch
                if batch.count < APIClient.pageSize { break }
            }
            try Task.checkCancellation()
            guard operation == generation, account == session.accountGeneration, enabled else { return false }
            var ledger = NotificationLedger()
            if defaults.string(forKey: "notificationLedgerAccount") == key,
               let data = defaults.data(forKey: "notificationLedger"), let existing = try? JSONDecoder().decode(NotificationLedger.self, from: data) { ledger = existing }
            let changes = ledger.changes(in: threads)
            if !changes.isEmpty {
                // Summarize bursts in one alert, keeping pending requests well below iOS limits.
                let content = UNMutableNotificationContent()
                let preview = defaults.bool(forKey: "notificationPreviews")
                content.title = changes.count == 1 ? "New Gitea activity" : "\(changes.count) Gitea updates"
                content.body = preview && changes.count == 1 ? changes[0].subject.title : "You have new activity on your Gitea server."
                content.sound = .default
                content.userInfo = ["account": key, "thread": changes[0].id]
                let id = "gitea-" + key + "-updates"
                try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
                guard operation == generation, account == session.accountGeneration, enabled else {
                    center.removePendingNotificationRequests(withIdentifiers: [id]); center.removeDeliveredNotifications(withIdentifiers: [id]); return false
                }
            }
            ledger.record(threads)
            defaults.set(try JSONEncoder().encode(ledger), forKey: "notificationLedger")
            defaults.set(key, forKey: "notificationLedgerAccount")
            lastChecked = Date()
            defaults.set(lastChecked, forKey: "notificationLastCheck")
            session.notifications = threads
            try await center.setBadgeCount(threads.filter(\.unread).count)
            if operation != generation { try? await center.setBadgeCount(0); return false }
            return true
        } catch is CancellationError { return false }
        catch {
            if operation == generation { self.error = error.localizedDescription }
            return false
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                           withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                           withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let key = info["account"] as? String
        let thread = info["thread"] as? Int
        Task { @MainActor in
            defer { completionHandler() }
            await self.session?.restore()
            guard let session = self.session, !session.isDemo, let api = session.client, let user = session.user,
                  key == NotificationLedger.accountKey(server: api.baseURL.absoluteString, login: user.login), let thread, thread > 0 else { return }
            let account = session.accountGeneration
            do {
                let notification: NotificationThread = try await api.get("notifications/threads/\(thread)")
                guard account == session.accountGeneration else { return }
                self.destination = notification
            } catch { self.error = error.localizedDescription }
        }
    }
}

final class GiteaAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NotificationService.shared.registerBackgroundTask()
        return true
    }
}
