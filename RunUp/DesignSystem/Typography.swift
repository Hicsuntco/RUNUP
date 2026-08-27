import SwiftUI
import Observation
import UIKit

/// Font tokens — see README § Typography.
///
/// Une seule famille de texte, `DisplayFont.family` (Archivo), déclinée par taille et par graisse :
/// - Display/numerals (Medium, class `.b`): big numbers, headlines,
///   buttons — voir `display(_:)` et son facteur de taille.
/// - Body (300–700 + italic): body copy, labels.
/// - Monospace ("DM Mono", class `.m`): timestamps, XP counters, precise numeric readouts.
/// - Eyebrow (class `.eye`): 9px, 3px tracking, uppercase, weight 700, used above section titles.
///
/// # Dynamic Type
/// Every token below routes its design point size through `scaled(_:)` and then hands the result
/// to a NON-scaling font initializer (`.custom(_:fixedSize:)` / `.system(size:)`), so this file is
/// the single place that decides how the app answers the iOS text-size setting. That indirection
/// is deliberate, and it fixes two different problems at once:
///
/// 1. La police de titrage avait, en mode clair, une branche `.system(size:)` qui ne suit PAS
///    Dynamic Type — en mode clair, chaque grand chiffre, titre et libellé de bouton de l'app
///    restait figé à sa taille codée en dur, quoi que l'utilisatrice ait choisi dans
///    Réglages → Affichage → Taille du texte. Cette branche a disparu avec Bebas (voir
///    `display(_:)`), mais l'indirection qui l'avait corrigée reste ce qui garantit qu'aucun
///    token ne puisse la réintroduire.
/// 2. The `.custom(_:size:)` initializer the other tokens used *does* scale (Apple: "scales with
///    the body text style"), but with no ceiling whatsoever: at the largest accessibility size
///    `.body` grows 17pt → 53pt, i.e. ≈3.1×. Applied to the week strip, the 3-up stat rows, the
///    prediction tiles or the tab bar labels — all fixed-width, side-by-side layouts — that
///    doesn't degrade gracefully, it collapses into unreadable truncation.
///
/// Les deux branches avaient fini par ne plus s'accorder : le même écran suivait ou non le
/// réglage selon que le mode clair était actif. Un seul chemin, plafonné, les rend cohérentes —
/// et il n'y a plus qu'une seule police de titrage à suivre, sur les deux fonds.
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

    /// La police de titrage : titres, grands chiffres, libellés en capitales, boutons.
    ///
    /// C'était Bebas Neue — des capitales d'affiche condensées, énergiques, registre salle de
    /// sport. Elle avait deux défauts. Elle ne tenait pas sur fond clair, au point que le mode
    /// clair la remplaçait par une system sans lourde : l'app avait donc DEUX identités
    /// typographiques selon le thème. Et elle est une police d'affiche, un genre qui date vite.
    ///
    /// C'est désormais Archivo Medium — la même famille que le texte courant, une graisse plus
    /// haut. Elle tient sur les deux fonds, d'où la disparition de la bifurcation.
    ///
    /// Le nom de la police et le facteur de taille vivent dans `DisplayFont` (RunUp/Shared) :
    /// le widget et la montre les utilisent aussi, et une police nommée à trois endroits finit
    /// toujours par n'être changée qu'à deux.
    ///
    static func display(_ size: CGFloat) -> Font {
        .custom(DisplayFont.postScriptName, fixedSize: scaled(DisplayFont.pointSize(for: size)))
    }

    /// Le texte courant et les métriques, relevés de 6 %.
    ///
    /// Séparé du facteur de titrage parce que les deux problèmes sont distincts : celui du
    /// titrage venait du changement de police, celui-ci est un jugement sur l'app telle qu'elle
    /// est — les libellés de 10 à 13 pt de la maquette sont serrés pour un écran lu en courant,
    /// souvent au soleil, souvent en bougeant.
    ///
    /// 6 % et pas davantage : les rangées de trois métriques côte à côte sont à largeur fixe, et
    /// au-delà elles tronquent au lieu de s'adapter. Comme le facteur de titrage, c'est un nombre,
    /// à un seul endroit, qu'on rouvre après avoir regardé un écran.
    /// 1,30, et ce n'est plus une compensation de police : c'est un choix de générosité.
    ///
    /// Deux choses se cumulent dans ce nombre. La compensation d'Archivo d'abord — sa hauteur
    /// d'x est 4,5 % sous celle de Poppins, ce qui valait 1,05. Puis le relèvement demandé, à
    /// partir d'une mesure des captures de référence : leur texte courant tourne autour de 16 pt
    /// quand les libellés d'ici étaient dessinés à 12. Le rapport est de 1,33 ; 1,30 le rejoint
    /// presque, et fait passer un libellé de 12 pt à 15,6 pt à l'écran.
    ///
    /// Le garde-fou reste le même — les rangées de métriques côte à côte tronquent au lieu de
    /// s'adapter — mais il n'est plus le facteur limitant : les neuf libellés d'une seule ligne
    /// qui n'avaient pas de `minimumScaleFactor` en ont un, donc ils rétrécissent au lieu de se
    /// couper. C'était la condition pour pouvoir monter aussi haut sans casser une rangée.
    ///
    /// Archivo aide aussi : 9 % plus étroite que Poppins, donc une ligne relevée de 30 % occupe
    /// 19 % de plus qu'avant, pas 30.
    private static let bodySizeFactor: CGFloat = 1.30

    static func mono(_ size: CGFloat, weight: DMWeight = .regular) -> Font {
        let pointSize = scaled(size * bodySizeFactor)
        switch weight {
        case .medium: return .custom("DMMono-Medium", fixedSize: pointSize)
        default: return .custom("DMMono-Regular", fixedSize: pointSize)
        }
    }

    /// La famille du texte courant, nommée UNE fois.
    ///
    /// C'est elle qui dessine l'écrasante majorité de ce qu'on lit : 348 appels à `sans` contre
    /// 82 au titrage. Autrement dit, changer la police de titrage ne change presque rien à
    /// l'impression que donne un écran — c'est ici qu'il faut agir, et c'est ici qu'on agira la
    /// prochaine fois, en modifiant cette seule chaîne.
    private static let bodyFamily = DisplayFont.family

    static func sans(_ size: CGFloat, weight: DMWeight = .regular) -> Font {
        let pointSize = scaled(size * bodySizeFactor)
        switch weight {
        case .light: return .custom("\(bodyFamily)-Light", fixedSize: pointSize)
        case .regular: return .custom("\(bodyFamily)-Regular", fixedSize: pointSize)
        case .medium: return .custom("\(bodyFamily)-Medium", fixedSize: pointSize)
        case .semibold: return .custom("\(bodyFamily)-SemiBold", fixedSize: pointSize)
        case .bold: return .custom("\(bodyFamily)-Bold", fixedSize: pointSize)
        }
    }

    static func sansItalic(_ size: CGFloat) -> Font {
        .custom("\(bodyFamily)-Italic", fixedSize: scaled(size * bodySizeFactor))
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
    /// Class `.b` in the prototype — la police de titrage, interlettrage serré (négatif).
    /// `.tracking`/`.textCase` are `View`-only modifiers (not declared on `Text` itself), so this
    /// returns `some View` rather than `Text` — safe everywhere it's used since none of these
    /// call sites concatenate the result with `+` (that requires `Text` on both sides).
    func displayStyle(_ size: CGFloat) -> some View {
        // Interlettrage NÉGATIF, proportionnel à la taille (−3 %), là où il était fixé à +0,5.
        //
        // Un titrage gras espacé positivement se lit comme du texte agrandi ; c'est le resserrage
        // qui le fait lire comme un titre. La proportionnalité compte autant que le signe : à
        // 11 pt, −0,33 se remarque à peine, à 46 pt, −1,4 change la ligne entière. Une valeur
        // fixe ne peut pas servir les deux.
        self.font(RUFont.display(size)).tracking(-size * 0.03)
    }

    /// Class `.eye` — eyebrow label above section/card titles.
    ///
    /// Recalé sur le `.ru-eyebrow` de la maquette : `font-size: 8.5px; font-weight: 700;
    /// letter-spacing: 0.18em; color: var(--ru-ink3)`.
    ///
    /// - Taille 9 → 10 : le gabarit téléphone de la maquette (268px pour ~393pt réels) donne un
    ///   facteur ~1,25, calibré sur deux repères non ambigus — ses micro-libellés de métriques font
    ///   7,5px là où l'app utilise `sans(9)`, et sa barre de progression d'onboarding fait 2,5px là
    ///   où l'app utilise 3. 8,5 × 1,25 ≈ 10,6. L'app posait l'eyebrow et les micro-libellés à la
    ///   MÊME taille (9) alors que la maquette hiérarchise les deux.
    /// - Interlettrage 3 → 1,8 : 0,18em à 10pt vaut 1,8pt. L'ancien 3pt à 9pt valait 0,33em, soit
    ///   presque le double de la maquette — c'est l'écart le plus net de toute la typographie
    ///   partagée, et le plus visible (un eyebrow trop étiré se lit comme un titre de rubrique de
    ///   presse, pas comme une étiquette discrète).
    ///   Les deux changements se compensent en largeur : ~8,4pt par caractère avant, ~7,8pt après.
    /// - Couleur par défaut `text2` → `text3` : la maquette réserve `--ru-ink2` à la prose
    ///   secondaire (`.callout p`, `.insight-line`, `.alert-card .s8`) et emploie `--ru-ink3` pour
    ///   TOUTES ses micro-étiquettes — eyebrows, libellés de métriques, horodatages. Les deux
    ///   tokens se correspondent d'ailleurs exactement (`ink3` sombre = 32% blanc = `text3`).
    ///   Sans effet sur les ~66 des 83 `EyebrowLabel` qui passent déjà une couleur explicite.
    func eyebrowStyle(color: Color = RUColor.text3) -> some View {
        self.font(RUFont.sans(10, weight: .bold)).tracking(1.8).textCase(.uppercase).foregroundColor(color)
    }
}

struct EyebrowLabel: View {
    var text: String
    /// Voir `eyebrowStyle(color:)` : `text3`, pas `text2` — la maquette réserve `ink2` à la prose
    /// secondaire et met toutes ses micro-étiquettes en `ink3`.
    var color: Color = RUColor.text3

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
