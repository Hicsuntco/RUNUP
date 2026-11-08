import Foundation

/// Identifies what a report is about — a club, a user, or one activity — so the reason picker
/// can post to `api/moderation/report` with the right target. Internal (not private): `FriendsView`
/// reuses this same type for its own report confirmationDialog.
struct ReportTarget: Identifiable {
    let id = UUID()
    var targetType: String
    var targetId: String
    var displayName: String
}
