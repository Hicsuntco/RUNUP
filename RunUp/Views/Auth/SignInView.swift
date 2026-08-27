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
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var referralCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// Set right after a successful sign-in/sign-up when the account has no username yet — gates
    /// the sheet on choosing one instead of dismissing straight away. Covers both a genuinely new
    /// account AND an older one (Apple sign-in's one-tap flow can't tell the two apart client-side)
    /// that simply never set one, so this is the one moment guaranteed to reach everyone at least
    /// once, rather than relying on her finding the field in Réglages on her own.
    @State private var showChooseUsername = false
    @State private var usernameField = ""
    @State private var isSavingUsername = false
    @State private var usernameError: String?

    private enum Mode { case signIn, signUp }

    var body: some View {
        ScrollView {
            if showChooseUsername {
                chooseUsernameView
            } else {
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        AppMarkView(size: 56)
                        Text("Connecte-toi").displayStyle(22).foregroundColor(RUColor.textPrimary)
                        Text("Pour rejoindre un vrai club, avec un classement et un fil d'activité réels.")
                            .font(RUFont.sans(12.5))
                            .foregroundColor(RUColor.text2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 24)

                    SignInWithAppleButton(.signIn, onRequest: configureAppleRequest, onCompletion: handleAppleCompletion)
                        // Black-on-light / white-on-dark — a fixed .white button was invisible
                        // against the near-white light-mode sheet.
                        .signInWithAppleButtonStyle(RUColor.isLight ? .black : .white)
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
                    .font(RUFont.sans(12, weight: .medium))
                    .foregroundColor(RUColor.text2)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .buttonStyle(PressableStyle())
                }
                .padding(.horizontal, RUSpacing.pagePadding)
                .padding(.bottom, 40)
            }
        }
        .background(RUColor.pageBackground)
        .disabled(isLoading)
        .overlay {
            if isLoading {
                ProgressView().tint(RUColor.textPrimary)
            }
        }
        .onAppear {
            // A referral only ever matters for a brand-new account — prefilling it also switches
            // straight to the sign-up form, since someone who tapped a friend's link almost
            // certainly doesn't have an account yet.
            guard referralCode.isEmpty, let pending = ReferralLinkHandler.pendingCode else { return }
            referralCode = pending
            mode = .signUp
        }
    }

    private var chooseUsernameView: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                AppMarkView(size: 56)
                Text("Choisis ton pseudo").displayStyle(22).foregroundColor(RUColor.textPrimary)
                Text("Pour que tes amis te retrouvent facilement dans la recherche.")
                    .font(RUFont.sans(12.5))
                    .foregroundColor(RUColor.text2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 24)

            TextField("Pseudo", text: $usernameField)
                .textFieldStyle(AuthFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if let usernameError {
                Text(usernameError)
                    .font(RUFont.sans(12))
                    .foregroundColor(RUColor.rose)
                    .multilineTextAlignment(.center)
            }

            Button(isSavingUsername ? "…" : "CONTINUER") { Task { await saveUsername() } }
                .buttonStyle(PrimaryButtonStyle(isDisabled: !isValidUsernameFormat(usernameField) || isSavingUsername))
                .disabled(!isValidUsernameFormat(usernameField) || isSavingUsername)

            Button("Plus tard") { dismiss() }
                .font(RUFont.sans(12, weight: .medium))
                .foregroundColor(RUColor.text2)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .buttonStyle(PressableStyle())
                .disabled(isSavingUsername)
        }
        .padding(.horizontal, RUSpacing.pagePadding)
        .padding(.bottom, 40)
        .onAppear {
            guard usernameField.isEmpty else { return }
            usernameField = suggestedUsername()
        }
    }

    private var emailForm: some View {
        VStack(spacing: 10) {
            if mode == .signUp {
                HStack(spacing: 10) {
                    TextField("Prénom", text: $name)
                        .textFieldStyle(AuthFieldStyle())
                        .textContentType(.givenName)
                    // Optional — not required to create an account, but without it "Mes amis"
                    // can't search "nom prénom" and a first name alone can't disambiguate
                    // several people sharing a common one.
                    TextField("Nom (facultatif)", text: $lastName)
                        .textFieldStyle(AuthFieldStyle())
                        .textContentType(.familyName)
                }
            }
            TextField("Email", text: $email)
                .textFieldStyle(AuthFieldStyle())
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            SecureField("Mot de passe", text: $password)
                .textFieldStyle(AuthFieldStyle())
                .textContentType(mode == .signIn ? .password : .newPassword)

            if mode == .signUp {
                TextField("Code de parrainage (facultatif)", text: $referralCode)
                    .textFieldStyle(AuthFieldStyle())
                    .textInputAutocapitalization(.characters)
            }

            // Was only checking non-empty — a malformed email or a too-short password round-
            // tripped to the server before any error showed. Sign-in stays format-agnostic
            // (an existing account may predate any length rule); only sign-up gates on it.
            if !email.isEmpty && !isValidEmailFormat {
                Text("Adresse email invalide.").font(RUFont.sans(11)).foregroundColor(RUColor.rose)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if mode == .signUp && !password.isEmpty && password.count < 8 {
                Text("8 caractères minimum.").font(RUFont.sans(11)).foregroundColor(RUColor.rose)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(mode == .signIn ? "SE CONNECTER" : "CRÉER MON COMPTE") {
                submitEmailForm()
            }
            .buttonStyle(PrimaryButtonStyle(isDisabled: !isEmailFormSubmittable))
            .disabled(!isEmailFormSubmittable)
        }
    }

    private var isValidEmailFormat: Bool {
        email.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
    }

    private var isEmailFormSubmittable: Bool {
        guard isValidEmailFormat, !password.isEmpty else { return false }
        if mode == .signUp {
            return password.count >= 8 && !name.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
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
                errorMessage = String(localized: "Connexion Apple impossible.")
                return
            }
            // Apple only sends `fullName` the very first time this Apple ID signs into this app —
            // given/family name are sent as two separate fields (not pre-joined) so the server can
            // store a real, structured `last_name` for "Mes amis" search, this being the one
            // chance to ever capture it.
            let givenName = credential.fullName?.givenName
            let familyName = credential.fullName?.familyName
            let trimmedReferral = referralCode.trimmingCharacters(in: .whitespaces)
            Task { await runAuth { try await appState.auth.signInWithApple(identityToken: identityToken, name: givenName, lastName: familyName, referralCode: trimmedReferral.isEmpty ? nil : trimmedReferral) } }
        case .failure:
            errorMessage = String(localized: "Connexion Apple annulée ou impossible.")
        }
    }

    private func submitEmailForm() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        Task {
            await runAuth {
                if mode == .signIn {
                    try await appState.auth.logIn(email: trimmedEmail, password: password)
                } else {
                    let trimmedReferral = referralCode.trimmingCharacters(in: .whitespaces)
                    let trimmedLastName = lastName.trimmingCharacters(in: .whitespaces)
                    try await appState.auth.signUp(
                        email: trimmedEmail, password: password, name: name.trimmingCharacters(in: .whitespaces),
                        lastName: trimmedLastName.isEmpty ? nil : trimmedLastName,
                        referralCode: trimmedReferral.isEmpty ? nil : trimmedReferral
                    )
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
            ReferralLinkHandler.clearPendingCode()
            // Fire-and-forget: a device token obtained earlier (e.g. during onboarding, before
            // any account existed) only ever gets a chance to reach the backend once signed in.
            // Not awaited — registering it isn't worth delaying the dismiss for.
            Task { await NotificationService.shared.sendPendingDeviceTokenIfSignedIn() }
            // Same story for a photo picked before this account existed (`ProfileView.setAvatar`
            // only syncs when already signed in) — this is its one other chance to reach the
            // server, otherwise she'd show initials-only to every other club member indefinitely.
            if let jpeg = appState.profile.avatarImageData {
                let dataURI = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
                Task { try? await appState.auth.updateAvatar(dataURI: dataURI) }
            }
            // Gate on choosing a pseudo instead of dismissing straight away — a first name alone
            // can't be searched reliably (see FriendsView), and this is the one moment guaranteed
            // to reach every account at least once rather than hoping she finds the field in
            // Réglages on her own. `currentUser` here already reflects the real server value (the
            // auth response includes it directly), so this correctly skips anyone — new or
            // returning — who already has one.
            if appState.auth.currentUser?.username == nil {
                showChooseUsername = true
            } else {
                dismiss()
            }
        } catch AuthServiceError.badResponse(409, _) {
            errorMessage = String(localized: "Un compte existe déjà avec cet email.")
        } catch AuthServiceError.badResponse(401, _) {
            errorMessage = String(localized: "Email ou mot de passe incorrect.")
        } catch AuthServiceError.badResponse(422, _) {
            errorMessage = String(localized: "Ce prénom n'est pas autorisé — choisis-en un autre.")
        } catch {
            errorMessage = String(localized: "Connexion impossible — vérifie ta connexion internet.")
        }
        isLoading = false
    }

    /// Lowercase letters/digits/underscore only, 3-20 chars — mirrors the server's own check
    /// (`api/friends/[action].js`'s `USERNAME_RE`) so a bad format never even reaches it.
    private func isValidUsernameFormat(_ value: String) -> Bool {
        let clean = value.trimmingCharacters(in: .whitespaces).lowercased()
        guard clean.count >= 3, clean.count <= 20 else { return false }
        return clean.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "_" }
    }

    /// A starting point, not a final answer — her real name plus two random digits, so the field
    /// never opens empty (which would just read as "type something" with no hint of the format).
    /// She can freely overwrite it before tapping Continuer.
    private func suggestedUsername() -> String {
        let base = (appState.auth.currentUser?.name ?? name)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
            .prefix(15)
        let suffix = Int.random(in: 10...99)
        let candidate = "\(base)\(suffix)"
        return candidate.count >= 3 ? candidate : "coureur\(suffix)"
    }

    private func saveUsername() async {
        isSavingUsername = true
        usernameError = nil
        let clean = usernameField.trimmingCharacters(in: .whitespaces).lowercased()
        do {
            try await ClubService(auth: appState.auth).updateProfile(username: clean)
            // `refreshMe` rend l'utilisatrice mise à jour ; ici on ne veut que l'effet de bord
            // (le rafraîchissement du profil en mémoire), d'où le `_ =` explicite.
            _ = try? await appState.auth.refreshMe()
            dismiss()
        } catch ClubServiceError.badResponse(409, _) {
            usernameError = String(localized: "Ce pseudo est déjà pris.")
        } catch ClubServiceError.badResponse(400, _) {
            usernameError = String(localized: "Pseudo invalide — lettres minuscules, chiffres, underscore, 3 à 20 caractères.")
        } catch {
            usernameError = String(localized: "Impossible d'enregistrer — vérifie ta connexion.")
        }
        isSavingUsername = false
    }
}

private struct AuthFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(RUFont.sans(14))
            .foregroundColor(RUColor.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }
}
