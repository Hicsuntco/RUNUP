import SwiftUI

/// LES DEUX CLASSEMENTS DU CLUB — la semaine en kilomètres, et l'XP de toujours.
///
/// Sortis de `ClubView`, qui faisait 2 721 lignes et portait 113 membres privés. Ce n'est pas
/// un découpage par longueur : c'est la région la MOINS liée au reste de l'écran, et c'est
/// pour ça qu'elle part la première.
///
/// Relevé avant de couper, état par état, sur les cinq régions du fichier : des trente états
/// de `ClubView`, `boardMode` et `weeklyDisplayMode` ne servaient qu'ici — ils deviennent des
/// `@State` de cette vue, et personne d'autre ne peut plus les lire. `board` et `isLoading`
/// sont des données que le classement AFFICHE sans jamais les changer : ils entrent en `let`,
/// ce qui le dit mieux qu'un commentaire. `reportTarget` et `pendingBlock` restent au parent,
/// parce que c'est lui qui porte la feuille de signalement et l'alerte de blocage ; ils
/// entrent en `@Binding`, les deux seules choses que cette vue écrive chez quelqu'un d'autre.
///
/// Ce que ce découpage DOIT garantir : que l'écran ne bouge pas d'un pixel. Les quatre
/// captures du Club — le mur, l'aperçu, le bas de l'aperçu, le classement — sont prises à
/// chaque exécution, et `ci_scripts/comparer.py` compare celles d'avant à celles d'après.
struct ClubBoardSection: View {
    /// Le classement tel que le serveur l'a rendu. Cette vue le lit, elle ne le recharge pas :
    /// le chargement appartient à l'écran du club, qui le fait une fois pour ses trois onglets.
    let board: ClubBoard
    /// Vrai tant que le premier chargement n'est pas revenu — c'est ce qui sépare « personne
    /// n'a couru cette semaine » de « on ne sait pas encore ».
    let isLoading: Bool
    /// La feuille de signalement et l'alerte de blocage vivent sur l'écran du club : une ligne
    /// de classement les déclenche, elle ne les présente pas.
    @Binding var reportTarget: ReportTarget?
    @Binding var pendingBlock: (userId: String, name: String)?

    @Environment(AppState.self) private var appState

    /// Lequel des deux classements l'onglet montre : la course aux kilomètres de la semaine, ou
    /// l'XP de toujours.
    @State private var boardMode: BoardMode = .week

    /// LE CLASSEMENT MONDIAL EST PARTI, ET C'EST UNE DÉCISION DE FOND.
    ///
    /// Un club de course est LOCAL. Se comparer aux kilomètres de quelqu'un qu'on ne croisera
    /// jamais, dans une ville qu'on ne connaît pas, ne fait pas courir — ça ne fait même pas un
    /// classement, ça fait un palmarès mondial où personne ne se reconnaît. Ce que le club
    /// compare, c'est ses membres entre eux, et c'est tout ce qui a du sens.
    ///
    /// Partent avec lui : la pastille « Mondial », son contenu, son interrupteur de
    /// participation et ses deux appels au serveur. La colonne `global_leaderboard_opt_in`
    /// reste en base — la retirer serait une migration destructrice pour rien.
    private enum BoardMode { case week, general }
    /// Only meaningful within `BoardMode.week` — raw km (server-ranked) vs. each member's own %
    /// of their real weekly plan (`WeeklyRow.pctOfTarget`, client-ranked — see `weekBoardContent`).
    /// The whole reason this mode exists: a mixed-level club (a beginner on 15 km/week next to a
    /// marathoner on 60) stays motivating for everyone, not just whoever runs the most raw distance.
    @State private var weeklyDisplayMode: WeeklyDisplayMode = .km
    // Same `CaseIterable, Identifiable` shape as `StatsView.StatsRange` — lets the picker below use
    // `ForEach(WeeklyDisplayMode.allCases)` directly instead of a hand-rolled `id:` keypath.
    private enum WeeklyDisplayMode: CaseIterable, Identifiable, Equatable {
        case km, pctObjectif
        var id: Self { self }
    }

