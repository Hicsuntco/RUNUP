import Foundation

/// Captures the code from a tapped referral link (`https://runup-nu.vercel.app/r/CODE` — a
/// universal link if the app is installed, see `public/.well-known/apple-app-site-association` and
/// the `com.apple.developer.associated-domains` entitlement in `project.yml`) and hands it to
/// `SignInView` the next time she opens it, so creating an account there needs no manually typing
/// the code a friend sent her. Stored in `UserDefaults` rather than only in memory: `.onOpenURL`
/// can fire before `AppState` exists yet on a cold launch, and this way whoever reads the pending
/// code later doesn't need a live reference passed through at the exact right moment.
enum ReferralLinkHandler {
    private static let defaultsKey = "runup.pending-referral-code"

    static func handle(_ url: URL) {
        guard let code = referralCode(from: url) else { return }
        UserDefaults.standard.set(code, forKey: defaultsKey)
    }

    /// `/r/CODE` in either a universal link (`https://…/r/CODE`) or the `runup://r/CODE` custom
    /// scheme — Foundation parses the two differently even though they look the same: a
    /// `scheme://host/path` URL puts "r" in `.host`, not in `.pathComponents`, so the universal
    /// link's `parts[0] == "r"` check never matches a custom-scheme link at all.
    private static func referralCode(from url: URL) -> String? {
        if url.host == "r" {
            let code = url.pathComponents.filter { $0 != "/" }.first
            guard let code, !code.isEmpty else { return nil }
            return code.uppercased()
        }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2, parts[0] == "r", !parts[1].isEmpty else { return nil }
        return parts[1].uppercased()
    }

    static var pendingCode: String? {
        UserDefaults.standard.string(forKey: defaultsKey)
    }

    /// Call once the code has actually been submitted in a sign-in/sign-up request — whether or
    /// not the account creation itself succeeds, there's no reason to keep re-offering the same
    /// stale code on a later, unrelated sign-in.
    static func clearPendingCode() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}
