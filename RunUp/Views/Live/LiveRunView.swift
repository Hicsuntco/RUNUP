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
                if let cue = vm?.coachCue {
                    coachBubble(cue)
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
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: vm?.coachCue)
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
            Text("Interv. \(vm?.intervalIndex ?? 1)/6")
                .font(RUFont.bebas(12))
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.black.opacity(0.4), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
        }
        .overlay(alignment: .top) {
            if vm?.isSignalUnstable == true {
                gpsWarningBanner
                    .padding(.top, 48)
            }
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
                Text(AdaptivePlanEngine.fmt(vm?.elapsedSeconds ?? 0)).displayStyle(64).foregroundColor(.white)
                EyebrowLabel(text: "Temps · \(String(format: "%.2f", vm?.distanceKm ?? 0)) km")
            }

            HStack(spacing: 10) {
                liveMetric(vm?.paceLabel ?? "--:--", "ALLURE", RUColor.rose2)
                liveMetric("\(vm?.heartRate ?? 0)", "FC · Z4", RUColor.rose)
                liveMetric("\(Int(vm?.kcal ?? 0))", "KCAL", RUColor.cyan)
            }

            HStack(spacing: 16) {
                Button(action: { _ = appState.endLiveRun() }) {
                    Text("STOP").displayStyle(11).tracking(1).foregroundColor(.white)
                }
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.08), in: Circle())
                .buttonStyle(PressableStyle())

                Button(action: { vm?.togglePause() }) {
                    Image(systemName: vm?.isPaused == true ? "play.fill" : "pause.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: 0x0A0A0A))
                }
                .frame(width: 70, height: 70)
                .background(.white, in: Circle())
                .buttonStyle(PressableStyle())

                ZStack {
                    Circle().fill(RUColor.rose.opacity(0.15))
                    Circle().strokeBorder(RUColor.rose.opacity(0.3), lineWidth: RUSpacing.hairline)
                    Image(systemName: "lock.fill").foregroundColor(RUColor.rose2).font(.system(size: 15))
                }
                .frame(width: 52, height: 52)
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