    private func boardModeChip(_ label: String, _ value: BoardMode) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) { boardMode = value }
        }) {
            Text(label)
                .font(RUFont.sans(.small, weight: .semibold))
                .foregroundColor(boardMode == value ? RUColor.rose2 : RUColor.text2)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .frame(minHeight: 44)
                // Les deux branches de ce ternaire valaient `card2` : le sélecteur ne changeait
                // donc de REMPLISSAGE jamais, et la pastille active ne se distinguait que par un
                // filet et une nuance de texte — le signal le plus faible de l'app. Tous ses
                // voisins écrivent `card2 : card`.
                .background(boardMode == value ? RUColor.card2 : RUColor.card, in: Capsule())
                .overlay(Capsule().stroke(boardMode == value ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(boardMode == value ? .isSelected : [])
    }

    /// LES MORCEAUX SONT PETITS PARCE QUE LE COMPILATEUR L'A EXIGÉ.
    ///
    /// Les trois blocs de lignes — presque identiques, vingt-cinq lignes chacun — et la chaîne
    /// de `if` et de `.transition()` tenaient dans une seule expression `ViewBuilder`, et ça
    /// suffisait à épuiser le budget du vérificateur de types : `unable to type-check this
    /// expression in reasonable time`, un vrai échec de construction et non une remarque de
    /// style. Les découper est exactement ce que le message d'erreur de Xcode propose, et ça
    /// règle au passage le même défaut que `HomeView.programWeekCard` avait eu — un `if` sans
    /// `else` ne prend pas de modificateur directement, d'où le `Group`.
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Two real races: km of THIS week (Monday reset — a newcomer can win her first week)
            // and the all-time XP board.
            HStack(spacing: 6) {
                boardModeChip(String(localized: "Cette semaine"), .week)
                boardModeChip(String(localized: "Général (XP)"), .general)
            }
            Group {
                if boardMode == .week {
                    weekBoardContent
                } else {
                    generalBoardContent
                }
            }
            .transition(.opacity)
        }
    }

    /// Ranked by raw `weekKm` (the server's own order) in `.km` mode; re-ranked client-side by
    /// `pctOfTarget` in `.pctObjectif` mode — the server always orders by km since that's the one
    /// true race everyone shares, but "closest to YOUR OWN plan" is a different ranking entirely
    /// (a beginner at 110% of her plan legitimately outranks a marathoner at 70% of his, even
    /// though his raw km is much higher). Rows with no `pctOfTarget` (hasn't opened Club since
    /// this shipped, or course libre) sort to the bottom rather than being dropped — still visible,
    /// just falls back to a plain km display for that one row.
    private var rankedWeekly: [WeeklyRow] {
        let rows = board.weekly ?? []
        guard weeklyDisplayMode == .pctObjectif else { return rows }
        return rows.sorted { a, b in
            switch (a.pctOfTarget, b.pctOfTarget) {
            case let (pa?, pb?): return pa > pb
            case (nil, nil): return a.weekKm > b.weekKm
            case (nil, _): return false
            case (_, nil): return true
            }
        }
    }

    private var weekBoardContent: some View {
        Group {
            if (board.weekly ?? []).isEmpty && !isLoading {
                RUEmpty(forme: .ligne,
                        message: String(localized: "Personne n'a encore couru cette semaine — lance-toi !"))
                    .padding(.vertical, 18)
            } else {
                // La bascule Km / % objectif était posée seule, alignée à droite, sans rien
                // dire de ce qu'elle bascule. La maquette lui donne son titre de section sur la
                // même ligne — c'est ce qui fait qu'on comprend « classement DE LA SEMAINE » et
                // pas « classement tout court, avec un réglage mystérieux ».
                HStack {
                    RUCardHeader(title: "Classement de la semaine")
                    Spacer(minLength: 8)
                    weeklyDisplayModePicker
                }
                .padding(.bottom, 2)
                weekBoardRows
            }
        }
    }

    /// POURQUOI LE CLASSEMENT EST UNE LISTE À FILETS, ET NON UNE PILE DE CARTES.
    ///
    /// Les lignes étaient des cartes individuelles (fond `card2` + contour + rayon 14), empilées
    /// avec 6 pt d'écart : douze membres donnaient douze cartes à contours, soit un classement
    /// qui ressemblait à une liste de réglages. Un classement est une seule et même liste
    /// ordonnée — un filet entre les lignes le dit, et ça permet d'en afficher nettement plus
    /// par écran. La ligne « toi » garde, elle, son fond teinté : c'est le seul repère qui doit
    /// sauter aux yeux, et il ressort beaucoup mieux maintenant qu'il est le seul fond de la
    /// liste (le filet saute de part et d'autre pour ne pas venir couper ce bloc arrondi).
    private var weekBoardRows: some View {
        let rows = rankedWeekly
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                if index > 0 && !entry.isMe && !rows[index - 1].isMe {
                    RUFilet()
                }
                weekRow(entry, displayRank: index + 1)
            }
        }
    }

    /// Same pill-in-capsule idiom as `StatsView.rangePicker` — Km vs. "% objectif" for the weekly
    /// board only (the all-time XP/global boards have no personal target to compare against).
    private var weeklyDisplayModePicker: some View {
        HStack(spacing: 4) {
            ForEach(WeeklyDisplayMode.allCases) { mode in
                Button(action: {
                    Haptics.selection()
                    weeklyDisplayMode = mode
                }) {
                    Text(mode == .km ? "Km" : "% objectif")
                        // Était en chasse fixe : deux mots de réglage dans une typographie que
                        // rien d'autre de l'écran n'emploie, à côté d'un titre de section en
                        // sans. La chasse fixe sert les CHIFFRES qui s'alignent en colonne,
                        // pas les étiquettes.
                        .font(RUFont.sans(.small, weight: .semibold))
                        .foregroundColor(weeklyDisplayMode == mode ? .white : RUColor.text2)
                        // Même hauteur que le sélecteur de période des Stats, dont c'est l'idiome.
                        .padding(.horizontal, 10).padding(.vertical, 10)
                        .background(
                            // Un aplat d'accent, comme toutes les pastilles sélectionnées de
                            // l'app : c'était un dégradé, et la règle 7 l'interdit.
                            weeklyDisplayMode == mode
                                ? AnyShapeStyle(RUColor.rose)
                                : AnyShapeStyle(Color.clear),
                            in: Capsule()
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: weeklyDisplayMode)
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(weeklyDisplayMode == mode ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RUColor.card2, in: Capsule())
    }

    /// LE RANG, ÉCRIT TROIS FOIS ET SANS MÉDAILLE.
    ///
    /// Les trois premières places portaient 🥇🥈🥉 — des émojis en couleurs d'impression au
    /// milieu d'une liste sombre et sobre, et la chose la moins chère à l'œil de tout l'écran.
    /// Un classement n'a pas besoin d'images pour dire qui mène : le chiffre le dit, et l'or de
    /// la première place suffit à la distinguer. Les deuxième et troisième reprennent leur rang,
    /// comme la quatrième et la cinquième — la hiérarchie est dans l'ordre de la liste, pas dans
    /// trois pastilles de couleur.
    ///
    /// Et il était recopié à l'identique dans les TROIS classements (semaine, général, mondial),
    /// donc corrigé une fois ici plutôt que trois fois là-bas.
    private func rang(_ valeur: Int, estMoi: Bool) -> some View {
        Text("\(valeur)")
            .displayStyle(.label)
            .foregroundColor(estMoi ? RUColor.rose2 : (valeur == 1 ? RUColor.amber : RUColor.text2))
            .frame(width: 20)
    }

    private func weekRow(_ entry: WeeklyRow, displayRank: Int) -> some View {
        Button(action: { if !entry.isMe { appState.ouvrirLeProfil(entry.id) } }) {
        HStack(spacing: 12) {
            rang(displayRank, estMoi: entry.isMe)
            AvatarView(urlString: entry.avatarUrl, base64DataURI: entry.avatarBase64, initial: String(entry.name.prefix(1)), size: 28, seed: entry.isMe ? nil : entry.id)
            Text(entry.isMe ? String(localized: "\(entry.nomComplet) · toi") : entry.nomComplet)
                .font(RUFont.sans(.label, weight: entry.isMe ? .semibold : .regular))
                .foregroundColor(RUColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            if weeklyDisplayMode == .pctObjectif, let pct = entry.pctOfTarget {
                weeklyPctBadge(pct: pct, isMe: entry.isMe)
            } else {
                Text(verbatim: "\(String(format: "%.1f", locale: Locale.current, entry.weekKm)) km")
                    .displayStyle(.label).foregroundColor(entry.isMe ? RUColor.rose2 : RUColor.textPrimary)
            }
        }
        // Même retrait horizontal pour TOUTES les lignes (et non un retrait plus grand pour la
        // mienne, comme le fait la maquette avec sa marge négative) : ici les colonnes — rang,
        // avatar, nom — doivent rester alignées d'une ligne à l'autre, sinon la ligne « toi » a
        // l'air décalée par erreur. Le fond teinté suffit largement à la distinguer.
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(entry.isMe ? RUColor.rose.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
        .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(entry.isMe)
    }

    /// A compact progress ring + percentage, replacing the raw-km number in "% objectif" mode —
    /// lime past 100% of plan (she's beaten her own target), rose otherwise. The ring itself is
    /// visually capped at a full circle past 100% (going further doesn't need to overflow the
    /// shape to read as "done and then some" — the number next to it already says 114%).
    private func weeklyPctBadge(pct: Int, isMe: Bool) -> some View {
        let fraction = min(Double(pct) / 100, 1)
        let color = pct >= 100 ? RUColor.lime : (isMe ? RUColor.rose2 : RUColor.textPrimary)
        return HStack(spacing: 6) {
            ZStack {
                Circle().stroke(RUColor.line, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 20, height: 20)
            Text("\(pct)%").displayStyle(.label).foregroundColor(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pct) pour cent de l'objectif de la semaine")
    }

    private var generalBoardContent: some View {
        let rows = board.leaderboard
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, entry in
                if index > 0 && !entry.isMe && !rows[index - 1].isMe {
                    RUFilet()
                }
                generalRow(entry)
            }
        }
    }

    /// TOUTE LA LIGNE OUVRE LA PAGE DU MEMBRE, et c'est un `Button` et non un `onTapGesture`.
    ///
    /// La nuance a déjà coûté un défaut dans ce fichier : une bande qui défile, un geste de tape
    /// posé dessus, et taper pour arrêter l'inertie du défilement déclenchait l'action. Un
    /// `Button` placé dans une vue défilante ne répond pas à la tape qui arrête la décélération ;
    /// un `onTapGesture`, si. Sur un classement qu'on fait défiler, c'est la différence entre
    /// « j'ai arrêté la liste » et « je me retrouve sur le profil de quelqu'un ».
    private func generalRow(_ entry: LeaderboardRow) -> some View {
        Button(action: { if !entry.isMe { appState.ouvrirLeProfil(entry.id) } }) {
        HStack(spacing: 12) {
            rang(entry.rank, estMoi: entry.isMe)
            AvatarView(urlString: entry.avatarUrl, base64DataURI: entry.avatarBase64, initial: String(entry.name.prefix(1)), size: 28, seed: entry.isMe ? nil : entry.id)
            Text(entry.isMe ? String(localized: "\(entry.nomComplet) · toi") : entry.nomComplet)
                .font(RUFont.sans(.label, weight: entry.isMe ? .semibold : .regular))
                .foregroundColor(RUColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Text("\(entry.xp)").displayStyle(.label).foregroundColor(entry.isMe ? RUColor.rose2 : RUColor.textPrimary)
        }
        // Même chrome que `weekRow` ci-dessus (retrait uniforme, fond teinté pour « toi »).
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(entry.isMe ? RUColor.rose.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
        .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        // Sa propre ligne ne mène nulle part : on est déjà à un onglet de son profil, et un
        // aller-retour vers soi-même n'apprend rien.
        .disabled(entry.isMe)
        .contextMenu {
            if !entry.isMe {
                Button("Signaler \(entry.name)") {
                    reportTarget = ReportTarget(targetType: "user", targetId: entry.id, displayName: entry.nomComplet)
                }
                Button("Bloquer \(entry.name)", role: .destructive) {
                    pendingBlock = (entry.id, entry.name)
                }
            }
        }
    }
}
