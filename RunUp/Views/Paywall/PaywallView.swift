import SwiftUI
import StoreKit
import Foundation

/// L'écran d'abonnement, affiché à la fin de l'inscription et tant que l'abonnement n'est pas
/// actif.
///
/// # Ce que la validation App Store exige ici
///
/// Un paywall incomplet est un motif de rejet fréquent (guideline 3.1.2), et la liste est courte
/// mais stricte : le nom de l'abonnement, sa DURÉE, son prix, ce qu'il contient, un lien vers les
/// conditions d'utilisation, un lien vers la politique de confidentialité, et un bouton de
/// restauration. Tout est là, et rien n'y est décoratif — retirer un seul de ces éléments pour
/// faire plus propre, c'est un aller-retour de deux semaines avec la revue.
struct PaywallView: View {
    @Environment(AppState.self) private var appState
    var subscriptions: SubscriptionService
    /// `nil` à la fin de l'inscription — il n'y a nulle part où revenir. Renseigné quand l'écran
    /// est ouvert depuis les réglages, où il doit se fermer.
    var onClose: (() -> Void)?

    @State private var selected: Product?

    /// Les conditions standard d'Apple. L'app n'a pas de CGU propres, et c'est exactement le cas
    /// que ce document couvre — la revue l'accepte, à condition que le lien soit là.
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacyURL = URL(string: "https://hicsuntco.github.io/RUNUP/privacy.html")!

    /// Un type nommé plutôt qu'un tuple : Swift n'accepte pas de key path vers un élément de
    /// tuple, donc `ForEach(_, id: \.1)` ne compile pas — et l'erreur qu'il rend ne parle pas des
    /// tuples.
    private struct Advantage: Identifiable {
        let icon: String
        let text: String
        var id: String { text }
    }

