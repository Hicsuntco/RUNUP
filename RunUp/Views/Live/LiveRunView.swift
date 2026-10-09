import SwiftUI
import MapKit
import UIKit

/// Live run tracking — real MapKit + CoreLocation route, coach voice cues, and a GPS-instability
/// banner driven by actual signal accuracy. Mirrors `LiveScreen` in screensA.jsx, with a real map
/// in place of the prototype's stylized SVG route (see architecture decision).
///
/// Deliberately always-dark, unlike every other screen — not an oversight (checked: an audit
/// flagged the flip between light-themed Home and this screen as looking like a bug). Every
/// element here — the white numbers/text, the white pause button, the translucent-black STOP
/// button — was chosen assuming a dark backdrop specifically for outdoor glanceability in direct
/// sunlight, the same reasoning Nike Run Club/Strava's own live-tracking screens stay dark
/// regardless of the rest of the app's theme. Re-theming the *background* alone (swap
/// `Color(hex: 0x0A0A0E)` for `RUColor.bg`) without redesigning every element built against it —
/// the white pause button and white metric text would both go invisible against a white
/// background in light mode — would make this screen worse, not better. Same documented-exception
/// treatment as `RUSpacing.radiusHero`.
///
/// This is also why `Color(hex: 0xFFD79A)`/`Color(hex: 0x0E0E14)` below pin `RUColor.amberText`/
/// `.bg`'s *dark-mode* values literally instead of referencing those tokens — the tokens are
/// theme-aware and would flip to their light-mode values (a dark brownish amber, a near-white bg)
/// whenever she has the app's global appearance set to light, which would break contrast on a
/// screen that stays visually dark regardless. Referencing the token here would be the bug, not
/// the literal.
///
/// La doctrine ne s'appliquait qu'à deux couleurs sur la vingtaine que l'écran pose. Tout le
/// reste — `rose2` sur « EN DIRECT » et l'allure, `textPrimary` dans la bulle du coach, `text2`
/// sous chaque métrique, `amber` de l'alerte GPS, `line` du panneau — lisait les jetons
/// thème-conscients : en mode clair, chacun basculait vers sa valeur « pour fond blanc » et se
/// retrouvait sombre sur un écran resté noir. L'accent devenait un rose foncé, le titre du coach
/// du noir sur noir. `Ink` ci-dessous fixe le registre sombre de TOUT l'écran : les accents
/// lisent `AccentTheme` directement (ils suivent le nuancier, jamais le thème), le reste est
/// littéral.
/// Les marges de l'écran, lues sur la fenêtre réelle.
///
/// Cet écran ignore les zones sûres pour que la carte aille bord à bord, et posait ensuite sa
/// marge basse à la main : 16 points. Sur tous les iPhone sans bouton d'accueil, la barre de
/// geste en occupe 34. Les trois boutons du bas — dont la pause, 70 points de diamètre — se
/// trouvaient donc à cheval sur la zone où un glissement vers le haut appartient au système :
/// une pause tapée un peu bas, en courant, essoufflée, ouvrait le sélecteur d'applications au
/// lieu d'arrêter le chrono. C'est le seul geste de l'écran qu'on fait sans regarder.
///
/// Lu sur la fenêtre plutôt que sur l'environnement : à l'intérieur d'un `ignoresSafeArea()`,
/// les encarts rapportés par la mise en page valent zéro — c'est précisément ce qu'on a demandé.
/// Le même détour existe déjà dans `StravaService` pour la même raison.
private enum ScreenEdges {
    /// 34 points de repli : la valeur des modèles sans bouton d'accueil, c'est-à-dire la grande
    /// majorité, et la seule erreur sans conséquence des deux (une marge un peu large sur un SE
    /// plutôt qu'un bouton inatteignable sur un 15).
    static var bottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom }
            .first ?? 34
    }
}

private enum Ink {
    /// L'accent de la coureuse, version fond sombre — quelle que soit l'apparence globale.
    static var accent: Color { AccentTheme.current.primary }
    static var accentSoft: Color { AccentTheme.current.light }
    static let label = Color.white.opacity(0.55)
    static let line = Color.white.opacity(0.08)
    static let cyan = Color(hex: 0x38E0D0)
    static let amber = Color(hex: 0xFFB03D)
}

