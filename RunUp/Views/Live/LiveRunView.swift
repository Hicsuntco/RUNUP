import SwiftUI
import MapKit
import UIKit

/// Live run tracking — real MapKit + CoreLocation route, coach voice cues, and a GPS-instability
/// banner driven by actual signal accuracy. Mirrors `LiveScreen` in screensA.jsx, with a real map
/// in place of the prototype's stylized SVG route (see architecture decision).
struct LiveRunView: View {
    @Environment(AppState.self) private var appState
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    private var vm: LiveRunViewModel? { appState.liveRun }

    var body: some View {
        ZStack {
            mapLayer
            VStack {
                topOverlay
                if let text = topBannerText {
                    coachBubble(text)
                        .transition(.move(edge: .top).combined(with: .opacity))
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
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: topBannerText)
    }

    /// Voice coaching takes over the same banner scripted cues already use — a live "je
    /// t'écoute…"/transcript while listening, then the coach's real spoken reply while it plays,
    /// falling back to the scripted timestamp cues the rest of the time.
    private var topBannerText: String? {
        if let vc = vm?.voiceCoach {
            switch vc.state {
            case .listening: return vc.partialTranscript.isEmpty ? "Je t'écoute…" : vc.partialTranscript
            case .thinking: return "…"
            case .speaking: return vc.lastReply
            case .idle: break
            }
        }
        return vm?.coachCue
    }

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            if let vm, vm.location.route.count > 1 {
                MapPolyline(coordinates: vm.location.route)
                    .stroke(RUColor.rose, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls { }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topOverlay: some View {
        HStack {
            HStack(spacing: 8) {
                FrostedBackButton { appState.go(.home) }
                HStack(spacing: 6) {
                    Circle().fill(RUColor.rose).frame(width: 6, height: 6)
                        .shadow(color: RUColor.rose, radius: 4)
                    Text(vm?.isPaused == true ? "EN PAUSE" : "EN DIRECT")
                        .font(RUFont.bebas(11)).tracking(2).foregroundColor(RUColor.rose2)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(RUColor.rose.opacity(0.16), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
            }
            Spacer()
            if vm?.isIntervalSession == true {
                Text("Interv. \(vm?.intervalIndex ?? 1)/6")
                    .font(RUFont.bebas(12))
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
    }

    private var metricsPanel: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(PaceModel.formatDuration(vm?.elapsedSeconds ?? 0)).displayStyle(64).foregroundColor(.white)
                EyebrowLabel(text: "Temps · \(String(format: "%.2f", vm?.distanceKm ?? 0)) km")
            }

            HStack(spacing: 10) {
                liveMetric(vm?.paceLabel ?? "--:--", "ALLURE", RUColor.rose2)
                // No live sensor stream means no real reading — "--" rather than a fabricated
                // number (was a fake sine-wave formula dressed up as a live measurement).
                liveMetric(
                    vm?.heartRate.map { "\($0)" } ?? "--",
                    "FC · \(appState.profile.todaySession.zone)",
                    RUColor.rose
                )
                liveMetric("\(Int(vm?.kcal ?? 0))", "KCAL", RUColor.cyan)
            }

            HStack(spacing: 16) {
                Button(action: {
                    Haptics.impact(.heavy)
                    _ = appState.endLiveRun()
                }) {
                    Text("STOP").displayStyle(11).tracking(1).foregroundColor(.white)
                }
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.08), in: Circle())
                .buttonStyle(PressableStyle())

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
    }

    private func handleMicTap() {
        guard let voiceCoach = vm?.voiceCoach else { return }
        Task {
            if voiceCoach.state == .idle {
                guard await voiceCoach.requestAuthorization() else { return }
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