    private var advantages: [Advantage] {
        [Advantage(icon: "figure.run", text: String(localized: "Un programme qui s'adapte à ta forme chaque semaine")),
         Advantage(icon: "bubble.left.fill", text: String(localized: "Le coach, sans limite de messages")),
         Advantage(icon: "chart.line.uptrend.xyaxis", text: String(localized: "Allure, charge d'entraînement, records, prédictions")),
         Advantage(icon: "applewatch", text: String(localized: "La montre, le widget et le suivi GPS")),
         Advantage(icon: "person.3.fill", text: String(localized: "Le club, les amis et les parcours partagés"))]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                advantagesList
                offers
                actions
                legal
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(RUColor.pageBackground)
        .task {
            await subscriptions.start()
            if selected == nil { selected = subscriptions.products.first }
        }
        .onChange(of: subscriptions.products.map(\.id)) { _, _ in
            if selected == nil { selected = subscriptions.products.first }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let onClose {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(RUColor.text3)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Fermer")
                }
            }
            Text("RUNUP Plus").displayStyle(30).foregroundColor(RUColor.textPrimary)
            Text("Sept jours offerts. Ensuite, tout le programme, sans rien qui manque.")
                .font(RUFont.sans(.label)).foregroundColor(RUColor.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var advantagesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(advantages) { advantage in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: advantage.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(RUColor.rose)
                        .frame(width: 28, height: 28)
                        .background(RUColor.rose.opacity(0.10), in: RoundedRectangle(cornerRadius: RUSpacing.radiusChip, style: .continuous))
                    Text(advantage.text)
                        .font(RUFont.sans(.body)).foregroundColor(RUColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 5)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ruCard()
    }

    @ViewBuilder private var offers: some View {
        if subscriptions.products.isEmpty {
            // Sans produits, il n'y a rien à acheter et le bouton mentirait. Le cas arrive pour de
            // vrai : pas de réseau, ou des produits pas encore approuvés côté App Store Connect.
            VStack(alignment: .leading, spacing: 8) {
                Text(subscriptions.loadFailed
                     ? "Les formules n'ont pas pu être chargées."
                     : "Chargement des formules…")
                    .font(RUFont.sans(.body)).foregroundColor(RUColor.text2)
                if subscriptions.loadFailed {
                    Button("Réessayer") { Task { await subscriptions.loadProducts() } }
                        .font(RUFont.sans(.body, weight: .semibold))
                        .foregroundColor(RUColor.rose2)
                        .frame(minHeight: 44)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .ruCard()
        } else {
            VStack(spacing: 10) {
                ForEach(subscriptions.products, id: \.id) { product in
                    offerRow(product)
                }
            }
        }
    }

    private func offerRow(_ product: Product) -> some View {
        let isSelected = selected?.id == product.id
        let isYearly = product.id == SubscriptionService.ProductID.yearly
        return Button(action: { selected = product }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 19))
                    .foregroundColor(isSelected ? RUColor.rose : RUColor.text3)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(isYearly ? "Annuel" : "Mensuel")
                            .font(RUFont.sans(.label, weight: .bold))
                            .foregroundColor(RUColor.textPrimary)
                        if isYearly, let saving = yearlySavingPercent {
                            // `Text("−\(saving) %")` deviendrait la clé « −%lld % » : un `%`
                            // isolé en fin de chaîne de format, et l'espace avant le signe est en
                            // plus une convention française que l'anglais n'a pas. Le formateur de
                            // pourcentage du système règle les deux, et n'a pas besoin du
                            // catalogue.
                            Text(verbatim: "−" + (Double(saving) / 100).formatted(.percent))
                                .font(RUFont.sans(.micro, weight: .bold))
                                .foregroundColor(RUColor.onRose)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(RUColor.rose, in: Capsule())
                        }
                    }
                    // La durée ET le prix, dans la même phrase : c'est ce que la revue vérifie.
                    Text(isYearly
                         ? String(localized: "\(product.displayPrice) par an")
                         : String(localized: "\(product.displayPrice) par mois"))
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text2)
                }
                Spacer(minLength: 8)
                if isYearly, let monthly = yearlyPerMonth {
                    Text(String(localized: "soit \(monthly)/mois"))
                        .font(RUFont.sans(.micro)).foregroundColor(RUColor.text3)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous)
                    .stroke(isSelected ? RUColor.rose : RUColor.line,
                            lineWidth: isSelected ? 2 : RUSpacing.hairline)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Calculés sur les prix RÉELS renvoyés par StoreKit, jamais écrits en dur : ils changent avec
    /// la devise, la boutique et les taxes locales. Un « −50 % » codé en dur devient faux dès la
    /// première utilisatrice hors zone euro, et c'est le genre d'écart qui fait rejeter une app.
    private var yearlySavingPercent: Int? {
        guard let year = subscriptions.products.first(where: { $0.id == SubscriptionService.ProductID.yearly }),
              let month = subscriptions.products.first(where: { $0.id == SubscriptionService.ProductID.monthly })
        else { return nil }
        // En `Double`, pas en `Decimal`. `Product.price` est un `Decimal`, et `Decimal * 12`
        // ne compile pas : le littéral n'est pas promu, il est inféré comme un autre type
        // numérique. `Decimal` n'a pas non plus de `rounded()`. Pour un pourcentage affiché,
        // la précision du `Double` est très au-delà du nécessaire.
        let monthly = NSDecimalNumber(decimal: month.price).doubleValue
        let yearly = NSDecimalNumber(decimal: year.price).doubleValue
        let full = monthly * 12
        guard full > 0, yearly < full else { return nil }
        return Int(((full - yearly) / full * 100).rounded())
    }

    private var yearlyPerMonth: String? {
        guard let year = subscriptions.products.first(where: { $0.id == SubscriptionService.ProductID.yearly })
        else { return nil }
        // Le format de prix DU PRODUIT, pas un format reconstruit : il porte déjà la devise et
        // les conventions de la boutique de l'utilisatrice.
        return (year.price / Decimal(12)).formatted(year.priceFormatStyle)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: { Task { await buy() } }) {
                if subscriptions.isPurchasing {
                    ProgressView().tint(RUColor.onRose)
                } else {
                    Text("Commencer les 7 jours gratuits")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selected == nil || subscriptions.isPurchasing)

            Text("Sans engagement. Résiliable à tout moment depuis les Réglages de ton iPhone, et rien n'est prélevé avant le huitième jour.")
                .font(RUFont.sans(.micro)).foregroundColor(RUColor.text3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Restaurer mes achats") { Task { await restore() } }
                .font(RUFont.sans(.small, weight: .semibold))
                .foregroundColor(RUColor.text2)
                .frame(minHeight: 44)
        }
    }

    private var legal: some View {
        HStack(spacing: 14) {
            Spacer()
            Link("Conditions d'utilisation", destination: termsURL)
            Text("·").foregroundColor(RUColor.text4)
            Link("Confidentialité", destination: privacyURL)
            Spacer()
        }
        .font(RUFont.sans(.micro))
        .foregroundColor(RUColor.text3)
    }

    private func buy() async {
        guard let product = selected else { return }
        switch await subscriptions.purchase(product) {
        case .subscribed:
            appState.toast(String(localized: "Bienvenue dans RUNUP Plus 🎉"))
        case .pending:
            appState.toast(String(localized: "Achat en attente d'approbation."))
        case .failed:
            appState.toast(String(localized: "L'achat n'a pas abouti."))
        case .cancelled:
            break
        }
    }

    private func restore() async {
        await subscriptions.restore()
        if subscriptions.isSubscribed != true {
            appState.toast(String(localized: "Aucun abonnement actif trouvé."))
        }
    }
}
