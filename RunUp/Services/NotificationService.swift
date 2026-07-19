import Foundation
import UIKit
import UserNotifications

/// Local (on-device) reminders — the daily session nudge — plus real APNs push (a club-mate's
/// kudos or activity landing while the app isn't open) once signed in. Both share the same
/// `UNUserNotificationCenter` authorization prompt and the same delegate, so from the user's side
/// it's one permission and one place notifications show up; only the *source* differs (this
/// device's clock vs. RunUp's backend).
final class NotificationService: NSObject {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()
    private static let reminderID = "runup.daily-session-reminder"
    private static let inactivityReminderID = "runup.inactivity-reminder"
    private static let deviceTokenDefaultsKey = "runup.apns-device-token-hex"
    private static let baseURL = URL(string: "https://runup-nu.vercel.app")!

    /// The device's real APNs token (hex-encoded), once the OS has handed one back — persisted so
    /// it survives relaunches and can be (re-)sent to the backend as soon as she's signed in, even
    /// if that happens well after the token itself was granted (push permission is asked during
    /// onboarding, an account is only ever created later, from Club).
    private(set) var deviceTokenHex: String? {
        didSet { UserDefaults.standard.set(deviceTokenHex, forKey: Self.deviceTokenDefaultsKey) }
    }

    private override init() {
        deviceTokenHex = UserDefaults.standard.string(forKey: Self.deviceTokenDefaultsKey)
        super.init()
        center.delegate = self
    }

    /// Call when the user turns "Notifications du coach" on in Profil (or once at the end of
    /// onboarding) — the local system prompt only ever shows once per install, so later calls are
    /// harmless no-ops. Also kicks off real APNs registration on success: local reminders and
    /// remote push share one authorization, no separate prompt for the latter.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted {
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        }
        return granted
    }

    /// Called by `AppDelegate` once the OS hands back a real APNs token. Stores it locally and, if
    /// she already has an account, registers it with the backend right away — otherwise
    /// `sendPendingDeviceTokenIfSignedIn()` picks it up the moment she signs in.
    func handleDeviceToken(_ data: Data) {
        deviceTokenHex = data.map { String(format: "%02x", $0) }.joined()
        Task { await sendPendingDeviceTokenIfSignedIn() }
    }

    /// Registers whatever device token is on hand with the backend — call right after a successful
    /// sign-in (a token obtained during onboarding, before any account existed, would otherwise
    /// never make it to the server) and from `handleDeviceToken` for the common case where she's
    /// already signed in when a (re-)issued token arrives.
    func sendPendingDeviceTokenIfSignedIn() async {
        guard let deviceTokenHex, let authToken = KeychainService.loadToken() else { return }
        var request = URLRequest(url: Self.baseURL.appending(path: "api/notifications/register"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["deviceToken": deviceTokenHex, "platform": "ios"])
        _ = try? await URLSession.shared.data(for: request)
    }

    /// Re-schedules (or clears) today's reminder to match the current plan — call whenever
    /// program/profile state could have changed (app foreground, onboarding finish, a session
    /// just got logged). Fires at 18:00 local time, only if the coach-notifications toggle is on,
    /// there's an active program, and today's session isn't already done — never nags about a
    /// rest day or a session that's already checked off.
    func rescheduleDailyReminder(for profile: UserProfile) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
        guard profile.coachNotificationsEnabled, profile.programPhase == .active, !profile.seanceDoneToday else { return }
        let session = profile.todaySession
        guard session.durationMinutes > 0 else { return }

        center.getNotificationSettings { [center] settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "Séance du jour"
            content.body = "\(session.title) t'attend — \(session.durationMinutes)′ à \(session.pace)/km."
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = 18
            dateComponents.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: Self.reminderID, content: content, trigger: trigger)
            center.add(request)
        }
    }

    /// Call when the user turns "Notifications du coach" off — otherwise a stale reminder could
    /// still fire after they've explicitly opted out.
    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
    }

    /// Re-arms a 3-day-out "on ne t'a pas vu" nudge every time the app comes to the foreground —
    /// cancelled and rescheduled from scratch each time (see `AppState.refreshProgramForCurrentDate`
    /// and `init`), so it only actually fires if she genuinely doesn't reopen the app for 3 real
    /// days. Same authorization/toggle as the daily session reminder, no separate opt-in — and
    /// unlike that one, fires regardless of `programPhase` (recovery/free-run included), since the
    /// point is bringing her back to the app at all, not to one specific planned session.
    func rescheduleInactivityReminder(for profile: UserProfile) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.inactivityReminderID])
        guard profile.coachNotificationsEnabled else { return }

        center.getNotificationSettings { [center] settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "Ça fait un moment…"
            content.body = "Ton programme t'attend toujours — une petite séance aujourd'hui ?"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3 * 24 * 60 * 60, repeats: false)
            let request = UNNotificationRequest(identifier: Self.inactivityReminderID, content: content, trigger: trigger)
            center.add(request)
        }
    }

    /// Call when the user turns "Notifications du coach" off — same reasoning as `cancelDailyReminder`.
    func cancelInactivityReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.inactivityReminderID])
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Without this, a notification that arrives while the app is already open (the common case
    /// for a push about a club-mate's kudos landing mid-session) is delivered silently — iOS only
    /// auto-banners ones received while the app is backgrounded.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
