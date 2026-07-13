import SwiftUI

/// App-wide toast pill (white bg / dark text, bottom-center, ~2.2s auto-dismiss).
@Observable
final class ToastCenter {
    private(set) var message: String?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.message = message
        }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) { self?.message = nil }
            }
        }
    }
}

/// Overlays the current toast message, positioned above the floating tab bar.
struct ToastHost: ViewModifier {
    var toastCenter: ToastCenter

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message = toastCenter.message {
                Text(message)
                    .font(RUFont.sans(13, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.white, in: Capsule())
                    .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
                    .padding(.bottom, RUSpacing.tabBarBottomInset + RUSpacing.tabBarHeight + 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toastCenter.message)
    }
}

extension View {
    func toastHost(_ toastCenter: ToastCenter) -> some View {
        modifier(ToastHost(toastCenter: toastCenter))
    }
}
