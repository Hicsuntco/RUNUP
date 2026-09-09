import SwiftUI
import StoreKit

/// Le bouton « code promo », et tout ce qui va avec.
///
/// Il existe à deux endroits — le pied de l'offre et les réglages d'abonnement — et il n'y a
/// aucune raison que la mécanique y soit écrite deux fois : la feuille, l'attente du droit et le
/// message qui suit sont les mêmes. Seule l'apparence change, d'où le `label` en paramètre.
///
/// LA FEUILLE EST CELLE D'APPLE. C'est elle qui reçoit le code, le vérifie, et affiche ses propres
/// erreurs. L'app ne voit jamais le code et n'a aucune liste à tenir : un code promo d'abonnement
/// est un objet d'App Store Connect, pas une chaîne de caractères qu'on comparerait ici. C'est
/// aussi ce qui fait qu'il ne peut pas être contourné en bidouillant l'app.
struct OfferCodeButton<Label: View>: View {
    let subscriptions: SubscriptionService
    let onOutcome: (OfferCodeOutcome) -> Void
    @ViewBuilder let label: () -> Label

    @State private var presenting = false

    var body: some View {
        Button { presenting = true } label: { label() }
            .offerCodeRedemption(isPresented: $presenting) { result in
                let sheetFailed: Bool
                switch result {
                case .success: sheetFailed = false
                case .failure: sheetFailed = true
                }
                Task { onOutcome(await subscriptions.applyRedemption(sheetFailed: sheetFailed)) }
            }
    }
}
