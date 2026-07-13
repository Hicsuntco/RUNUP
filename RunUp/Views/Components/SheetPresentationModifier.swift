import SwiftUI

/// Consistent styling for the app's bottom sheets (session detail, program settings,
/// notifications, debrief): dark backdrop, drag handle, dark sheet background.
/// Uses native `.sheet` + `.presentationDetents` rather than a hand-rolled overlay —
/// this gives free drag-to-dismiss, backdrop-tap-to-dismiss and safe-area handling.
struct RunUpSheetModifier: ViewModifier {
    var detents: Set<PresentationDetent> = [.medium, .large]

    func body(content: Content) -> some View {
        content
            .presentationDetents(detents)
            .presentationDragIndicator(.visible)
            .presentationBackground(RUColor.bg)
            .presentationCornerRadius(26)
    }
}

extension View {
    func runUpSheetStyle(detents: Set<PresentationDetent> = [.medium, .large]) -> some View {
        modifier(RunUpSheetModifier(detents: detents))
    }
}
