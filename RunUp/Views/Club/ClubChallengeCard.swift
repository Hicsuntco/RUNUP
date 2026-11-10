import SwiftUI

/// Le défi en cours du club, ou l'invitation à en lancer un.
///
/// Sortie de `ClubView` au deuxième morceau de la découpe. Elle demande UNE liaison —
/// `showManagement`, parce que le bouton « lancer un défi » ouvre la gestion du club — et c'est
/// la seule. Voir « Chantier 36 » dans `PROGRESS.md`.
struct ClubChallengeCard: View {
    let magasin: ClubStore
    @Binding var showManagement: Bool

    /// Any member can set the club's challenge (see "Gestion du club") — this used to always show
    /// a fixed "100 km ce mois-ci" regardless of whether anyone had actually agreed to that goal.
    /// `progressKm` is a real sum computed server-side over every member's logged runs since the
    /// challenge was created, not just this device's local history.
    /// UNE SECTION, PAS UNE CARTE — et surtout pas une carte VIDE.
    ///
    /// « Défi du club / Aucun défi en cours » occupait un rectangle plein de cent points de haut
    /// pour dire qu'il n'y avait rien à dire. Deux de ces blocs se suivaient en tête de l'écran,
    /// et c'est tout ce qu'on voyait d'un club qui démarre : deux grands cadres vides.
    ///
    /// L'invitation à en créer un reste, en une ligne discrète — c'est la même forme que
    /// « Sorties de groupe » juste en dessous, qui n'a jamais eu besoin d'un cadre pour dire
    /// qu'aucune sortie n'est prévue.
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let challenge = magasin.board.challenge {
                HStack {
                    RUCardHeader(title: "Défi du club")
                    StatChip(text: String(localized: "J-\(daysLeft(until: challenge.endDate))"), color: RUColor.rose2)
                }
                Text(challenge.title).displayStyle(.subtitle).foregroundColor(RUColor.textPrimary)
                LinearBar(fraction: challenge.targetKm > 0 ? min(1, challenge.progressKm / challenge.targetKm) : 0, color: RUColor.rose)
                HStack {
                    Text(challengeProgressText(challenge)).font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                    Spacer()
                    Text("ensemble").font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                }
            } else {
                HStack {
                    RUCardHeader(title: "Défi du club")
                    Spacer(minLength: 8)
                    Button(action: { showManagement = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus").font(RUFont.icone(.small, weight: .bold))
                            Text("Créer").font(RUFont.sans(.small, weight: .semibold))
                        }
                        .foregroundColor(RUColor.rose2)
                        .padding(8)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                }
                RUEmpty(forme: .ligne,
                        message: String(localized: "Aucun défi en cours — un objectif de kilomètres à se partager, avec une date de fin."))
                    .padding(.horizontal, 2)
            }
        }
        .ruCarteSiPleine(magasin.board.challenge != nil)
    }


    /// Les jours qui restent, jamais négatifs : un défi dont la date est passée affiche « J-0 »
    /// et non « J--3 ». Descendu de `ClubView` avec la carte, parce qu'elle est sa seule appelante.
    private func daysLeft(until date: Date) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0)
    }

    /// « 312 / 500 km — 62 % ». Le pourcentage est celui que la barre juste au-dessus dessine
    /// déjà : la maquette le met en toutes lettres, et c'est le chiffre qu'on cherche vraiment
    /// (« on en est où »), là où deux nombres bruts obligent à faire la division de tête. Rien
    /// d'inventé — c'est exactement `progressKm / targetKm`, tous deux calculés côté serveur.
    private func challengeProgressText(_ challenge: ClubChallenge) -> String {
        // Pas de `String(localized:)` : deux nombres, une barre, « km ». Rien à traduire, et
        // une clé au catalogue pour ça aurait deux traductions identiques à la française.
        let base = "\(Int(challenge.progressKm)) / \(Int(challenge.targetKm)) km"
        guard challenge.targetKm > 0 else { return base }
        let pct = Int((challenge.progressKm / challenge.targetKm * 100).rounded())
        return "\(base) — \(pct) %"
    }

}
