import Foundation
import UserNotifications

/// Local (on-device) reminders — deliberately separate from the in-app bell (`AppNotification`,
/// see `AppState.notify`). No APNs/backend involved here, so this needs no server infrastructure
/// or Apple Developer push key: `UNUserNotificationCenter` can schedule and fire a real system
/// notification purely from the device's own clock, even while the app isn't running.
///
/// Scope is intentionally narrow — a single daily reminder for today's planned session — rather
/// than a general-purpose scheduler, since that's the one thing genuinely worth interrupting
/// someone for without a live backend behind it.
final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()
    private static let reminderID = "runup.daily-session-reminder"

    private init() {}

    /// Call when the user turns "Notifications du coach" on in Profil — the local system prompt
    /// only ever shows once per install, so later calls are harmless no-ops.
    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
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
}
