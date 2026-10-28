import SwiftUI

/// Screen header: eyebrow + large display-face title, optional trailing accessory. Mirrors `Header` in ui.jsx.
struct HeaderView<Trailing: View>: View {
    var eyebrow: String
    var title: String
    /// La taille du titre, réglable comme celle de `BackTitleHeaderView` juste en dessous, et pour
    /// la même raison : un onglet de premier niveau ne se lit pas à la même échelle qu'un écran
    /// poussé par-dessus. Le défaut reste la valeur d'avant, donc aucun appelant existant ne bouge.
    var titleSize: RUDisplaySize = .title
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                // L'EYEBROW REPREND LA COULEUR QUE LE SYSTÈME LUI DONNE, et ce n'est pas rose.
                //
                // `EyebrowLabel` porte `text3` par défaut, avec sa raison écrite : la maquette
                // réserve la prose secondaire à `ink2` et met toutes ses micro-étiquettes en
                // `ink3`. Ce composant-ci passait outre et forçait le rose sur l'eyebrow de
                // CHAQUE onglet de premier niveau — une date, « Semaine 4/9 », « Mode course
                // libre ». Aucune de ces lignes n'est une action ; les peindre de la couleur des
                // actions, c'est dépenser l'accent sur ce qui ne le mérite pas, en haut de chaque
                // écran de l'app.
                EyebrowLabel(text: eyebrow)
                Text(LocalizedStringKey(title)).displayStyle(titleSize).foregroundColor(RUColor.textPrimary)
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 2)
    }
}

/// Back-chevron + title header used at the top of most sub-screens — was hand-rolled
/// independently in ~10 files (`HStack(spacing: 12) { BackChevronButton {...}; Text(title)... }`),
/// each with its own one-off font size and eyebrow-or-not choice. Consolidates that repeated
/// shape into one component while still letting each screen pick its own title size/eyebrow,
/// since those really do vary by the screen's place in the hierarchy (a top-level tab reads
/// larger than a modal push).
struct BackTitleHeaderView<Trailing: View>: View {
    var eyebrow: String? = nil
    /// Même raison qu'au-dessus : le défaut suit `EyebrowLabel`, qui met ses micro-étiquettes en
    /// `text3`. Les appelants qui veulent vraiment un accent le passent — aucun ne le fait
    /// aujourd'hui, ce qui dit assez que le rose n'était pas un choix mais un défaut hérité.
    var eyebrowColor: Color = RUColor.text3
    var title: String
    var titleSize: RUDisplaySize = .title
    var onBack: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            BackChevronButton(action: onBack)
            if let eyebrow {
                VStack(alignment: .leading, spacing: 2) {
                    EyebrowLabel(text: eyebrow, color: eyebrowColor)
                    Text(LocalizedStringKey(title)).displayStyle(titleSize).foregroundColor(RUColor.textPrimary)
                }
            } else {
                Text(LocalizedStringKey(title)).displayStyle(titleSize).foregroundColor(RUColor.textPrimary)
            }
            Spacer()
            trailing
        }
    }
}

extension BackTitleHeaderView where Trailing == EmptyView {
    init(eyebrow: String? = nil, eyebrowColor: Color = RUColor.text3, title: String, titleSize: RUDisplaySize = .title, onBack: @escaping () -> Void) {
        self.init(eyebrow: eyebrow, eyebrowColor: eyebrowColor, title: title, titleSize: titleSize, onBack: onBack, trailing: { EmptyView() })
    }
}

/// Circular first-initial avatar button, the default trailing accessory used across headers.
/// The visible circle stays 36pt (unchanged look), but the tappable area grows to Apple's 44pt
/// HIG minimum via the outer frame + `.contentShape` — no `accessibilityLabel` existed anywhere
/// in the app before this pass, so VoiceOver read every icon-only button as just "button".
struct AvatarButton: View {
    var initial: String
    /// Her real profile photo, if she's set one — `AvatarView` falls back to the initial-letter
    /// circle when nil, same as every other avatar spot in the app.
    var imageData: Data? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            // `useGradient: false` donnait, depuis le passage au dégradé maillé, une pastille
            // lavande très pâle : sur un fond clair, le marqueur de sa propre identité devenait
            // l'élément le plus faible de l'en-tête, plus discret que la cloche à côté. La
            // maquette rend « moi » avec le même dégradé partout où on la voit (`class="avatar
            // p-camille"` jusque dans l'en-tête du Profil) — c'est aussi ce que fait déjà
            // `ProfileView`, donc les deux surfaces qui montrent son avatar concordent enfin.
            AvatarView(imageData: imageData, initial: initial, size: 36, useGradient: true)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Profil")
    }
}

/// Back chevron button used at the top of most sub-screens. Same 44pt-tap-target /
/// `accessibilityLabel` treatment as `AvatarButton` above.
struct BackChevronButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("‹")
                .font(.system(size: 22))
                .foregroundColor(RUColor.text2)
                .frame(width: 30, height: 30)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Retour")
    }
}

/// Frosted circular chevron used over imagery (Live Run, Recap hero). Same treatment as
/// `BackChevronButton` above.
struct FrostedBackButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("‹")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(.black.opacity(0.45), in: Circle())
                .background(.ultraThinMaterial, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Retour")
    }
}
