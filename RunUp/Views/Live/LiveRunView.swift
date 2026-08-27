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
struct LiveRunView: View {
    @Environment(AppState.self) private var appState
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showStopConfirm = false
    /// A throttled snapshot of `vm.location.route`, rebuilt only every 5 new GPS fixes instead of
    /// every single one — see `mapLayer`'s `.onChange` for why.
    @State private var displayedRoute: [CLLocationCoordinate2D] = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    .stroke(RUColor.rose, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
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
                    Circle().fill(RUColor.rose).frame(width: 6, height: 6)
                        .shadow(color: RUColor.rose.opacity(RUColor.isLight ? 0 : 1), radius: 4)
                    Text(vm?.isAutoPaused == true ? "PAUSE AUTO" : (vm?.isPaused == true ? "EN PAUSE" : "EN DIRECT"))
                        .font(RUFont.display(11)).tracking(2).foregroundColor(RUColor.rose2)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(RUColor.rose.opacity(0.16), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
            }
            Spacer()
            // Only when the session's own title declares a real rep structure ("5 × 500 m") —
            // driven by `LiveRunViewModel`'s real segment state machine (actual GPS distance per
            // rep, actual elapsed recovery time), not a guessed flat-distance chunk.
            if let label = vm?.segmentLabel {
                Text(label)
                    .font(RUFont.display(12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.black.opacity(0.4), in: Capsule())
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .overlay(alignment: .top) {
            if vm?.isSignalUnstable == true {
                gpsWarningBanner
                    .padding(.top, 48)
                    // The coach bubble right above gets a slide+fade via `topBannerText`'s
                    // animation; this sibling banner used to just pop in with no transition.
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: vm?.isSignalUnstable == true)
        .onChange(of: vm?.isSignalUnstable == true) { _, unstable in
            // One buzz when the signal first degrades (not per frame it stays degraded) — she's
            // mid-run and not watching the screen; the warning is useless if it arrives silently.
            if unstable { Haptics.warning() }
        }
    }

    private var gpsWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(RUColor.amber).font(.system(size: 14))
            Text("Signal GPS instable — position estimée")
                .font(RUFont.sans(11.5, weight: .semibold))
                .foregroundColor(Color(hex: 0xFFD79A))
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(RUColor.amber.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.amber.opacity(0.4), lineWidth: RUSpacing.hairline))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func coachBubble(_ text: String) -> some View {
        HStack(spacing: 12) {
            Circle().fill(RUColor.rose).frame(width: 34, height: 34)
                .overlay(Image(systemName: "speaker.wave.2.fill").foregroundColor(.white).font(.system(size: 13)))
            VStack(alignment: .leading, spacing: 3) {
                EyebrowLabel(text: "Coach · en direct", color: RUColor.rose2)
                Text(text).font(RUFont.sans(12.5)).foregroundColor(.white).lineSpacing(3)
            }
        }
        .padding(14)
        .background(Color(hex: 0x0E0E14).opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(RUColor.rose.opacity(0.25), lineWidth: RUSpacing.hairline))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.top, 90)
        // Speaker icon + "Coach · en direct" eyebrow + the coach line were three separate stops.
        .accessibilityElement(children: .combine)
    }

    private var metricsPanel: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(PaceModel.formatDuration(vm?.elapsedSeconds ?? 0)).displayStyle(64).foregroundColor(.white)
                EyebrowLabel(text: String(localized: "Temps · \(String(format: "%.2f", locale: Locale.current, vm?.distanceKm ?? 0)) km"))
            }

            HStack(spacing: 10) {
                // `liveMetric` rend son libellé par un `Text(String)` nu — d'où le
                // `String(localized:)` explicite ici. « KCAL » est un symbole, il ne bouge pas.
                liveMetric(vm?.paceLabel ?? "--:--", String(localized: "ALLURE"), RUColor.rose2)
                // No live sensor stream means no real reading — "--" rather than a fabricated
                // number (was a fake sine-wave formula dressed up as a live measurement).
                liveMetric(
                    vm?.heartRate.map { "\($0)" } ?? "--",
                    String(localized: "FC · \(appState.profile.todaySession.zone)"),
                    RUColor.rose
                )
                liveMetric("\(Int(vm?.kcal ?? 0))", "KCAL", RUColor.cyan)
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
        .overlay(RoundedCornerShape(radius: 26, corners: [.topLeft, .topRight]).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    /// Was a purely decorative lock icon with no `Button`/action at all — replaced with the real
    /// tap-to-talk voice coach control (see `VoiceCoachController`): tap to ask a question out
    /// loud, tap again to stop and send, hear a real spoken reply.
    private var voiceCoachButton: some View {
        let state = vm?.voiceCoach?.state ?? .idle
        return Button(action: handleMicTap) {
            ZStack {
                Circle().fill(RUColor.rose.opacity(state == .listening ? 0.35 : 0.15))
                Circle().strokeBorder(RUColor.rose.opacity(state == .listening ? 0.6 : 0.3), lineWidth: RUSpacing.hairline)
                switch state {
                case .idle:
                    Image(systemName: "mic.fill").foregroundColor(RUColor.rose2).font(.system(size: 15))
                case .listening:
                    Image(systemName: "waveform").foregroundColor(RUColor.rose2).font(.system(size: 15))
                case .thinking:
                    ProgressView().tint(RUColor.rose2)
                case .speaking:
                    Image(systemName: "speaker.wave.2.fill").foregroundColor(RUColor.rose2).font(.system(size: 15))
                }
            }
            .frame(width: 52, height: 52)
        }
        .buttonStyle(PressableStyle())
        .disabled(state == .thinking || state == .speaking)
        .accessibilityLabel(state == .listening ? "Arrêter et envoyer" : "Parler au coach")
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
            Text(label).font(RUFont.sans(8, weight: .bold)).tracking(1.5).foregroundColor(RUColor.text2)
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