struct LiveRunView: View {
    @Environment(AppState.self) private var appState
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showStopConfirm = false
    /// A throttled snapshot of `vm.location.route`, rebuilt only every 5 new GPS fixes instead of
    /// every single one — see `mapLayer`'s `.onChange` for why.
    @State private var displayedRoute: [CLLocationCoordinate2D] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Armé à l'apparition, pour que le point d'enregistrement respire. Voir `liveDot`.
    @State private var pulse = false
    @Environment(\.openURL) private var openURL
    @Environment(SubscriptionService.self) private var subscriptions

    private var vm: LiveRunViewModel? { appState.liveRun }

    var body: some View {
        ZStack {
            mapLayer
            VStack {
                topOverlay
                if let text = topBannerText {
                    coachBubble(text)
                        .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .padding(.top, 44)
            .padding(.horizontal, 18)

            VStack {
                Spacer()
                metricsPanel
            }
        }
        .background(Color(hex: 0x0A0A0E))
        .ignoresSafeArea()
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: topBannerText)
    }

    /// Voice coaching takes over the same banner scripted cues already use — a live "je
    /// t'écoute…"/transcript while listening, then the coach's real spoken reply while it plays,
    /// falling back to the scripted timestamp cues the rest of the time.
    private var topBannerText: String? {
        if let vc = vm?.voiceCoach {
            // Failures surface here too — a denied mic permission or a failed coach reply used to
            // leave the tap doing literally nothing visible.
            if vc.state == .idle, let error = vc.lastError { return "⚠️ \(error)" }
            switch vc.state {
            case .listening: return vc.partialTranscript.isEmpty ? String(localized: "Je t'écoute…") : vc.partialTranscript
            case .thinking: return "…"
            case .speaking: return vc.lastReply
            case .idle: break
            }
        }
        return vm?.coachCue
    }

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            if displayedRoute.count > 1 {
                MapPolyline(coordinates: displayedRoute)
                    .stroke(Ink.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls { }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Purely decorative for VoiceOver — distance/pace are already read from the metrics panel
        // below, so an unlabeled interactive-looking "Map" element mixed into those stops adds
        // nothing but confusion.
        .accessibilityHidden(true)
        // MapKit has no way to append one point to an existing overlay here — each update hands
        // it a brand-new coordinate array to re-tessellate from scratch. Rebuilding on every
        // single GPS fix (`vm.location.route` grows roughly once/second) means the per-update
        // cost keeps climbing as a run goes on (thousands of points over 60-90 min), on the main
        // thread, on the one screen where frame drops are most visible. Throttled to every 5 new
        // fixes (~5s) instead — the user-location dot itself (`UserAnnotation`) still updates
        // every tick since it isn't driven by this array.
        .onChange(of: vm?.location.route.count ?? 0) { _, newCount in
            let shouldUpdate = (displayedRoute.isEmpty && newCount > 1)
                || newCount - displayedRoute.count >= 5
                || newCount < displayedRoute.count
            guard shouldUpdate else { return }
            displayedRoute = vm?.location.route ?? []
        }
    }

    private var topOverlay: some View {
        HStack {
            HStack(spacing: 8) {
                FrostedBackButton { appState.go(.home) }
                HStack(spacing: 6) {
                    liveDot
                    Text(libelleEtat)
                        .font(RUFont.display(11)).tracking(2).foregroundColor(Ink.accentSoft)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Ink.accent.opacity(0.16), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
            }
            Spacer()
            // La pastille de segment vivait ici, en haut à droite, en 12 pt. Elle est maintenant
            // le surtitre du bloc de consigne, au centre et dans le regard. La garder aux deux
            // endroits afficherait « RÉP. 3/5 » deux fois sur le même écran.
        }
        .overlay(alignment: .top) {
            if let state = vm?.gpsState, state != .ok {
                gpsBanner(state)
                    .padding(.top, 48)
                    // The coach bubble right above gets a slide+fade via `topBannerText`'s
                    // animation; this sibling banner used to just pop in with no transition.
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: vm?.gpsState)
        .onChange(of: vm?.gpsState) { _, state in
            // One buzz when the signal first degrades (not per frame it stays degraded) — she's
            // mid-run and not watching the screen; the warning is useless if it arrives silently.
            // Pas pendant l'accrochage : c'est l'état normal des premières secondes de chaque
            // course, et faire vibrer le téléphone pour dire « tout se passe comme prévu » est
            // précisément ce qui apprend à ignorer les alertes.
            if state == .unstable || state == .denied { Haptics.warning() }
        }
    }

    /// Le seul mouvement perpétuel de l'écran, et le seul qui porte une information.
    ///
    /// Un écran de course ne doit rien animer pour le plaisir : on le regarde en bougeant,
    /// essoufflée, parfois sous la pluie, et tout ce qui frétille y coûte de l'attention qu'on
    /// n'a pas. Ce point-là respire parce que son battement DIT quelque chose — l'enregistrement
    /// tourne. Et il s'arrête net en pause : l'arrêt du battement est alors la deuxième preuve,
    /// non textuelle, que le chrono est bien figé — utile exactement au moment où le mot « EN
    /// PAUSE » est trop petit pour être lu en courant.
    private var liveDot: some View {
        let beating = pulse && vm?.isPaused != true && !reduceMotion
        return Circle().fill(Ink.accent).frame(width: 6, height: 6)
            .shadow(color: Ink.accent, radius: 4)
            .scaleEffect(beating ? 1.55 : 1)
            .opacity(beating ? 0.45 : 1)
            .animation(beating ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                               : RUMotion.digit,
                       value: beating)
            .onAppear { pulse = true }
            .accessibilityHidden(true)
    }

    /// Trois messages, parce qu'il y a trois situations que la coureuse doit pouvoir distinguer
    /// d'un coup d'œil — et qu'un écran muet les rendait identiques : une distance qui reste à
    /// 0,00 se lit « l'app est cassée » aussi bien quand le GPS accroche encore que quand
    /// l'autorisation a été refusée.
    @ViewBuilder
    private func gpsBanner(_ state: LiveRunViewModel.GPSState) -> some View {
        switch state {
        case .denied:
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                bannerBody(icon: "location.slash.fill",
                           text: "Localisation refusée — ouvrir les Réglages")
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
        case .searching:
            bannerBody(icon: "location.magnifyingglass",
                       text: "Recherche du signal GPS…")
        case .unstable:
            bannerBody(icon: "exclamationmark.triangle.fill",
                       text: "Signal GPS instable — position estimée")
        case .ok:
            EmptyView()
        }
    }

    private func bannerBody(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(Ink.amber).font(.system(size: 14))
            Text(text)
                .font(RUFont.sans(.body, weight: .semibold))
                .foregroundColor(Color(hex: 0xFFD79A))
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        // Surface neutre, l'ambre reste au texte. L'écran de course est toujours sombre : un
        // ambre à 16 % y donnait un brun, cerclé du même brun. Un accent n'a que deux états.
        .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
    }

    private func coachBubble(_ text: String) -> some View {
        HStack(spacing: 12) {
            Circle().fill(Ink.accent).frame(width: 34, height: 34)
                .overlay(Image(systemName: "speaker.wave.2.fill").foregroundColor(.white).font(.system(size: 13)))
            VStack(alignment: .leading, spacing: 3) {
                // Pas de `RUCardHeader` ici : son titre lit `textPrimary`, qui devient noir en
                // mode clair — sur cette bulle sombre, le nom du coach disparaissait.
                Text("Coach · en direct")
                    .font(RUFont.sans(.small, weight: .bold))
                    .foregroundColor(Ink.accentSoft)
                Text(text).font(RUFont.sans(.label)).foregroundColor(.white).lineSpacing(3)
            }
        }
        .padding(RUSpacing.cardPadding)
        .background(Color(hex: 0x0E0E14).opacity(0.85), in: RoundedRectangle(cornerRadius: RUSpacing.radiusStandard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusStandard, style: .continuous).stroke(Ink.accent.opacity(0.25), lineWidth: RUSpacing.hairline))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RUSpacing.radiusStandard, style: .continuous))
        .padding(.top, 90)
        // Speaker icon + "Coach · en direct" eyebrow + the coach line were three separate stops.
        .accessibilityElement(children: .combine)
    }

    /// Y a-t-il quelque chose à dire, à cet instant, que le chrono ne dit pas ?
    /// L'état de la séance, dans la pastille du haut.
    ///
    /// Un `switch` plutôt que le ternaire à trois étages qu'il remplace : la troisième discipline
    /// en aurait fait un à quatre, et la forme avait déjà atteint sa limite de lisibilité. Le
    /// `?? .run` évite d'avoir à filtrer un optionnel dans un `switch` sur une énumération — la
    /// course est l'état par défaut de cet écran de toute façon.
    ///
    /// La course ne se nomme pas : « EN DIRECT » seul, parce que c'est le cas ordinaire et que
    /// « COURSE · EN DIRECT » n'ajouterait rien. Les deux autres se nomment, parce que l'écran est
    /// le même et que rien d'autre, à cet endroit, ne distingue une sortie vélo d'un footing.
    private var libelleEtat: LocalizedStringKey {
        if vm?.isAutoPaused == true { return "PAUSE AUTO" }
        if vm?.isPaused == true { return "EN PAUSE" }
        switch vm?.discipline ?? .run {
        case .run: return "EN DIRECT"
        case .bike: return "VÉLO · EN DIRECT"
        case .trail: return "TRAIL · EN DIRECT"
        }
    }

    private var hasInstruction: Bool {
        // Rien à vélo : la séance du jour est une séance de course, son allure cible ne
        // s'adresse pas à quelqu'un sur une selle.
        guard vm?.suitLePlan ?? true else { return false }
        let pace = appState.profile.todaySession.pace
        return !pace.isEmpty && pace != "—" && pace != "--:--"
    }

    /// La consigne du moment : le segment en cours, et l'allure à tenir.
    ///
    /// `segmentLabel` n'existe que pour les séances dont la structure est réelle — il est piloté
    /// par la machine à états du modèle de vue, sur la distance GPS parcourue dans la répétition,
    /// pas sur un découpage supposé. Sur un footing continu il vaut nil, et le surtitre annonce
    /// simplement l'allure de la séance : c'est la seule consigne qu'il y ait, et elle vaut
    /// d'être dite.
    @ViewBuilder private var instruction: some View {
        if hasInstruction {
            VStack(spacing: 2) {
                HStack(spacing: 7) {
                    Text(vm?.segmentLabel ?? String(localized: "ALLURE CIBLE"))
                        .font(RUFont.display(11)).tracking(2)
                        .foregroundColor(Ink.accentSoft)
                    // LE RESTANT, à côté du nom du segment.
                    //
                    // L'écran annonçait « RÉP. 3/5 » et s'arrêtait là. Elle savait donc quelle
                    // répétition elle courait, et jamais s'il lui restait cinquante mètres ou
                    // quatre cents — la seule chose qu'on veuille savoir au milieu d'une
                    // répétition. Le modèle de vue l'avait sous la main depuis toujours : c'est
                    // lui qui surveille la condition de fin du segment à chaque seconde.
                    if let remaining = vm?.segmentRemainingLabel {
                        Text(verbatim: "·")
                            .font(RUFont.display(11)).foregroundColor(Ink.label)
                        Text(remaining)
                            .font(RUFont.display(11)).tracking(1)
                            .foregroundColor(.white.opacity(0.82))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(RUMotion.respecting(reduceMotion, RUMotion.digit), value: remaining)
                    }
                }
                targetPaceLine
                if let progress = vm?.segmentProgress {
                    segmentBar(progress)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibleInstruction)
        }
    }

    /// L'ALLURE CIBLE, ET QUAND ELLE EST VRAIMENT LA CONSIGNE.
    ///
    /// Pendant une répétition — ou pendant toute une séance continue — l'allure du jour EST ce
    /// qu'elle doit faire maintenant : gros, en accent, c'est la première chose lue de l'écran.
    ///
    /// Pendant l'échauffement, la récupération et le retour au calme, non : ces segments sont
    /// volontairement hors allure cible, et l'écran affichait pourtant « ÉCHAUFFEMENT » suivi de
    /// l'allure des répétitions dans le même accent — soit, lu à bout de souffle, la consigne de
    /// courir son échauffement à l'allure de son travail. Le chiffre reste, parce qu'il est utile
    /// de savoir vers quoi on s'échauffe ; il perd l'accent et gagne le mot CIBLE. Même place,
    /// même taille, aucun saut de mise en page toutes les quatre-vingt-dix secondes : l'accent
    /// seul dit « c'est maintenant ».
    @ViewBuilder private var targetPaceLine: some View {
        let pace = appState.profile.todaySession.pace
        if vm?.isTargetEffortNow ?? true {
            Text(verbatim: "\(pace)/km")
                .displayStyle(34)
                .foregroundColor(Ink.accent)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("CIBLE")
                    .font(RUFont.display(11)).tracking(2)
                    .foregroundColor(Ink.label)
                Text(verbatim: "\(pace)/km")
                    .displayStyle(34)
                    .foregroundColor(.white.opacity(0.45))
            }
        }
    }

    /// Ce que la consigne dit à voix haute, à la lettre — y compris le segment et son restant,
    /// que l'étiquette précédente passait sous silence alors qu'ils sont à l'écran.
    private var accessibleInstruction: String {
        let pace = appState.profile.todaySession.pace
        guard let segment = vm?.segmentLabel else {
            return String(localized: "Consigne, allure cible \(pace) par kilomètre")
        }
        // « allure cible » quand c'est la consigne de l'instant, « cible » quand ce n'est que
        // l'objectif de la séance — la même distinction que l'accent fait à l'écran, qui ne se
        // voit pas quand on écoute.
        let effort = vm?.isTargetEffortNow ?? true
        guard let remaining = vm?.segmentRemainingLabel else {
            return effort
                ? String(localized: "\(segment), allure cible \(pace) par kilomètre")
                : String(localized: "\(segment), cible \(pace) par kilomètre")
        }
        return effort
            ? String(localized: "\(segment), reste \(remaining), allure cible \(pace) par kilomètre")
            : String(localized: "\(segment), reste \(remaining), cible \(pace) par kilomètre")
    }

    /// La progression dans le segment en cours.
    ///
    /// Quatre points de haut et rien d'autre : sur cet écran, une barre est déjà le plus de
    /// détail qu'on puisse se permettre. Masquée à VoiceOver — l'étiquette de la consigne
    /// au-dessus énonce déjà le restant, en toutes lettres et avec son unité, ce qu'une barre ne
    /// saurait pas faire.
    private func segmentBar(_ progress: Double) -> some View {
        Capsule().fill(Color.white.opacity(0.12))
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule().fill(Ink.accent)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(maxWidth: 220)
            .padding(.top, 8)
            .animation(RUMotion.respecting(reduceMotion, RUMotion.glide), value: progress)
            .accessibilityHidden(true)
    }

    private var metricsPanel: some View {
        VStack(spacing: 14) {
            // LA CONSIGNE D'ABORD, le chronomètre ensuite.
            //
            // Le chrono occupait le plus grand corps de l'écran — et c'est le chiffre le moins
            // coaché de tous : une montre à vingt euros le donne. Ce qu'une app de coaching a de
            // plus à dire, c'est quoi faire maintenant. Sur une séance à répétitions, cette
            // consigne changeait toutes les quatre-vingt-dix secondes et vivait dans une pastille
            // de 12 pt, en haut à droite, hors du regard de quelqu'un qui court.
            //
            // Elle monte donc au-dessus du chrono, avec le segment en surtitre et l'allure visée
            // en gros. Le chrono descend de 64 à 52 : il reste le plus grand chiffre de l'écran —
            // c'est lui qui structure l'effort — mais il cesse d'être la première chose lue.
            //
            // Rien n'est inventé quand il n'y a rien à dire : sans allure cible au plan (HYROX,
            // course libre), le bloc disparaît et le chrono retrouve ses 64 pt.
            instruction

            VStack(spacing: 0) {
                // LES CHIFFRES ROULENT, ILS NE SAUTENT PAS.
                //
                // `monospacedDigit` d'abord, et c'est le plus important des deux : avec des
                // chiffres de largeurs différentes, un chrono de 52 points se décale
                // horizontalement à chaque seconde — un tremblement permanent au centre de
                // l'écran, sur le seul objet qu'on fixe en courant. La transition numérique
                // ensuite, qui fait glisser le seul chiffre qui change au lieu de remplacer la
                // ligne entière.
                Text(PaceModel.formatDuration(vm?.elapsedSeconds ?? 0))
                    .displayStyle(hasInstruction ? 52 : 64).foregroundColor(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(RUMotion.respecting(reduceMotion, RUMotion.digit), value: Int(vm?.elapsedSeconds ?? 0))
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(String(format: "%.2f", locale: Locale.current, vm?.distanceKm ?? 0))
                        .displayStyle(26).foregroundColor(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(RUMotion.respecting(reduceMotion, RUMotion.digit), value: vm?.distanceKm ?? 0)
                    Text(verbatim: "KM")
                        .font(RUFont.sans(.micro, weight: .bold)).tracking(1.5)
                        .foregroundColor(Ink.label)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Temps \(PaceModel.formatDuration(vm?.elapsedSeconds ?? 0)), distance \(String(format: "%.2f", locale: Locale.current, vm?.distanceKm ?? 0)) kilomètres"))

            HStack(spacing: 10) {
                paceMetric
                // No live sensor stream means no real reading — "--" rather than a fabricated
                // number (was a fake sine-wave formula dressed up as a live measurement).
                liveMetric(
                    vm?.heartRate.map { "\($0)" } ?? "--",
                    String(localized: "FC · \(appState.profile.todaySession.zone)"),
                    Ink.accent
                )
                // `liveMetric` rend son libellé par un `Text(String)` nu — mais « KCAL » est un
                // symbole, il ne se traduit pas.
                liveMetric("\(Int(vm?.kcal ?? 0))", "KCAL", Ink.cyan)
            }

            HStack(spacing: 16) {
                Button(action: {
                    Haptics.impact(.heavy)
                    showStopConfirm = true
                }) {
                    Text("STOP").displayStyle(11).tracking(1).foregroundColor(.white)
                }
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.08), in: Circle())
                .buttonStyle(PressableStyle())
                // A 52pt button right next to pause used to end the workout irreversibly on a
                // single tap — one mid-run mis-tap killed the session.
                .confirmationDialog("Terminer la course ?", isPresented: $showStopConfirm, titleVisibility: .visible) {
                    Button("Terminer", role: .destructive) { _ = appState.endLiveRun() }
                    Button("Continuer à courir", role: .cancel) {}
                }

                Button(action: {
                    Haptics.impact(.medium)
                    vm?.togglePause()
                }) {
                    Image(systemName: vm?.isPaused == true ? "play.fill" : "pause.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: 0x0A0A0A))
                }
                .frame(width: 70, height: 70)
                .background(.white, in: Circle())
                .buttonStyle(PressableStyle())
                .accessibilityLabel(vm?.isPaused == true ? "Reprendre" : "Mettre en pause")

                voiceCoachButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        // Le fond du panneau descend jusqu'au bord physique de l'écran — c'est son dégradé qui
        // ferme l'image. Son CONTENU, lui, s'arrête au-dessus de la barre de geste : voir
        // `ScreenEdges`. Le plancher à 16 garde la marge d'origine sur les modèles à bouton
        // d'accueil, où l'encart vaut zéro.
        .padding(.bottom, max(16, ScreenEdges.bottom + 8))
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: 0x0E0E14).opacity(0.6), Color(hex: 0x0E0E14, opacity: 1)], startPoint: .top, endPoint: .bottom)
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedCornerShape(radius: 26, corners: [.topLeft, .topRight]))
        .overlay(RoundedCornerShape(radius: 26, corners: [.topLeft, .topRight]).stroke(Ink.line, lineWidth: RUSpacing.hairline))
    }

    /// Was a purely decorative lock icon with no `Button`/action at all — replaced with the real
    /// tap-to-talk voice coach control (see `VoiceCoachController`): tap to ask a question out
    /// loud, tap again to stop and send, hear a real spoken reply.
    private var voiceCoachButton: some View {
        let state = vm?.voiceCoach?.state ?? .idle
        // Verrouillé, le bouton reste à sa place, avec son micro et un petit cadenas. Le retirer
        // serait la seule option qui n'apprend rien : on ne peut pas vouloir ce qu'on n'a jamais
        // vu. Et en pleine course, un bouton est la seule forme qu'un verrou puisse prendre —
        // aucune carte d'argumentaire n'a sa place sur cet écran-là.
        let locked = !subscriptions.unlocks(.voiceCoach)
        return Button(action: {
            if locked { appState.plusPrompt = .voiceCoach } else { handleMicTap() }
        }) {
            ZStack {
                Circle().fill(Ink.accent.opacity(state == .listening ? 0.35 : 0.15))
                Circle().strokeBorder(Ink.accent.opacity(state == .listening ? 0.6 : 0.3), lineWidth: RUSpacing.hairline)
                switch state {
                case .idle:
                    Image(systemName: "mic.fill").foregroundColor(Ink.accentSoft).font(.system(size: 15))
                case .listening:
                    Image(systemName: "waveform").foregroundColor(Ink.accentSoft).font(.system(size: 15))
                case .thinking:
                    ProgressView().tint(Ink.accentSoft)
                case .speaking:
                    Image(systemName: "speaker.wave.2.fill").foregroundColor(Ink.accentSoft).font(.system(size: 15))
                }
            }
            .frame(width: 52, height: 52)
            .overlay(alignment: .bottomTrailing) {
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Ink.accentSoft)
                        .padding(4)
                        .background(Color(hex: 0x0E0E14).opacity(0.85), in: Circle())
                }
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(!locked && (state == .thinking || state == .speaking))
        .accessibilityLabel(locked ? "Le coach vocal fait partie de RUNUP Plus"
                                   : (state == .listening ? "Arrêter et envoyer" : "Parler au coach"))
    }

    private func handleMicTap() {
        guard let voiceCoach = vm?.voiceCoach else { return }
        Task {
            if voiceCoach.state == .idle {
                guard await voiceCoach.requestAuthorization() else {
                    voiceCoach.reportAuthorizationDenied()
                    return
                }
            }
            voiceCoach.toggle()
        }
    }

    /// L'ALLURE, ET CE QU'ELLE VAUT.
    ///
    /// Deux changements sur une seule case, et c'est la case la plus regardée de l'écran.
    ///
    /// Le chiffre, d'abord : c'était la moyenne de toute la sortie. Passé la vingtième minute,
    /// elle ne bouge plus que de quelques secondes même quand la coureuse change franchement de
    /// rythme — autrement dit, le seul nombre censé lui dire comment elle court maintenant ne le
    /// disait plus. C'est l'allure des trente dernières secondes qui s'affiche désormais : la
    /// seule qu'elle puisse corriger. La moyenne garde sa place au récap, où elle décrit une
    /// course finie.
    ///
    /// Le libellé, ensuite. Tant qu'elle tient la cible, il dit ALLURE et rien ne change. Dès
    /// qu'elle s'en écarte de plus que la tolérance, il devient le verbe que le coach prononce au
    /// même instant — ACCÉLÈRE, RALENTIS — et passe à l'ambre avec le chiffre.
    ///
    /// Un mot plutôt qu'une flèche, et un mot plutôt que la couleur seule : la couleur ne se lit
    /// pas pour tout le monde, et elle ne se lit pour personne à bout de souffle avec le soleil
    /// dessus. C'est aussi le même mot que la voix, lue sur la même fenêtre et la même tolérance
    /// — l'écran et le coach ne peuvent plus se contredire.
    private var paceMetric: some View {
        let standing = vm?.paceStanding ?? .unknown
        let drift: Bool = standing == .tooSlow || standing == .tooFast
        let label: String
        switch standing {
        case .tooSlow: label = String(localized: "ACCÉLÈRE")
        case .tooFast: label = String(localized: "RALENTIS")
        case .onTarget, .unknown: label = vm?.rythmeLibelle ?? String(localized: "ALLURE")
        }
        let value = vm?.rythmeRecent ?? "--:--"
        // Pas le libellé affiché : « Allure 8:32 par kilomètre, ALLURE » est ce que donnerait sa
        // reprise telle quelle.
        let spoken: String
        switch standing {
        case .tooSlow: spoken = String(localized: "Allure \(value) par kilomètre, accélère")
        case .tooFast: spoken = String(localized: "Allure \(value) par kilomètre, ralentis")
        case .onTarget, .unknown:
            spoken = vm?.discipline.seLitEnAllure ?? true
                ? String(localized: "Allure \(value) par kilomètre")
                : String(localized: "Vitesse \(value) kilomètres par heure")
        }
        return VStack(spacing: 2) {
            Text(value).displayStyle(26)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(RUMotion.respecting(reduceMotion, RUMotion.digit), value: value)
                .foregroundColor(drift ? Ink.amber : Ink.accentSoft)
            Text(label)
                .font(RUFont.sans(.micro, weight: .bold)).tracking(1.5)
                .foregroundColor(drift ? Ink.amber : Ink.label)
        }
        .frame(maxWidth: .infinity)
        .animation(RUMotion.respecting(reduceMotion, RUMotion.snap), value: drift)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spoken)
    }

    private func liveMetric(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).displayStyle(26).foregroundColor(color)
            Text(label).font(RUFont.sans(.micro, weight: .bold)).tracking(1.5).foregroundColor(Ink.label)
        }
        .frame(maxWidth: .infinity)
        // The screen most glanced at mid-run — was two separate stops ("8:32" then, later,
        // "ALLURE") with no indication which number belonged to which label.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }
}

/// Rounded-corner shape for a top-only radius (metrics panel).
struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}
