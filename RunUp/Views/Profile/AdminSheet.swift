import SwiftUI

/// La fiche de la maison.
///
/// # À QUOI ELLE SERT, ET À QUOI ELLE NE SERT PAS
///
/// Elle ne commande RIEN. Pas un interrupteur, pas un bouton qui accorde un droit : tout ce
/// qu'on pourrait y actionner serait, par construction, une chose que l'app s'accorde à
/// elle-même. Le droit est décidé par le serveur, à partir d'une liste qui vit dans son
/// environnement — voir `lib/admin.js`.
///
/// Elle RÉPOND. À une question précise, et c'est celle qu'on se pose quand ça ne marche pas :
/// « sous quelle adresse suis-je connectée ? » Parce que « Se connecter avec Apple » peut créer
/// un compte sous un `…@privaterelay.appleid.com` que personne ne devine, et qu'on peut avoir
/// deux comptes sans le savoir — un par mot de passe sur un appareil, un par Apple sur l'autre.
/// Hukaia a passé une mise à jour entière à chercher ça : le péage s'y était refermé sur la
/// personne qui avait écrit l'app, parce que son iPhone s'était connecté sous une autre adresse.
///
/// Et elle distingue les deux pannes qui se ressemblent : « tu n'es pas dans la liste » et « il
/// n'y a pas de liste ». La première se corrige en ajoutant une adresse, la seconde en créant la
/// variable. Sans cette distinction on essaie la première pendant une heure.
struct AdminSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(SubscriptionService.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    private var compte: AuthenticatedUser? { appState.auth.currentUser }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    etat

                    EyebrowLabel(text: "Le compte connecté", color: RUColor.text3)
                    VStack(spacing: 0) {
                        ligne("Adresse", compte?.email ?? String(localized: "inconnue du serveur"))
                        Divider().background(RUColor.line)
                        ligne("Nom", compte?.name ?? "—")
                        Divider().background(RUColor.line)
                        ligne("Identifiant", compte?.id ?? "—")
                    }
                    .ruCard()

                    EyebrowLabel(text: "Les droits", color: RUColor.text3)
                    VStack(spacing: 0) {
                        ligne("Compte de la maison", oui(compte?.isAdmin == true))
                        Divider().background(RUColor.line)
                        ligne("Liste configurée côté serveur", oui(compte?.adminListConfigured == true))
                        Divider().background(RUColor.line)
                        ligne("Abonnement App Store", abonnement)
                        Divider().background(RUColor.line)
                        ligne("Plan complet ouvert", oui(subscriptions.unlocks(.raceGoal)))
                    }
                    .ruCard()

                    EyebrowLabel(text: "Cette installation", color: RUColor.text3)
                    VStack(spacing: 0) {
                        ligne("Version", "\(version) (\(build))")
                        Divider().background(RUColor.line)
                        ligne("Serveur", AuthService.hoteDuServeur)
                    }
                    .ruCard()

                    Text("Cette fiche ne commande rien : elle montre ce que le serveur répond. Un droit qu'on pourrait s'accorder depuis l'app ne serait pas un droit, ce serait un interrupteur.")
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text3).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
            }
            .background(RUColor.pageBackground)
            .navigationTitle("Fiche admin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
        .preferredColorScheme(RUColor.colorScheme)
    }

    /// La phrase d'en-tête, qui dit QUOI FAIRE plutôt que ce qui ne va pas.
    ///
    /// Trois états, et trois conduites différentes. C'est tout l'intérêt de distinguer « pas de
    /// liste » de « pas dedans » : la première se répare dans les réglages de Vercel, la seconde
    /// en ajoutant une ligne à une liste qui existe déjà.
    @ViewBuilder private var etat: some View {
        if compte == nil {
            encart("Pas de compte connecté sur cet appareil. Les droits de la maison suivent le compte, pas le téléphone.")
        } else if compte?.isAdmin == true {
            encart("Compte de la maison reconnu. Le plan complet est ouvert, sans abonnement.")
        } else if compte?.adminListConfigured == false {
            encart("Aucune liste de comptes de la maison côté serveur. Crée la variable d'environnement RUNUP_ADMIN_EMAILS sur Vercel, avec l'adresse affichée ci-dessous, puis redéploie.")
        } else {
            encart("Cette adresse n'est pas dans la liste des comptes de la maison. Ajoute celle affichée ci-dessous à RUNUP_ADMIN_EMAILS sur Vercel — c'est la seule que le serveur reconnaîtra.")
        }
    }

    private func encart(_ texte: LocalizedStringKey) -> some View {
        Text(texte)
            .font(RUFont.sans(.body)).foregroundColor(RUColor.text2).lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(RUSpacing.cardPadding)
            .ruCard()
    }

    private func ligne(_ titre: LocalizedStringKey, _ valeur: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(titre)
                .font(RUFont.sans(.emphasis, weight: .medium)).foregroundColor(RUColor.textPrimary)
            Spacer(minLength: 12)
            // `Text(verbatim:)` : ces valeurs viennent du serveur ou du bundle, elles sont déjà
            // ce qu'elles sont. Les repasser au catalogue chercherait une clé qui n'existe pas.
            Text(verbatim: valeur)
                .font(RUFont.mono(13)).foregroundColor(RUColor.text2)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(minHeight: 44)
    }

    private func oui(_ valeur: Bool) -> String {
        valeur ? String(localized: "oui") : String(localized: "non")
    }

    private var abonnement: String {
        switch subscriptions.isSubscribed {
        case true: return String(localized: "actif")
        case false: return String(localized: "aucun")
        default: return String(localized: "pas encore vérifié")
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
}
