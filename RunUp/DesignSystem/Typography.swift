import SwiftUI
import Observation
import UIKit

/// Font tokens — see README § Typography.
/// - Display/numerals ("Bebas Neue", class `.b`): big numbers, headlines, buttons.
/// - Body ("DM Sans", 300–700 + italic): body copy, labels.
/// - Monospace ("DM Mono", class `.m`): timestamps, XP counters, precise numeric readouts.
/// - Eyebrow (class `.eye`): 9px, 3px tracking, uppercase, weight 700, used above section titles.
///
/// # Dynamic Type
/// Every token below routes its design point size through `scaled(_:)` and then hands the result
/// to a NON-scaling font initializer (`.custom(_:fixedSize:)` / `.system(size:)`), so this file is
/// the single place that decides how the app answers the iOS text-size setting. That indirection
/// is deliberate, and it fixes two different problems at once:
///
/// 1. The light-mode branch of `bebas(_:)` used `.system(size:)`, which does NOT scale with
///    Dynamic Type at all — in light mode, every big number, headline and button label in the app
///    (hundreds of `displayStyle()` call sites) was frozen at its hardcoded point size no matter
///    what the user had chosen in Réglages → Affichage → Taille du texte.
/// 2. The `.custom(_:size:)` initializer the other tokens used *does* scale (Apple: "scales with
///    the body text style"), but with no ceiling whatsoever: at the largest accessibility size
///    `.body` grows 17pt → 53pt, i.e. ≈3.1×. Applied to the week strip, the 3-up stat rows, the
///    prediction tiles or the tab bar labels — all fixed-width, side-by-side layouts — that
///    doesn't degrade gracefully, it collapses into unreadable truncation.
///
/// So the two branches also stopped agreeing with each other: the same screen scaled or didn't
/// depending purely on whether light mode was on. One shared, capped path makes them consistent.
///
/// Reactivity works exactly like `RUColor`'s theme tokens do (see `ThemeStore`): the sizes are
/// computed, not stored, and they read an `@Observable` singleton — `TextSizeStore` — so every
/// existing call site re-scales live when the setting changes, with zero call-site changes.
enum RUFont {
    /// Ceiling on how far a design size is allowed to grow, as a multiple of itself.
    ///
    /// 1.6× is the compromise between the two failure modes above: it covers the whole non-
    /// accessibility range of the iOS slider (xSmall…xxxLarge tops out at ≈1.35× for `.body`)
    /// with room to spare, so anyone who simply prefers larger text gets exactly what they asked
    /// for, while the five accessibility sizes are clamped instead of tripling and shattering the
    /// dense multi-column cards this app is built out of. It is knowingly NOT full AX support —
    /// that needs per-screen work (HStacks of metrics becoming VStacks past a threshold, which is
    /// a layout change per screen, not a font change), and this helper can't do it from here. A
    /// hard cap that keeps every screen usable is the honest intermediate step; raising this
    /// number is safe only screen by screen, once those layouts reflow.
    private static let maxScale: CGFloat = 1.6

    /// Turns a design point size into the size actually rendered, honouring the user's text-size
    /// setting up to `maxScale`.
    ///
    /// `.body` as the reference style for every token, rather than trying to map each call site's
    /// size onto the "right" text style: the sizes passed in here (8 → 44) were all drawn against
    /// each other in one mockup, and scaling them on different curves would pull the design apart
    /// at exactly the sizes it's meant to hold together. `.body`'s multiplier is 1.0 at the default
    /// (Large) category, so this is a no-op for anyone who never touched the setting — nothing
    /// about the default rendering of the app changes.
    ///
    /// Scaled `compatibleWith:` an explicit trait collection built from `TextSizeStore`, rather
    /// than letting `UIFontMetrics` fall back to the ambient `UITraitCollection.current`: that
    /// ambient value is only meaningfully set inside a UIKit view-update pass, and reading it
    /// would also make this function invisible to the Observation framework — the fonts would go
    /// stale until something else happened to re-render the screen. Going through the store gives
    /// a deterministic input AND registers the dependency, so a change to the setting invalidates
    /// every view that drew text, immediately.
    private static func scaled(_ size: CGFloat) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: TextSizeStore.shared.category)
        let scaledSize = UIFontMetrics(forTextStyle: .body).scaledValue(for: size, compatibleWith: traits)
        return min(scaledSize, size * maxScale)
    }

    /// Bebas Neue's condensed poster caps read energetic/gamified — right for the app's dark
    /// mode, but it's the single biggest reason light mode didn't read as the sober, premium,
    /// "digital coach" register she wants competing with Runna. Every `displayStyle()`/`.bebas()`
    /// call site (hundreds of them) switches automatically in light mode to a heavy system sans
    /// instead — no other file needs to change. Dark mode is untouched on purpose: two deliberate
    /// moods, not one compromise.
    static func bebas(_ size: CGFloat) -> Font {
        let pointSize = scaled(size)
        return RUColor.isLight
            ? .system(size: pointSize, weight: .heavy, design: .default)
            : .custom("BebasNeue-Regular", fixedSize: pointSize)
    }

    static func mono(_ size: CGFloat, weight: DMWeight = .regular) -> Font {
        let pointSize = scaled(size)
        switch weight {
        case .medium: return .custom("DMMono-Medium", fixedSize: pointSize)
        default: return .custom("DMMono-Regular", fixedSize: pointSize)
        }
    }

    static func sans(_ size: CGFloat, weight: DMWeight = .regular) -> Font {
        let pointSize = scaled(size)
        switch weight {
        case .light: return .custom("DMSans-Light", fixedSize: pointSize)
        case .regular: return .custom("DMSans-Regular", fixedSize: pointSize)
        case .medium: return .custom("DMSans-Medium", fixedSize: pointSize)
        case .semibold: return .custom("DMSans-SemiBold", fixedSize: pointSize)
        case .bold: return .custom("DMSans-Bold", fixedSize: pointSize)
        }
    }

    static func sansItalic(_ size: CGFloat) -> Font {
        .custom("DMSans-Italic", fixedSize: scaled(size))
    }

    enum DMWeight {
        case light, regular, medium, semibold, bold
    }
}

