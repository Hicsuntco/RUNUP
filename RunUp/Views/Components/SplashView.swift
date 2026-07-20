import SwiftUI

/// A brief in-app splash on cold launch — the wordmark in white on RunUp's near-black background,
/// same idea as Strava's launch flash. The OS-drawn launch screen (`UILaunchScreen` in
/// project.yml) can only ever show a static color — this is the real animated version, shown once
/// app code is actually running, layered over `ContentRouterView` while it fades out.
struct SplashView: View {
    var onFinished: () -> Void

    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.94

    var body: some View {
        ZStack {
            RUColor.bg.ignoresSafeArea()
            Text("RUNUP")
                .font(RUFont.bebas(40))
                .tracking(7)
                .foregroundColor(RUColor.textPrimary)
                .opacity(opacity)
                .scaleEffect(scale)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                opacity = 1
                scale = 1
            }
            Task {
                try? await Task.sleep(for: .milliseconds(850))
                withAnimation(.easeIn(duration: 0.3)) { opacity = 0 }
                try? await Task.sleep(for: .milliseconds(300))
                onFinished()
            }
        }
    }
}
