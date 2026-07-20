import Foundation

/// Pure geometry for one segment of the "3 daily goals" single ring — shared by the in-app
/// `DailyGoalsBarsView` and the widget extension's `WidgetRingView` so a tweak to gap size or
/// segment count only ever needs to change in one place, and so the trim fractions and the
/// gradient's degree range (which must describe the exact same arc) can't drift out of sync with
/// each other the way two independently-computed copies could.
enum RingSegmentGeometry {
    static let segmentCount = 3
    /// Degrees of empty space between adjacent segments. Round line caps eat into this visually,
    /// so the actual gap reads narrower than this number.
    static let gapDegrees: Double = 14

    struct Segment {
        /// `Circle().trim(from:to:)` fractions (0...1) for this segment's full track — always the
        /// whole segment regardless of progress.
        let trimStart: Double
        let trimEnd: Double
        /// The same segment, in degrees, for an `AngularGradient`'s `startAngle`/`endAngle` — kept
        /// as a fixed full-segment sweep (not scaled by progress) so filling in more of the trim
        /// below reveals progressively more of one consistent gradient instead of a gradient that
        /// itself changes shape as it fills.
        let gradientStartDegrees: Double
        let gradientEndDegrees: Double
    }

    static func segment(at index: Int) -> Segment {
        let spanDegrees = 360.0 / Double(segmentCount)
        let startDeg = Double(index) * spanDegrees
        let endDeg = startDeg + (spanDegrees - gapDegrees)
        return Segment(
            trimStart: startDeg / 360,
            trimEnd: endDeg / 360,
            gradientStartDegrees: startDeg,
            gradientEndDegrees: endDeg
        )
    }
}
