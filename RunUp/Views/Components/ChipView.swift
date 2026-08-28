import SwiftUI

/// Selectable pill chip used throughout onboarding deep-dive steps and quick filters (gender,
/// injuries, level, goal, race details...). One shared component, so a single visual pass here
/// covers every picker in the app at once instead of a dozen near-identical ones drifting apart.
struct SelectableChip: View {
    var label: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if selected {
                    // A small affordance beyond color alone — the flat rose fill used to be the
                    // only signal a chip was picked, easy to miss at a glance across a whole row.
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .transition(.scale.combined(with: .opacity))
                }
                Text(LocalizedStringKey(label))
                    .font(RUFont.sans(.label, weight: .semibold))
            }
            .foregroundColor(selected ? .white : RUColor.text2)
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .frame(minHeight: 44)
            // A flat solid fill read flat/dated — the same rose2→rose gradient the RUN button
            // already uses gives selection real depth without introducing a new accent.
            // `RUColor.accentGradient` = le `--ru-gradient` de la maquette, nommé plutôt que
            // recopié une troisième fois. Direction verticale conservée : rendu identique à avant.
            //
            // Conservé tel quel après vérification : la maquette a trois traitements « on » pour
            // ses sélecteurs et n'en désigne aucun comme LE bon — `.range-opt.on` est précisément
            // ce dégradé plein + texte blanc, `.style-chip.on` un aplat d'encre, `.rpe-opt.on` une
            // teinte pâle + contour accentué. Le nettoyage « moins de gros aplats roses » de la
            // v28 ne visait que les pastilles de statut (`.follow-chip`, RSVP), pas les
            // sélecteurs. Rien d'assez univoque pour changer.
            .background(
                selected
                    ? AnyShapeStyle(RUColor.accentGradient(from: .top, to: .bottom))
                    : AnyShapeStyle(RUColor.card),
                in: Capsule()
            )
            .overlay(Capsule().stroke(selected ? Color.clear : RUColor.line, lineWidth: RUSpacing.hairline))
            .shadow(color: RUColor.rose.opacity(selected && !RUColor.isLight ? 0.3 : 0), radius: 10, x: 0, y: 4)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Small static status badge — class `.chip` (e.g. "+1 palier", "Zone optimale", "▲ +2.1").
///
/// Équivalents maquette : `.streakpill` (`color: var(--ru-rose); background: color-mix(in srgb,
/// var(--ru-rose) 12%, var(--ru-bg)); padding: 4px 8px; border-radius: 999px`) et `.follow-chip`
/// (mêmes valeurs, `padding: 5px 10px`). La v28 en fait explicitement la norme des pastilles de
/// statut de toute la maquette (« pastille pâle, déjà la norme du reste du fichier — streakpill,
/// follow-chip par défaut »).
///
/// Note : la maquette n'a pas de classe `.stat-chip` ; ces deux-là sont ses vraies pastilles.
struct StatChip: View {
    var text: String
    var color: Color
    var background: Color? = nil

    var body: some View {
        Text(LocalizedStringKey(text))
            .font(RUFont.sans(.small, weight: .bold))
            .foregroundColor(color)
            // 8px/10px de padding horizontal dans la maquette, soit ~10–12,5pt à son échelle.
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            // Aplat opaque à 12% mélangé dans `bg`, pas un `color.opacity(0.14)` translucide :
            // voir `RUColor.tint`. Une pastille posée sur une carte se teintait du gris de la
            // carte au lieu de rester plus claire qu'elle — la maquette mélange sur `--ru-bg`
            // même pour les pastilles qui vivent dans une carte (`.follow-chip` dans
            // `.suggest-card`), ce qui leur donne cet effet de découpe qui manquait ici.
            .background(background ?? RUColor.tint(color, 0.12, over: RUColor.bg), in: Capsule())
    }
}

/// Value + label column — class `.metric` (duration/pace/zone triplets, etc.).
struct MetricColumn: View {
    var value: String
    var label: String
    var valueColor: Color = RUColor.textPrimary
    var valueSize: CGFloat = 20
    /// Les rangées de métriques de la maquette sont majoritairement CENTRÉES, pas alignées à
    /// gauche : `.stat-summary-row .ss`, `.metric-pair .mcard`, `.simplestat` et
    /// `.live-metrics-row .lm` portent tous `text-align: center` (elles vivent dans une carte
    /// unique découpée par des filets verticaux de 1px, `--ru-line`). L'alignement à gauche existe
    /// aussi (`.feed-stats`, `.week-tile`) et reste donc le défaut, pour ne changer aucun call
    /// site — mais sans ce paramètre, les rangées à filets ne pouvaient pas être construites avec
    /// ce composant partagé.
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(value).displayStyle(valueSize).foregroundColor(valueColor)
            Text(LocalizedStringKey(label))
                .font(RUFont.sans(.micro, weight: .bold))
                // 0,02–0,03em partout dans la maquette pour cette famille de micro-libellés
                // (`.mcard .l`, `.simplestat .l`, `.week-tile .l`, `.stat-summary-row .l`,
                // `.pr-chip .l`, `.feed-stats .fl`) : à 9pt cela vaut ~0,25pt. L'ancien 1pt
                // valait 0,11em, ~4× la maquette — la graisse et les capitales portent déjà la
                // distinction, l'interlettrage n'a pas à la doubler.
                .tracking(0.3)
                .textCase(.uppercase)
                // `--ru-ink3` dans la maquette, pour ces libellés comme pour les eyebrows —
                // `ink2` y est réservé à la prose secondaire. Voir `eyebrowStyle`.
                .foregroundColor(RUColor.text3)
        }
        // Reused across Home, Live, Stats, and History — a single fix here covers every duration/
        // pace/zone/metric pair in the app at once. Without this, VoiceOver read the value and its
        // label as two disconnected stops ("8:32" ... several stops later ... "ALLURE"); the
        // explicit label puts them in "name, value" order for clarity rather than relying on
        // `.combine`'s default top-to-bottom concatenation (value first, unit-less, then label).
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(LocalizedStringKey(label)) + Text(", ") + Text(value))
    }
}
