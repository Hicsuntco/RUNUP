import SwiftUI
import UIKit
import SwiftData

/// Bell-icon notifications sheet — marks all as read on open. Mirrors `NotifsSheet` in screensC.jsx.
struct NotificationsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppNotification.timestamp, order: .reverse) private var notifications: [AppNotification]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Notifications").displayStyle(.title).foregroundColor(RUColor.textPrimary).padding(.top, 8)

                if notifications.isEmpty {
                    // Was a blank scroll area under the title with no empty-state copy at all —
                    // every other list screen in the app at least says something here.
                    VStack(spacing: 10) {
                        Image(systemName: "bell.slash").font(.system(size: 28)).foregroundColor(RUColor.text3)
                        Text("Rien pour l'instant").font(RUFont.sans(.emphasis, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                        Text("Tes séances, tes séries et l'activité du club apparaîtront ici.")
                            .font(RUFont.sans(.body)).foregroundColor(RUColor.text2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }

                VStack(spacing: 8) {
                    ForEach(notifications) { n in
                        HStack(alignment: .top, spacing: 12) {
                            if n.icon == "mark" {
                                AppMarkView(size: 36)
                            } else {
                                // UN SYMBOLE QUAND C'EN EST UN, LE TEXTE BRUT SINON.
                                //
                                // Les six icônes de notification de l'app étaient des emojis —
                                // ⌚ ✅ 🌙 🎉 👟 🔥 — dans une app dont tout le reste du chrome
                                // est en symboles système. Un emoji change de dessin à chaque
                                // version d'iOS, ne prend pas la graisse de l'interface, et
                                // porte sa propre palette à côté de celle qu'on vient de régler.
                                //
                                // Le repli n'est pas de la prudence : l'icône est ENREGISTRÉE
                                // dans la base avec la notification. Celles qui sont déjà posées
                                // sur l'appareil portent encore un emoji, et `Image(systemName:)`
                                // sur « 🔥 » ne dessine rien du tout. On regarde donc si la
                                // chaîne nomme un symbole, et on retombe sur le texte sinon.
                                Circle().fill(Color(hex: UInt32(n.colorHex))).frame(width: 36, height: 36)
                                    .overlay {
                                        if UIImage(systemName: n.icon) != nil {
                                            Image(systemName: n.icon)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.white)
                                        } else {
                                            Text(n.icon).font(.system(size: 15))
                                        }
                                    }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(n.title).font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                                Text(n.text).font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(2)
                                Text(n.timestamp, style: .relative).font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        // `card` et non `card2` : posée à même le fond de la feuille, cette carte est une
                        // CARTE, pas une sous-surface. Depuis l'inversion du thème clair, `card2`
                        // (#F1F1F6) sur `bg` (#F4F4F8) donne 1,03:1 — la même couleur à l'œil, donc
                        // plus aucune carte, juste une colonne de textes flottants.
                        .ruCard(radius: RUSpacing.radiusCard)
                    }
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            // L'encart du bas n'est plus posé ici : `runUpSheetStyle` le donne à toutes les
            // feuilles, d'une seule valeur. Voir `RUSpacing.sheetBottomInset`.
        }
        .onAppear {
            for n in notifications where !n.read { n.read = true }
        }
    }
}
