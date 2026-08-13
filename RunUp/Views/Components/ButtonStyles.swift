import SwiftUI

/// Generic "press" tap feedback (subtle scale-down), applied to nearly every tappable element
/// in the prototype via the `.press` CSS class.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Full-width primary CTA — Bebas Neue label, rose fill, rose glow shadow. Class `.b.btn-rose`.
struct PrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    var fill: AnyShapeStyle? = nil

    /// Light mode gets a quiet rose2→rose gradient instead of a flat fill — one of the few
    /// "signature" accent moments left once the glow shadow below is gone, so it needs to carry a
    /// little more richness on its own. Dark mode keeps the flat fill it already had.
    private var resolvedFill: AnyShapeStyle {
        // `RUColor.accentGradient` = le `--ru-gradient` de la maquette ; ce couple rose2 → rose
        // était recopié à l'identique ici et dans `SelectableChip`. Direction verticale conservée
        // (voir le commentaire du token) — rendu strictement identique à avant.
        fill ?? (RUColor.isLight
            ? AnyShapeStyle(RUColor.accentGradient(from: .top, to: .bottom))
            : AnyShapeStyle(RUColor.rose))
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RUFont.bebas(16))
            .tracking(1)
            .foregroundColor(.white)
            // Padding first, `minHeight` second — the padding contributes to the natural size so
            // it only pads out to 44pt when needed, instead of stacking 24pt of padding on top of
            // an already-enforced 44pt frame (the order this had right after the tap-target fix,
            // which made every primary CTA ~68pt tall instead of the intended ~44-46pt).
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(resolvedFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            // The glow was a big part of what read as "gamified" rather than "premium digital" —
            // light mode drops it to nothing (the card shadow language handles elevation there
            // instead); dark mode's energetic glow is untouched.
            .shadow(color: RUColor.rose.opacity(RUColor.isLight || isDisabled ? 0 : 0.3), radius: 16, x: 0, y: 4)
            .opacity(isDisabled ? 0.35 : (configuration.isPressed ? 0.85 : 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension PrimaryButtonStyle {
    /// Violet→rose gradient variant used on the Paywall CTA.
    static var violetRose: PrimaryButtonStyle {
        PrimaryButtonStyle(fill: AnyShapeStyle(RUColor.violetRoseGradient))
    }
}

/// Bouton « fantôme » — fond de carte, contour hairline, libellé EN COULEUR D'ACCENT.
///
/// C'est le troisième style de bouton de la maquette, et le seul qui manquait ici. Il y apparaît
/// trois fois sous trois noms (`.cta-ghost`, `.badge-share-btn`, `.post-feed-btn`), avec les mêmes
/// valeurs à chaque fois : `background: var(--ru-card); border: 1px solid var(--ru-line); color:
/// var(--ru-rose)`, coins de 10–12px et un libellé en 10,5–11px/800.
///
/// Il porte une règle explicite de la maquette (« accent, pas aplat ») : en v28, « Partager ce
/// badge » et « Publier sur ton fil » sont passés du rose plein à cette carte neutre + texte rose,
/// pour s'aligner sur « Partager ta course » qui l'était déjà. Sans ce style, tout call site qui
/// veut une action secondaire *accentuée* n'avait le choix qu'entre `PrimaryButtonStyle` (aplat
/// rose plein largeur, précisément ce que la v28 retire) et `SecondaryButtonStyle` (libellé en
/// encre neutre, qui n'accentue rien).
///
/// Même géométrie que `SecondaryButtonStyle` volontairement : la maquette ne fait varier que le
/// fond (`card` au lieu de `card2`) et la couleur du libellé.
struct GhostButtonStyle: ButtonStyle {
    /// Par défaut l'accent courant. Paramétrable pour les quelques cas où la maquette accentue
    /// avec une couleur sémantique plutôt qu'avec la marque (violet pour le coach, ambre pour une
    /// alerte) — cf. `.callout .l` / `.alert-card`.
    var tint: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RUFont.sans(13, weight: .bold))
            .foregroundColor(tint ?? RUColor.rose)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Secondary full-width button — translucent card fill, used for "Déplacer à demain", "Plus tard" etc.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // 800 dans la maquette, pour TOUS ses libellés de boutons sans exception
            // (`.cta-ghost`, `.share-btn`, `.badge-share-btn`, `.post-feed-btn`, `.retry-btn`) —
            // `.semibold` (600) était le seul poids de libellé plus léger que la maquette.
            .font(RUFont.sans(13, weight: .bold))
            .foregroundColor(RUColor.textPrimary)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
