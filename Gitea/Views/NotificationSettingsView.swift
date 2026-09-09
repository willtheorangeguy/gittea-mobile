import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject private var session: AppSession
    @ObservedObject private var alerts = NotificationService.shared
    @AppStorage("notificationPreviews") private var previews = false
    @State private var changing = false
    var body: some View {
        Form {
            Section {
                Toggle("Check for new activity", isOn: Binding(get: { alerts.enabled }, set: { value in
                    changing = true
                    Task { await alerts.setEnabled(value); changing = false }
                })).disabled(changing || session.isDemo).accessibilityIdentifier("notificationChecks")
                if session.isDemo { Text("Connect your Gitea server to enable device alerts.").font(.caption).foregroundStyle(.secondary) }
            } footer: {
                Text("Checks run when you open the app and when iOS grants background time. Delivery may be delayed and requires your server to be reachable. This is background refresh, not instant push.")
            }
            if !session.isDemo {
                Section {
                    Toggle("Show notification previews", isOn: $previews).disabled(!alerts.enabled)
                    Button { Task { _ = await alerts.checkNow() } } label: {
                        HStack { Text(alerts.checking ? "Checking…" : "Check now"); Spacer(); if alerts.checking { ProgressView() } }
                    }.disabled(!alerts.enabled || alerts.checking)
                    if let date = alerts.lastChecked { LabeledContent("Last checked") { Text(date, style: .relative).foregroundStyle(.secondary) }.accessibilityIdentifier("lastNotificationCheck") }
                    Link("Open iOS Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                } footer: { Text("Previews can show private issue or pull-request titles on your lock screen. Existing unread items form the initial baseline and won’t trigger a burst of alerts.") }
            }
            Section {
                Label("Credentials stay on this device", systemImage: "lock.shield")
                Text("Enabling background checks allows the app to read your Keychain credentials while locked, after the first unlock following a restart. Turning checks off restores access only while unlocked. No token is sent to a notification relay.").font(.caption).foregroundStyle(.secondary)
            }
            if let error = alerts.error { Section { Text(error).font(.subheadline).foregroundStyle(.red) } }
        }.navigationTitle("Device alerts").navigationBarTitleDisplayMode(.inline)
            .task { alerts.attach(session); await alerts.refreshPermission() }
    }
}
