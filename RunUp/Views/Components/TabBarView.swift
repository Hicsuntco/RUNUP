import SwiftUI

/// Floating frosted-glass tab bar with a raised center "Run" button. See README § Global Chrome.
struct TabBarView: View {
    var selected: AppScreen
    var onSelect: (AppScreen) -> Void
    var onStartRun: () -> Void

    private let items: [(AppScreen, String, String)] = [
        (.home, "Prog", "list.bullet"),
        (.coach, "Coach", "bubble.left.and.bubble.right"),
        (.stats, "Stats", "chart.bar"),
        (.club, "Club", "person.2")
    ]

    var body: some View {
        HStack(spacing: 0) {
            tabButton(items[0])
            tabButton(items[1])
            runButton
            tabButton(items[2])
            tabButton(items[3])
        }
        .padding(.horizontal, 6)
        .frame(height: RUSpacing.tabBarHeight)
        .background(.ultraThinMaterial.opacity(0.9))
        // Was a fixed dark-navy tint regardless of theme — fine when the whole app was always
        // dark, but a heavy near-black pill floating on a white page in light mode reads as a
        // grey smudge rather than the same frosted-glass chrome the dark theme gets.
        .background(RUColor.isLight ? Color(hex: 0xEDEDF4).opacity(0.92) : Color(hex: 0x12121A).opacity(0.72))
        .overlay(
            Capsule().stroke(RUColor.isLight ? Color.black.opacity(0.13) : Color.white.opacity(0.09), lineWidth: RUSpacing.hairline)
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(RUColor.isLight ? 0.30 : 0.5), radius: 24, x: 0, y: 13)
    }

    private func tabButton(_ item: (AppScreen, String, String)) -> some View {
        let (screen, label, icon) = item
        let on = selected == screen
        let color = on ? RUColor.rose2 : (RUColor.isLight ? Color.black.opacity(0.32) : Color.white.opacity(0.4))
        return Button(action: {
            Haptics.selection()
            onSelect(screen)
        }) {
            VStack(spacing: 5) {
                Circle()
                    .fill(RUColor.rose)
                    .frame(width: 4, height: 4)
                    .opacity(on ? 1 : 0)
                    .scaleEffect(on ? 1 : 0.3)
                    // Snapped on/off before this — RootTabView already animates the screen swap
                    // itself (`.animation(.easeInOut(duration: 0.25), value: appState.screen)`),
                    // but the selection dot one layer down didn't match that with its own.
                    .animation(.easeOut(duration: 0.2), value: on)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: on ? .semibold : .regular))
                    .foregroundColor(color)
                Text(label)
                    .font(RUFont.sans(8, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableStyle())
    }

    private var runButton: some View {
        Button(action: onStartRun) {
            VStack(spacing: 4) {
                Circle()
                    .fill(LinearGradient(colors: [RUColor.rose2, RUColor.rose], startPoint: .top, endPoint: .bottom))
                    .frame(width: 50, height: 50)
                    .overlay(Image(systemName: "play.fill").foregroundColor(.white).font(.system(size: 16)))
                    .shadow(color: RUColor.rose.opacity(0.55), radius: 14, x: 0, y: 6)
                Text("RUN")
                    .font(RUFont.sans(8, weight: .bold))
                    .tracking(1)
                    .foregroundColor(RUColor.rose2)
            }
            .frame(width: 60)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Floating pill shown above the tab bar when a run is active but the user navigated away.
struct RunInProgressPill: View {
    var elapsed: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle().fill(.white).frame(width: 7, height: 7)
                Text("RUN EN COURS · \(elapsed)")
                    .font(RUFont.bebas(12))
                    .tracking(1)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(RUColor.rose, in: Capsule())
            .shadow(color: RUColor.rose.opacity(0.5), radius: 20, x: 0, y: 10)
        }
        .buttonStyle(PressableStyle())
    }
}
