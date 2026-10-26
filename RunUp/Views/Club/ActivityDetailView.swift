import SwiftUI

/// LA SORTIE DÉROULÉE.
///
/// # CE QUI MANQUAIT
///
/// Le fil montrait quatre chiffres d'une course — km, allure, temps, D+ — et c'était un
/// cul-de-sac : on ne pouvait pas l'OUVRIR. Chez Strava, chaque sortie du fil mène à sa page, où
/// se trouvent les kilomètres un par un, le profil du terrain, le cœur. Ces données existaient
/// déjà sur l'appareil de qui avait couru ; elles n'en sortaient simplement jamais.
///
/// # POURQUOI UN APPEL À PART
///
/// Les splits et les altitudes d'une sortie pèsent plus que tout le reste de sa carte, et le fil
/// en charge cinquante d'un coup. On ne paie ce poids que pour la sortie qu'on ouvre vraiment —
/// d'où `api/activities/detail` plutôt que trois champs de plus dans le fil.
///
/// # CE QU'ELLE DIT QUAND IL N'Y A RIEN À DIRE
///
/// Une sortie publiée avant ces champs, une séance saisie à la main, une course sans montre
/// cardio : la page le DIT, au lieu d'afficher des zéros qui passeraient pour des mesures. Une
/// absence de mesure et une mesure nulle ne sont pas la même phrase — c'est la règle de toute
/// l'app, et c'est ici qu'elle se voit le plus.
struct ActivityDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var activityId: String

    @State private var sortie: ActivityDetail?
    @State private var enChargement = true
    @State private var erreur: String?
    @State private var splitsRevelees = false
    @State private var commentairesOuverts = false

    private var clubService: ClubService { ClubService(auth: appState.auth) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                retour

                if enChargement {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 60)
                } else if let erreur {
                    Text("Impossible d'ouvrir cette sortie — \(erreur).")
                        .font(RUFont.sans(.body))
                        .foregroundColor(RUColor.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 40)
                } else if let sortie {
                    auteur(sortie)
                    media(sortie)
                    phrase(sortie)
                    grilleDeMesures(sortie)
                    titreEtNote(sortie)
                    // APPLAUDIR AVANT LES SPLITS, PAS APRÈS. Posées en bas, les deux actions
                    // arrivaient derrière douze barres et un profil de terrain : applaudir
                    // demandait de faire défiler toute l'analyse d'une sortie qu'on venait
                    // d'ouvrir pour la féliciter. Ce qui se répond d'un geste vient en premier ;
                    // ce qui se lit vient ensuite.
                    actions(sortie)
                    blocDesSplits(sortie)
                    blocDuProfil(sortie)
                    sansDetail(sortie)
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .background(RUColor.pageBackground)
        .task { await charger() }
        .sheet(isPresented: $commentairesOuverts) {
            ActivityCommentsSheet(
                activityId: activityId,
                currentUserId: appState.auth.currentUser?.id,
                clubService: clubService,
                onCommentPosted: { Task { await charger() } },
                onReport: { _ in },
                onBlock: { _ in }
            )
            .runUpSheetStyle(detents: [.large])
        }
    }

    /// Un écran plein n'a pas le glissement vers le bas d'une feuille : sans ce bouton, on y est
    /// enfermé. Même chemin de retour que la page d'une course.
    private var retour: some View {
        Button(action: { dismiss() }) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                Text("Retour").font(RUFont.sans(.label, weight: .semibold))
            }
            .foregroundColor(RUColor.text2)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Qui, et quand

    private func auteur(_ s: ActivityDetail) -> some View {
        Button(action: { if !s.isMine { appState.ouvrirLeProfil(s.userId) } }) {
            HStack(spacing: 11) {
                AvatarView(urlString: s.avatarUrl, base64DataURI: s.avatarBase64,
                           initial: String(s.name.prefix(1)), size: 40,
                           seed: s.isMine ? nil : s.userId)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.nomComplet)
                        .font(RUFont.sans(.emphasis, weight: .bold))
                        .foregroundColor(RUColor.textPrimary)
                    Text(s.createdAt.relativeDescription)
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                }
                Spacer(minLength: 0)
                if s.isPersonalRecord { pastilleDeRecord }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(s.isMine ? Text(s.nomComplet)
                                     : Text(String(localized: "Voir le profil de \(s.name)")))
    }

    private var pastilleDeRecord: some View {
        HStack(spacing: 4) {
            Image(systemName: "trophy.fill").font(.system(size: 8, weight: .bold))
            Text("RECORD")
        }
        .font(RUFont.sans(.micro, weight: .bold))
        .tracking(0.4)
        .foregroundColor(RUColor.rose)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(RUColor.rose.opacity(0.14)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Record personnel")
    }

    // MARK: - L'image

    @ViewBuilder
    private func media(_ s: ActivityDetail) -> some View {
        if let brut = s.photoUrl, !brut.isEmpty, let url = URL(string: brut) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    RUColor.card
                    ProgressView().tint(RUColor.text2)
                }
            }
            .aspectRatio(4.0 / 5.0, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
            .accessibilityElement()
            .accessibilityLabel("Photo de la sortie")
        } else if s.route.count > 1 {
            trace(s)
        }
    }

    /// Le tracé en grand. Le fond reste sombre dans les deux thèmes, pour la même raison que dans
    /// le fil : une ligne fine et colorée se lit sur du sombre, et devient un gribouillis pâle
    /// sur du clair.
    private func trace(_ s: ActivityDetail) -> some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1A1926), Color(hex: 0x0E0D16)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            SelfDrawingRoute(route: s.route, lineWidth: 3.5,
                             colors: [RUColor.rose, RUColor.violet],
                             targetPoints: 140, showsStart: true)
                .padding(22)
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
        .accessibilityElement()
        .accessibilityLabel("Tracé de la sortie")
    }

    // MARK: - Ce qui s'est passé

    private func phrase(_ s: ActivityDetail) -> some View {
        Text(s.localizedText)
            .font(RUFont.sans(.emphasis, weight: .bold))
            .foregroundColor(RUColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func titreEtNote(_ s: ActivityDetail) -> some View {
        if let titre = s.title, !titre.isEmpty {
            Text(titre)
                .font(RUFont.sans(.label, weight: .bold))
                .foregroundColor(RUColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        if let note = s.note, !note.isEmpty {
            Text(note)
                .font(RUFont.sans(.body))
                .foregroundColor(RUColor.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Les mesures, en grille plutôt qu'en ligne : à six, une rangée de colonnes séparées par des
    /// filets donnerait à chaque chiffre un sixième de la largeur de l'écran, et chacun devrait
    /// rétrécir pour tenir. Trois par rangée, un chiffre a la place d'être un chiffre.
    ///
    /// Seules les mesures RÉELLEMENT prises y figurent. Une case « 0 bpm » dirait qu'un cœur a
    /// été mesuré à zéro.
    private func grilleDeMesures(_ s: ActivityDetail) -> some View {
        let cases = mesures(s)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                   GridItem(.flexible(), spacing: 10),
                                   GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(cases, id: \.libelle) { mesure in
                VStack(alignment: .leading, spacing: 3) {
                    Text(mesure.valeur)
                        .displayStyle(20)
                        .foregroundColor(RUColor.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(LocalizedStringKey(mesure.libelle))
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text3)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10).padding(.horizontal, 12)
                .ruCard(radius: RUSpacing.radiusCompact)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private struct Mesure { var valeur: String; var libelle: String }

    private func mesures(_ s: ActivityDetail) -> [Mesure] {
        var out: [Mesure] = []
        if let km = s.distanceKm, km > 0 { out.append(Mesure(valeur: Distances.km(km), libelle: "distance")) }
        if let duree = s.durationDisplay { out.append(Mesure(valeur: duree, libelle: "temps")) }
        if let allure = s.avgPace, !allure.isEmpty { out.append(Mesure(valeur: allure, libelle: "allure")) }
        if let dplus = s.elevationGainM, dplus > 0 { out.append(Mesure(valeur: "\(dplus) m", libelle: "D+")) }
        if let fc = s.avgHeartRate { out.append(Mesure(valeur: "\(fc)", libelle: "bpm moyen")) }
        if let kcal = s.kcal { out.append(Mesure(valeur: "\(kcal)", libelle: "kcal")) }
        return out
    }

    // MARK: - En profondeur

    @ViewBuilder
    private func blocDesSplits(_ s: ActivityDetail) -> some View {
        if !s.splits.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                RUCardHeader(title: "Splits par km")
                SplitsView(splits: s.splits, revealed: splitsRevelees, reduceMotion: reduceMotion)
            }
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private func blocDuProfil(_ s: ActivityDetail) -> some View {
        if ElevationProfileView.hasData(s.route) {
            VStack(alignment: .leading, spacing: 10) {
                RUCardHeader(title: "Profil d'élévation")
                ElevationProfileView(route: s.route)
                    .frame(height: 110)
                    .padding(.vertical, 10).padding(.horizontal, 12)
                    .ruCard(radius: RUSpacing.radiusCompact)
            }
            .padding(.top, 6)
        }
    }

    /// Dit à voix haute ce que la page n'a pas pu montrer, et pourquoi. Sans cette ligne, une
    /// sortie publiée avant que ces champs n'existent ouvrirait sur une page qui répète la carte
    /// du fil — et on croirait l'app cassée plutôt que la donnée absente.
    @ViewBuilder
    private func sansDetail(_ s: ActivityDetail) -> some View {
        if !s.aDuDetail {
            Text("Cette sortie n'a pas de détail enregistré : pas de temps au kilomètre, pas de profil, pas de cardio.")
                .font(RUFont.sans(.small))
                .foregroundColor(RUColor.text3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }

    // MARK: - Applaudir, commenter

    private func actions(_ s: ActivityDetail) -> some View {
        HStack(spacing: 18) {
            Button(action: { Task { await applaudir() } }) {
                HStack(spacing: 7) {
                    Image(systemName: s.kudoedByMe ? "hands.clap.fill" : "hands.clap")
                        .font(.system(size: 16, weight: .regular))
                    if s.kudos > 0 {
                        Text("\(s.kudos)")
                            .font(RUFont.sans(.body, weight: .semibold))
                            .contentTransition(.numericText())
                    }
                }
                .foregroundColor(s.kudoedByMe ? RUColor.rose : RUColor.text2)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(s.kudoedByMe ? "Retirer ton applaudissement" : "Applaudir cette séance")
            .accessibilityValue("\(s.kudos)")

            Button(action: { commentairesOuverts = true }) {
                HStack(spacing: 7) {
                    Image(systemName: "bubble.right").font(.system(size: 16, weight: .regular))
                    if s.commentsCount > 0 {
                        Text("\(s.commentsCount)").font(RUFont.sans(.body, weight: .semibold))
                    }
                }
                .foregroundColor(RUColor.text2)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Commenter")
            .accessibilityValue("\(s.commentsCount)")

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    // MARK: - Réseau

    private func charger() async {
        // En démonstration, le cache est tout : pas de serveur en face d'un simulateur. Même
        // raison qu'au fil, au club et sur la page de quelqu'un.
        if Demonstration.enCours {
            sortie = appState.cachedActivityDetail
            enChargement = false
            reveler()
            return
        }
        enChargement = true
        erreur = nil
        do {
            sortie = try await clubService.fetchActivityDetail(id: activityId)
            reveler()
        } catch {
            erreur = PanneReseau.motif(pour: error)
        }
        enChargement = false
    }

    /// Les barres des splits se remplissent APRÈS l'arrivée des données, pas à l'apparition de
    /// l'écran : déclenchée trop tôt, l'animation se jouerait sur une liste vide et les barres
    /// apparaîtraient déjà pleines.
    private func reveler() {
        guard !splitsRevelees else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { splitsRevelees = true }
    }

    private func applaudir() async {
        guard let courante = sortie else { return }
        // L'affichage bouge d'abord : un applaudissement qui attend l'aller-retour se lit comme
        // un bouton qui n'a pas pris. Il est remis en place si le serveur refuse.
        let avant = courante.kudoedByMe
        sortie?.kudoedByMe = !avant
        sortie?.kudos += avant ? -1 : 1
        Haptics.impact(.light)
        do {
            let maintenant = try await clubService.toggleKudos(activityId: activityId)
            sortie?.kudoedByMe = maintenant
        } catch {
            sortie?.kudoedByMe = avant
            sortie?.kudos = courante.kudos
        }
    }
}