/// Live holder for the user's iOS text-size setting, read by `RUFont`'s scaled sizes from anywhere
/// in the app. Exactly the same shape and rationale as `ThemeStore` (see `AccentTheme.swift`): the
/// Observation framework tracks access to this object's properties during any view's `body`,
/// however that reference was obtained, so `RUFont.sans(13)` and friends stay reactive without a
/// single call site having to take an `@Environment(\.dynamicTypeSize)` of its own.
///
/// Seeded from `UIApplication.shared` and kept current by the system notification rather than by
/// polling — the setting can change while the app is in the foreground (Réglages via the app
/// switcher, or the text-size control in the Centre de contrôle), not only across a relaunch.
@Observable
final class TextSizeStore {
    static let shared = TextSizeStore()

    private(set) var category: UIContentSizeCategory

    private init() {
        category = UIApplication.shared.preferredContentSizeCategory
        // Delivered on `.main` so the mutation below — observed by SwiftUI views — always happens
        // on the main actor, and `[weak self]` purely out of habit: this singleton outlives the
        // observer either way, so there is no retain cycle to break and no removal to schedule.
        NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Re-read the app-level value rather than unwrapping the notification's userInfo: the
            // notification is posted after `UIApplication` has already adopted the new category,
            // so the two always agree, and this needs no optional-cast fallback path that could
            // silently leave the store stale.
            self?.category = UIApplication.shared.preferredContentSizeCategory
        }
    }
}

extension Text {
    /// Class `.b` in the prototype — Bebas Neue display type, tight tracking.
    /// `.tracking`/`.textCase` are `View`-only modifiers (not declared on `Text` itself), so this
    /// returns `some View` rather than `Text` — safe everywhere it's used since none of these
    /// call sites concatenate the result with `+` (that requires `Text` on both sides).
    func displayStyle(_ size: CGFloat) -> some View {
        self.font(RUFont.bebas(size)).tracking(0.5)
    }

    /// Class `.eye` — eyebrow label above section/card titles.
    func eyebrowStyle(color: Color = RUColor.text2) -> some View {
        self.font(RUFont.sans(9, weight: .bold)).tracking(3).textCase(.uppercase).foregroundColor(color)
    }
}

struct EyebrowLabel: View {
    var text: String
    var color: Color = RUColor.text2

    var body: some View {
        // `Text(text)` with a plain `String` never resolves through Localizable.xcstrings — only
        // `Text(_ key: LocalizedStringKey)` does, and that overload only kicks in for a string
        // literal passed directly at a `Text`/`Text`-taking-component call site. Since every call
        // site here passes a literal into this `String`-typed `text` property first, the literal
        // was being absorbed as a `String` before ever reaching a real `Text` init — wrapping in
        // `LocalizedStringKey(text)` performs the same catalog lookup a literal argument would,
        // for every caller, without needing to touch any of the ~75 call sites individually. A
        // caller passing a genuinely dynamic, already-formatted string (not a catalog key) just
        // falls through to the same verbatim rendering it had before — never worse, often fixed.
        Text(LocalizedStringKey(text)).eyebrowStyle(color: color)
    }
}
