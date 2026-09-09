# Feature-gap progress

## Completed in this increment

- Public-client OAuth sign-in using the system authentication browser, PKCE S256, strict callback/state validation, and scoped access.
- Keychain persistence of OAuth refresh tokens; serialized automatic refresh and a single retry following an authentication rejection.
- Protection against refresh responses replacing a different account or resurrecting a signed-out session.
- Opt-in local device alerts backed by foreground checks and iOS Background App Refresh, with backlog suppression, deduplication, privacy controls, account-bound routing, and disable/sign-out cleanup.
- Removed the redundant profile avatar from the Home navigation header.

OAuth registration instructions and the delivery limitations of background checks are in the [README](../README.md).

## True APNs push: next server-dependent increment

The current app has no push relay and does not register a remote device token. Background checks are a useful first step, but iOS may postpone them indefinitely. Do not treat them as reliable instant delivery.

An implementable next step is an optional, self-hosted notification relay:

1. Run a relay on infrastructure that can reach the Gitea instance, including private instances. Poll each opted-in user’s notification feed so alerts respect Gitea’s user-specific visibility and subscriptions. Repository webhooks alone do not supply an equivalent per-user inbox.
2. Pair the app explicitly with that relay. Keep API credentials in the user-controlled deployment, encrypt stored secrets, authenticate device registrations, rate-limit registration and polling, and make unpairing delete registrations and credentials. Never upload existing app tokens automatically.
3. Configure an Apple APNs signing key, key ID, team ID, bundle topic and sandbox/production environment in the relay. Keep the APNs private key exclusively on the server. Provision the iOS app with the Push Notifications capability.
4. Deliver generic, minimal payloads containing opaque account/thread references. Resolve thread details against the authenticated Gitea API after opening the app. Handle device-token rotation, APNs invalid-token responses, expiration, duplicate delivery, permission denial and sign-out.
5. Test end-to-end delivery on a provisioned physical iPhone, including locked-device delivery, background/terminated app states, account switching, private repositories and revocation.

This deployment and its credentials are not configured yet. The default Xcode scheme remains usable without an APNs entitlement or a relay.

## Remaining client work

- Multiple saved accounts and explicit switching, with account-scoped credentials, navigation, caches and notification registrations.
- Offline browsing using a bounded encrypted cache; mutation queuing requires conflict handling and should be a separate change.
- Inline pull-request review comments with validated old/new line positions and draft-review lifecycle.
- File editing with branch selection, optimistic concurrency using blob SHA, commit messages, and conflict recovery.
- Actions views and administration, followed by repository settings with permission-aware actions.

## References

- [Gitea OAuth provider and PKCE](https://docs.gitea.com/development/oauth2-provider/)
- [Apple background refresh](https://developer.apple.com/documentation/backgroundtasks/refreshing-and-maintaining-your-app-using-background-tasks)
- [Apple local notification scheduling](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
