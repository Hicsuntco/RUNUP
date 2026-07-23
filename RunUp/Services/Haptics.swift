import UIKit

/// Thin wrapper over UIKit's feedback generators. Before this, the app had zero haptic feedback
/// anywhere — `PressableStyle` gives every tap a visual press-down, but nothing physical backed
/// the moments that actually matter (finishing a run, a streak milestone, a kudos tap), which is
/// exactly the kind of gap that makes an app feel like a prototype next to Strava/Nike Run Club.
enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
