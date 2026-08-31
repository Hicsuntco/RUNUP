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
                    Circle().fill(Ink.accent).frame(width: 6, height: 6)
                        .shadow(color: Ink.accent, radius: 4)
                    Text(vm?.isAutoPaused == true ? "PAUSE AUTO" : (vm?.isPaused == true ? "EN PAUSE" : "EN DIRECT"))
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
        .background(Ink.amber.opacity(0.16), in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(Ink.amber.opacity(0.4), lineWidth: RUSpacing.hairline))
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
        .padding(14)
        .background(Color(hex: 0x0E0E14).opacity(0.85), in: RoundedRectangle(cornerRadius: RUSpacing.radiusStandard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusStandard, style: .continuous).stroke(Ink.accent.opacity(0.25), lineWidth: RUSpacing.hairline))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RUSpacing.radiusStandard, style: .continuous))
        .padding(.top, 90)
        // Speaker icon + "Coach · en direct" eyebrow + the coach line were three separate stops.
        .accessibilityElement(children: .combine)
    }

    /// Y a-t-il quelque chose à dire, à cet instant, que le chrono ne dit pas ?
    private var hasInstruction: Bool {
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
                Text(vm?.segmentLabel ?? String(localized: "ALLURE CIBLE"))
                    .font(RUFont.display(11)).tracking(2)
                    .foregroundColor(Ink.accentSoft)
                Text(verbatim: "\(appState.profile.todaySession.pace)/km")
                    .displayStyle(34)
                    .foregroundColor(Ink.accent)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Consigne, allure cible \(appState.profile.todaySession.pace) par kilomètre"))
        }
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
                Text(PaceModel.formatDuration(vm?.elapsedSeconds ?? 0))
                    .displayStyle(hasInstruction ? 52 : 64).foregroundColor(.white)
                HStack(alignment: .lastTextBaseline, spacing: 5) {
                    Text(String(format: "%.2f", locale: Locale.current, vm?.distanceKm ?? 0))
                        .displayStyle(26).foregroundColor(.white)
                    Text(verbatim: "KM")
                        .font(RUFont.sans(.micro, weight: .bold)).tracking(1.5)
                        .foregroundColor(Ink.label)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "Temps \(PaceModel.formatDuration(vm?.elapsedSeconds ?? 0)), distance \(String(format: "%.2f", locale: Locale.current, vm?.distanceKm ?? 0)) kilomètres"))

            HStack(spacing: 10) {
                // `liveMetric` rend son libellé par un `Text(String)` nu — d'où le
                // `String(localized:)` explicite ici. « KCAL » est un symbole, il ne bouge pas.
                liveMetric(vm?.paceLabel ?? "--:--", String(localized: "ALLURE"), Ink.accentSoft)
                // No live sensor stream means no real reading — "--" rather than a fabricated
                // number (was a fake sine-wave formula dressed up as a live measurement).
                liveMetric(
                    vm?.heartRate.map { "\($0)" } ?? "--",
                    String(localized: "FC · \(appState.profile.todaySession.zone)"),
                    Ink.accent
                )
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
        .padding(.bottom, 16)
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
