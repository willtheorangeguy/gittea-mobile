import SwiftUI

struct ConnectView: View {
    @EnvironmentObject private var session: AppSession
    @AppStorage("lastServer") private var lastServer = ""
    @State private var server = ""
    @State private var token = ""
    @State private var clientID = ""
    @State private var method = "token"
    @StateObject private var oauthBrowser = OAuthBrowser()
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focus: Field?
    private enum Field { case server, token, clientID }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 20) {
                        Image(systemName: "cup.and.saucer.fill").font(.system(size: 38, weight: .medium))
                            .foregroundStyle(.white).frame(width: 80, height: 80)
                            .background(Brand.green.gradient, in: RoundedRectangle(cornerRadius: 24))
                        Text("Your code.\nYour corner of the world.")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold)).tracking(-1)
                        Text("A little closer to your projects, wherever you are. Connect your Gitea server to get started.")
                            .font(.body).foregroundStyle(.secondary).lineSpacing(4)
                    }.padding(.top, 26)
                    VStack(alignment: .leading, spacing: 18) {
                        Picker("Sign-in method", selection: $method) {
                            Text("Access token").tag("token")
                            Text("Browser sign-in").tag("oauth")
                        }.pickerStyle(.segmented).disabled(busy).accessibilityIdentifier("signInMethod")
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Server URL").font(.subheadline.weight(.semibold))
                            TextField("https://git.example.com", text: $server)
                                .keyboardType(.URL).textContentType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                                .focused($focus, equals: .server).submitLabel(.next).onSubmit { focus = method == "token" ? .token : .clientID }
                                .disabled(busy)
                                .accessibilityIdentifier("serverURL")
                                .padding(14).background(Brand.card, in: RoundedRectangle(cornerRadius: 12))
                        }
                        if method == "token" {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Personal access token").font(.subheadline.weight(.semibold))
                                SecureField("Paste your access token", text: $token)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .focused($focus, equals: .token).submitLabel(.go).onSubmit { connect() }
                                    .disabled(busy)
                                    .accessibilityIdentifier("accessToken")
                                    .padding(14).background(Brand.card, in: RoundedRectangle(cornerRadius: 12))
                                Text("Create a token in your Gitea Settings → Applications. Allow repository, issue, notification, user, and organization access for the features you use.")
                                    .font(.caption).foregroundStyle(.secondary).lineSpacing(3)
                                if let url = try? APIClient.normalizeURL(server) {
                                    Link("Open token settings ↗", destination: url.appendingPathComponent("user/settings/applications")).font(.caption.weight(.semibold))
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("OAuth client ID").font(.subheadline.weight(.semibold))
                                TextField("Client ID from your Gitea server", text: $clientID)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .focused($focus, equals: .clientID).submitLabel(.go).onSubmit { connect() }.disabled(busy)
                                    .padding(14).background(Brand.card, in: RoundedRectangle(cornerRadius: 12))
                                    .accessibilityIdentifier("oauthClientID")
                                Text("Register Gitea Mobile under Settings → Applications on your server. Turn off “Confidential client” and use this redirect URI:")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(OAuthAttempt.callback).font(.caption.monospaced()).textSelection(.enabled)
                                Button { UIPasteboard.general.string = OAuthAttempt.callback } label: { Label("Copy redirect URI", systemImage: "doc.on.doc") }.font(.caption)
                                if let url = try? APIClient.normalizeURL(server) {
                                    Link("Open application settings ↗", destination: url.appendingPathComponent("user/settings/applications")).font(.caption.weight(.semibold))
                                }
                                Text("Requires Gitea 1.23+ for scoped authorization. Sign in and approve access in the browser; no client secret is needed.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        if let message = error ?? session.error {
                            Text(message).font(.subheadline).foregroundStyle(.red).accessibilityIdentifier("connectionError")
                        }
                        Button(action: connect) {
                            HStack { Spacer(); if busy { ProgressView().tint(.white) }; Text(busy ? "Connecting…" : method == "oauth" ? "Continue in browser" : "Connect to Gitea").fontWeight(.semibold); Spacer() }.padding(.vertical, 8)
                        }.buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(busy || server.trimmingCharacters(in: .whitespaces).isEmpty || (method == "token" ? token : clientID).trimmingCharacters(in: .whitespaces).isEmpty)
                            .accessibilityIdentifier("connectButton")
                        Label("Your token stays in your device’s Keychain.", systemImage: "lock.shield")
                            .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                    VStack(spacing: 12) {
                        Button("Explore a demo account") { focus = nil; session.enterDemo() }
                            .font(.subheadline.weight(.semibold)).accessibilityIdentifier("demoButton").disabled(busy)
                        Text("Self-hosted. Independent. Yours.").font(.caption).foregroundStyle(.tertiary)
                    }.frame(maxWidth: .infinity).padding(.bottom, 24)
                }.padding(.horizontal, 24).frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
            }.background(Brand.background).navigationTitle("Gitea").navigationBarTitleDisplayMode(.inline)
                .onAppear { if server.isEmpty { server = lastServer } }
                .scrollDismissesKeyboard(.interactively)
                .onDisappear { oauthBrowser.cancel() }
        }
    }
    private func connect() {
        guard !busy, !server.isEmpty, !(method == "token" ? token : clientID).isEmpty else { return }
        focus = nil
        busy = true
        error = nil
        Task {
            defer { busy = false }
            do {
                if method == "oauth" {
                    let credentials = try await oauthBrowser.signIn(server: APIClient.normalizeURL(server), clientID: clientID)
                    try await session.connect(credentials: credentials)
                } else { try await session.connect(server: server, token: token) }
                lastServer = server; token = ""
            }
            catch OAuthError.cancelled { }
            catch { self.error = error.localizedDescription }
        }
    }
}
