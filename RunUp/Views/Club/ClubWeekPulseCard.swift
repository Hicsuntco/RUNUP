import SwiftUI

/// Le pouls de la semaine du club.
///
/// Sortie de `ClubView` au deuxième morceau de la découpe, et c'était le moins cher qui restait :
/// elle ne demande que le magasin, aucune liaison. Voir « Chantier 36 » dans `PROGRESS.md`.
struct ClubWeekPulseCard: View {
    let magasin: ClubStore

    /// The club's pulse this week — real collective km + how many members actually ran, computed
    /// server-side over this Monday-started week. Gives the club a shared "we" number, not just
    /// individual rankings.
    /// Les kilomètres du club cette semaine, et qui les a courus.
    ///
    /// Le nombre de membres actifs vivait ici, en chiffre, ET trois cartes plus bas en pile
    /// d'avatars sous son propre intertitre « Membres actifs cette semaine ». Deux blocs pour un
    /// seul fait, séparés par le défi et les sorties de groupe — assez loin l'un de l'autre pour
    /// qu'on ne remarque pas que c'est le même. Les visages remplacent le chiffre : ils le
    /// contiennent (on les compte) et disent en plus QUI, ce que « 4 » ne dira jamais.
    var body: some View {
        let stats = magasin.board.weekStats
        let km = String(format: "%.1f", locale: Locale.current, stats?.totalKm ?? 0)
        let active = (magasin.board.weekly ?? []).filter { $0.weekKm > 0 }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    RUCardHeader(title: "Le club cette semaine", subtitle: "Kilomètres cumulés")
                    // « 0,0 KM » EN GRAND N'EST PAS UNE INFORMATION, C'EST UN REPROCHE.
                    //
                    // Un club qui démarre, ou un lundi matin, ouvrait sur un zéro de vingt-six
                    // points dans un cadre plein. Le chiffre ne s'écrit donc en grand que
                    // lorsqu'il y a quelque chose à écrire ; sinon, une phrase.
                    if stats?.totalKm ?? 0 > 0 {
                        // « km » et non « KM » : sur ce même écran, les quatre records écrivent
                        // déjà leur unité en minuscules. Deux casses pour la même unité, à trois
                        // centimètres l'une de l'autre.
                        RUChiffre(valeur: km, unite: "km")
                    } else {
                        Text("Personne n'a encore couru cette semaine.")
                            .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                    }
                }
                Spacer(minLength: 8)
            }
            if !active.isEmpty {
                HStack(spacing: 10) {
                    HStack(spacing: -8) {
                        ForEach(active.prefix(6)) { member in
                            AvatarView(
                                urlString: member.avatarUrl,
                                base64DataURI: member.avatarBase64,
                                initial: String(member.name.prefix(1)),
                                size: 28,
                                seed: member.isMe ? nil : member.id
                            )
                            .overlay(Circle().stroke(RUColor.card, lineWidth: 2))
                        }
                        if active.count > 6 {
                            Text("+\(active.count - 6)")
                                .font(RUFont.sans(.small, weight: .bold))
                                .foregroundColor(RUColor.text2)
                                .frame(width: 28, height: 28)
                                .background(RUColor.card2, in: Circle())
                                .overlay(Circle().stroke(RUColor.card, lineWidth: 2))
                        }
                    }
                    Text(Pluriel.choisir(active.count,
                                         String(localized: "\(active.count) membre a couru"),
                                         String(localized: "\(active.count) membres ont couru")))
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Pluriel.choisir(active.count,
                                                    String(localized: "\(active.count) membre a couru cette semaine"),
                                                    String(localized: "\(active.count) membres ont couru cette semaine")))
            }
        }
        // Les pastilles des membres actifs se cerclent de `RUColor.card` pour se chevaucher
        // proprement : ce liseré n'a de sens que sur une carte. Posé sur le fond lavande, il
        // dessinait des anneaux blancs autour des visages.
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }


}
