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
    /// La fonctionnalité qui a fait ouvrir cet écran, quand il vient d'un verrou.
    ///
    /// Elle change le titre : quelqu'un qui vient d'essayer de parler au coach lit « Ton coach
    /// personnel » plutôt qu'une promesse générale sur l'abonnement. C'est le seul instant où
    /// l'envie est précise, et la gâcher en récitant tout le catalogue est le plus sûr moyen de
    /// perdre la vente qu'on avait déjà à moitié faite.
    var highlighted: PlusFeature?
    /// `nil` à la fin de l'inscription — il n'y a nulle part où revenir. Renseigné quand l'écran
    /// est ouvert depuis les réglages ou depuis un verrou, où il doit se fermer.
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
            VStack(spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 16) {
                    advantagesList
                    offers
                }
                .padding(.horizontal, RUSpacing.pagePadding)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
        .background(RUColor.pageBackground)
        // Épinglé plutôt que posé à la fin du défilement. Le bouton était en bas d'une page qui
        // laissait ensuite un tiers d'écran vide : il fallait faire défiler pour trouver l'action
        // principale, et l'espace vide sous elle disait « c'est fini » alors que rien n'avait été
        // proposé. Un pied fixe met le prix et l'action toujours sous le pouce.
        .safeAreaInset(edge: .bottom) { footer }
        .task {
            await subscriptions.start()
            if selected == nil { selected = subscriptions.products.first }
            // Après `start()`, pas avant : le nombre de formules effectivement chargées fait
            // partie de ce qu'on veut savoir, et c'est ce qui distingue « elle a vu une offre »
            // de « elle a vu un écran vide ».
            Analytics.shared.track(.paywallShown, [
                "products": .int(subscriptions.products.count),
                // Quelle porte fait vendre : le verrou du coach ne convertit sûrement pas comme
                // celui des prédictions, et c'est exactement ce qu'on veut apprendre pour savoir
                // où placer la frontière la prochaine fois.
                "origin": .string(highlighted?.rawValue ?? (onClose == nil ? "onboarding" : "settings")),
            ])
            if subscriptions.products.isEmpty {
                Analytics.shared.track(.paywallProductsUnavailable)
            }
        }
        .onChange(of: subscriptions.products.map(\.id)) { _, _ in
            if selected == nil { selected = subscriptions.products.first }
        }
    }

    /// Le héros : un aplat d'accent pleine largeur, arrondi en bas.
    ///
    /// L'écran commençait par un titre noir sur fond blanc, au-dessus d'une pile de boîtes
    /// blanches — l'écran le plus commercial de l'app ressemblait à une page de réglages. Une
    /// couleur pleine en haut donne une identité en une demi-seconde, et c'est la seule chose que
    /// cet écran doit réussir avant qu'on lise quoi que ce soit.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let onClose {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(RUColor.onRose.opacity(0.85))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Fermer")
                }
                .padding(.bottom, -8)
            }
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                Text("7 jours offerts")
                    .font(RUFont.sans(.small, weight: .bold))
            }
            .foregroundColor(RUColor.onRose)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(RUColor.onRose.opacity(0.18), in: Capsule())

            Text(highlighted?.title ?? String(localized: "RUNUP Plus"))
                .displayStyle(34)
                .foregroundColor(RUColor.onRose)
                .fixedSize(horizontal: false, vertical: true)
            Text(highlighted?.pitch ?? String(localized: "Ton programme, ton coach et tes stats. Sans rien qui manque."))
                .font(RUFont.sans(.label))
                .foregroundColor(RUColor.onRose.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        // Une carte teintée en retrait, pas une bannière pleine largeur passant sous la barre
        // d'état. `ignoresSafeArea` sur un enfant de `ScrollView` ne fait pas ce qu'on croit — la
        // vue est disposée dans l'espace du défilement — et la référence apportée fait exactement
        // ça : sa carte verte « Your Weekly Progress » est une carte arrondie en retrait.
        .background(RUColor.accentGradient(from: .topLeading, to: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: RUSpacing.radiusHero, style: .continuous))
        .padding(.horizontal, RUSpacing.pagePadding)
        .padding(.top, onClose == nil ? 14 : 4)
    }

    private var advantagesList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Ce que tu débloques")
                .font(RUFont.sans(.label, weight: .bold))
                .foregroundColor(RUColor.textPrimary)
            VStack(alignment: .leading, spacing: 13) {
                ForEach(advantages) { advantage in
                    HStack(alignment: .top, spacing: 12) {
                        // Un glyphe plein, sans pastille. Cinq carrés rose pâle empilés faisaient
                        // cinq taches délavées sur du blanc et tiraient l'œil avant le texte
                        // qu'ils sont censés annoncer — c'était l'élément le plus bruyant de
                        // l'écran pour l'information la moins importante.
                        Image(systemName: advantage.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(RUColor.rose)
                            .frame(width: 22, alignment: .center)
                        Text(advantage.text)
                            .font(RUFont.sans(.body))
                            .foregroundColor(RUColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ruCard()
    }

    @ViewBuilder private var offers: some View {
        if subscriptions.products.isEmpty {
            // Quasiment inatteignable depuis que `grantsAccess` laisse entrer dès qu'il n'y a rien
            // à vendre : sans produits, cet écran ne s'affiche plus du tout. Reste une ligne
            // sobre pour le cas où les produits disparaîtraient pendant que l'écran est ouvert —
            // et surtout plus la grande carte vide qui occupait le milieu de la page.
            HStack(spacing: 10) {
                ProgressView().tint(RUColor.text3)
                Text("Chargement des formules…")
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        return Button(action: {
            // Seulement quand la sélection CHANGE : retaper la formule déjà cochée n'est pas un
            // second choix, et le compter gonflerait l'étape la plus intéressante de l'entonnoir.
            if selected?.id != product.id {
                Analytics.shared.track(.paywallPlanSelected, ["plan": .string(isYearly ? "yearly" : "monthly")])
            }
            selected = product
        }) {
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

    /// Le pied épinglé : le prix choisi, l'action, et les deux liens que la revue exige.
    ///
    /// Rassemblés ici parce qu'ils forment une seule décision. Éparpillés dans le défilement, le
    /// bouton se lisait sans son prix et le prix sans son bouton.
    private var footer: some View {
        VStack(spacing: 9) {
            if let line = priceLine {
                Text(line)
                    .font(RUFont.sans(.small))
                    .foregroundColor(RUColor.text2)
                    .multilineTextAlignment(.center)
            }
            Button(action: { Task { await buy() } }) {
                if subscriptions.isPurchasing {
                    ProgressView().tint(RUColor.onRose)
                } else {
                    Text("Commencer les 7 jours gratuits")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selected == nil || subscriptions.isPurchasing)

            Text("Renouvellement automatique, résiliable à tout moment.")
                .font(RUFont.sans(.micro)).foregroundColor(RUColor.text3)

            HStack(spacing: 12) {
                Button("Restaurer mes achats") { Task { await restore() } }
                Text(verbatim: "·").foregroundColor(RUColor.text4)
                Link("Conditions d'utilisation", destination: termsURL)
                Text(verbatim: "·").foregroundColor(RUColor.text4)
                Link("Confidentialité", destination: privacyURL)
            }
            .font(RUFont.sans(.micro))
            .foregroundColor(RUColor.text3)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, RUSpacing.pagePadding)
        .padding(.top, 14)
        .padding(.bottom, 6)
        // Un fond opaque, pas transparent : le contenu défile DESSOUS, et sans lui les lignes de
        // texte passeraient à travers le bouton.
        .background(
            RUColor.bg
                .overlay(Rectangle().fill(RUColor.line).frame(height: RUSpacing.hairline),
                         alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    /// « 7 jours gratuits, puis 39,99 € par an ». La phrase que la revue cherche, et celle que
    /// l'utilisatrice cherche aussi.
    private var priceLine: String? {
        guard let product = selected else { return nil }
        let isYearly = product.id == SubscriptionService.ProductID.yearly
        return isYearly
            ? String(localized: "7 jours gratuits, puis \(product.displayPrice) par an")
            : String(localized: "7 jours gratuits, puis \(product.displayPrice) par mois")
    }

    private func buy() async {
        guard let product = selected else { return }
        let plan: AnalyticsValue = .string(product.id == SubscriptionService.ProductID.yearly ? "yearly" : "monthly")
        Analytics.shared.track(.purchaseStarted, ["plan": plan])
        switch await subscriptions.purchase(product) {
        case .subscribed:
            Analytics.shared.track(.purchaseCompleted, ["plan": plan])
            appState.toast(String(localized: "Bienvenue dans RUNUP Plus 🎉"))
        case .pending:
            // « En attente » n'est ni un succès ni un échec — typiquement Demander à acheter, sur
            // un compte enfant. Le ranger avec l'un des deux fausserait les deux.
            Analytics.shared.track(.purchaseFailed, ["plan": plan, "reason": .string("pending")])
            appState.toast(String(localized: "Achat en attente d'approbation."))
        case .failed:
            Analytics.shared.track(.purchaseFailed, ["plan": plan, "reason": .string("failed")])
            appState.toast(String(localized: "L'achat n'a pas abouti."))
        case .cancelled:
            // Distinct d'un échec, et c'est tout l'intérêt : ici la machinerie a parfaitement
            // fonctionné, la personne a lu le prix et a dit non. Un taux d'annulation élevé se
            // corrige sur l'offre ; un taux d'échec élevé se corrige dans le code.
            Analytics.shared.track(.purchaseCancelled, ["plan": plan])
        }
    }

    private func restore() async {
        Analytics.shared.track(.restoreTapped)
        // Le résultat est toujours annoncé, y compris quand ça marche : un bouton qui ne répond
        // rien laisse croire qu'il n'a rien fait, et fait retaper.
        appState.toast(await subscriptions.restore().message)
    }
}
