import SwiftUI

/// App-wide toast pill (bottom-center, ~2.2s auto-dismiss).
///
/// `@MainActor` parce que tout ce que fait cette classe est de l'interface : `withAnimation`,
/// une annonce VoiceOver, et une propriété que SwiftUI observe. Sans l'annotation, la tâche de
/// disparition ci-dessous capture une classe non-`Sendable` dans du code concurrent — un
/// avertissement aujourd'hui, une erreur en Swift 6, et une vraie course de données entre
/// l'écriture différée et la lecture par la vue.
@MainActor
@Observable
final class ToastCenter {
    private(set) var message: String?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.message = message
        }
        // Un texte non focalisable qui apparaît puis disparaît n'est JAMAIS lu par VoiceOver.
        // Les 39 messages de l'app passaient donc entièrement à la trappe, y compris ceux qui
        // n'ont aucun autre canal : « Kudos non envoyé », « Impossible de suivre cette
        // personne », « Connexion à Apple Santé impossible ». On tapait un bouton, rien ne se
        // passait, et rien ne disait pourquoi.
        AccessibilityNotification.Announcement(message).post()
        // Plus de `await MainActor.run` : une `Task` créée depuis un contexte `@MainActor` hérite
        // de son isolation, donc le corps s'exécute déjà sur le fil principal.
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { self?.message = nil }
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
                    // Hardcoded dark-on-light regardless of theme, deliberately — it's a
                    // transient overlay that floats above arbitrary content in EITHER theme, and
                    // `RUColor.bg` is pure white in light mode (`Colors.swift:13`), so a
                    // theme-matched pill rendered a white toast on a white screen (see full-app
                    // audit finding). A fixed high-contrast pill is the same pattern iOS's own
                    // system toasts use.
                    .foregroundColor(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.white, in: Capsule())
                    .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: RUSpacing.hairline))
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
