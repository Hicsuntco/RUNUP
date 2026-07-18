import SwiftUI
import AuthenticationServices

/// Sign-in sheet, presented only from `ClubView` — the rest of the app works fully offline, an
/// account is only needed for the real, server-backed Club (leaderboard/feed/kudos). Offers Sign
/// in with Apple plus email/password, so nobody needs to create yet another password if they'd
/// rather not.
struct SignInView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private enum Mode { case signIn, signUp }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    AppMarkView(size: 56)
                    Text("Connecte-toi").displayStyle(22).foregroundColor(.white)
                    Text("Pour rejoindre un vrai club, avec un classement et un fil d'activité réels.")
                        .font(RUFont.sans(12.5))
                        .foregroundColor(RUColor.text2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 24)

                SignInWithAppleButton(.signIn, onRequest: configureAppleRequest, onCompletion: handleAppleCompletion)
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack {
                    Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)
                    Text("ou").font(RUFont.sans(11)).foregroundColor(RUColor.text3)
                    Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline)
                }

                emailForm

                if let errorMessage {
                    Text(errorMessage)
                        .font(RUFont.sans(12))
                        .foregroundColor(RUColor.rose)
                        .multilineTextAlignment(.center)
                }

                Button(mode == .signIn ? "Pas de compte ? Crée-en un" : "Déjà un compte ? Connecte-toi") {
                    mode = mode == .signIn ? .signUp : .signIn
                    errorMessage = nil
                }
                .font(RUFont.sans(12, weight: .semibold))
                .foregroundColor(RUColor.text2)
                .padding(.top, 4)
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.bottom, 40)
        }
        .background(RUColor.bg)
        .disabled(isLoading)
        .overlay {
            if isLoading {
                ProgressView().tint(.white)
            }
        }
    }

    private var emailForm: some View {
        VStack(spacing: 10) {
            if mode == .signUp {
                TextField("Prénom", text: $name)
                    .textFieldStyle(AuthFieldStyle())
                    .textContentType(.givenName)
            }
            TextField("Email", text: $email)
                .textFieldStyle(AuthFieldStyle())
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            SecureField("Mot de passe", text: $password)
                .textFieldStyle(AuthFieldStyle())
                .textContentType(mode == .signIn ? .password : .newPassword)

            Button(mode == .signIn ? "SE CONNECTER" : "CRÉER MON COMPTE") {
                submitEmailForm()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || (mode == .signUp && name.trimmingCharacters(in: .whitespaces).isEmpty))
        }
    }

    private func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Connexion Apple impossible."
                return
            }
            // Apple only sends `fullName` the very first time this Apple ID signs into this app.
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            Task { await runAuth { try await appState.auth.signInWithApple(identityToken: identityToken, name: name.isEmpty ? nil : name) } }
        case .failure:
            errorMessage = "Connexion Apple annulée ou impossible."
        }
    }

    private func submitEmailForm() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        Task {
            await runAuth {
                if mode == .signIn {
                    try await appState.auth.logIn(email: trimmedEmail, password: password)
                } else {
                    try await appState.auth.signUp(email: trimmedEmail, password: password, name: name.trimmingCharacters(in: .whitespaces))
                }
            }
        }
    }

    @MainActor
    private func runAuth(_ action: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        do {
            // `action()` (signInWithApple/logIn/signUp) already populates `currentUser` from its
            // own response — a follow-up refreshMe() here was a second, fully redundant round
            // trip: ClubView's `onChange(of: auth.isSignedIn)` fires the moment this dismisses and
            // reloads everything (including a fresh refreshMe) anyway.
            try await action()
            // Fire-and-forget: a device token obtained earlier (e.g. during onboarding, before
            // any account existed) only ever gets a chance to reach the backend once signed in.
            // Not awaited — registering it isn't worth delaying the dismiss for.
            Task { await NotificationService.shared.sendPendingDeviceTokenIfSignedIn() }
            dismiss()
        } catch AuthServiceError.badResponse(409, _) {
            errorMessage = "Un compte existe déjà avec cet email."
        } catch AuthServiceError.badResponse(401, _) {
            errorMessage = "Email ou mot de passe incorrect."
        } catch AuthServiceError.badResponse(422, _) {
            errorMessage = "Ce prénom n'est pas autorisé — choisis-en un autre."
        } catch {
            errorMessage = "Connexion impossible — vérifie ta connexion internet."
        }
        isLoading = false
    }
}

private struct AuthFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(RUFont.sans(14))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }
}
