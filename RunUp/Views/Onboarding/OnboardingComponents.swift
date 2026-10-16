import SwiftUI
import UIKit

/// Shared layout pieces for onboarding steps — mirrors `ObScreen`/`ObTitle`/`ObNext`/`ObProgress`
/// in onboarding.jsx.
struct ObScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, RUSpacing.pagePadding)
    }
}

/// Le corps d'un écran d'inscription : centré quand il tient, QUI DÉFILE quand il ne tient plus.
///
/// # LE DÉFAUT
///
/// Quatre écrans de l'inscription étaient écrits « `Spacer()`, le contenu, `Spacer()`, le
/// bouton » — une mise en page qui centre joliment… tant que le contenu est plus court que
/// l'écran. L'app autorise le texte jusqu'à deux fois sa taille (`RUFont.maxScale`). À cette
/// taille, les deux `Spacer` tombent à zéro, le contenu dépasse, et ce qui est en bas de la pile
/// sort de l'écran. En bas de `PlanRecapView`, il y a « C'EST PARTI » — le seul bouton qui
/// termine l'inscription. Autrement dit : quelqu'un qui agrandit le texte pour pouvoir lire
/// l'app ne pouvait pas finir de s'y inscrire, et rien à l'écran ne lui disait pourquoi.
///
/// # POURQUOI UN `ViewThatFits` ET PAS UN `ScrollView` TOUT COURT
///
/// Un `ScrollView` prend toute la hauteur offerte et colle son contenu en haut : à la taille de
/// texte par défaut, les dix écrans d'inscription perdraient leur centrage, pour un défilement
/// dont personne n'a besoin. Le premier candidat est donc la mise en page actuelle, telle quelle,
/// et le second la même, qui défile. Le second tient TOUJOURS — c'est ce qui distingue ce
/// `ViewThatFits` de celui de la barre d'onglets, où un candidat trop haut faisait disparaître
/// le mot « RUN » faute de solution de repli.
struct ObCorps<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
            }
            ScrollView {
                // Le `VStack` est OBLIGATOIRE et pas décoratif : `ObCorps` reçoit un
                // `@ViewBuilder`, donc parfois DEUX vues sœurs (voir `BuildingProgramView`, qui
                // lui passe l'anneau puis la liste des paliers). Sans conteneur, le `.frame`
                // s'appliquerait à chacune séparément et l'empilement dépendrait de ce que le
                // `ScrollView` fait d'un tuple.
                VStack(spacing: 0) { content }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            // Pas de rebond quand il n'y a rien à faire défiler : ce candidat sert aussi aux
            // tailles de texte intermédiaires, où le contenu dépasse de quelques points.
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

struct ObTitle: View {
    var eyebrow: String
    var title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowLabel(text: eyebrow, color: RUColor.rose)
            Text(LocalizedStringKey(title)).displayStyle(30).foregroundColor(RUColor.textPrimary).lineSpacing(-2)
            if let subtitle {
                Text(LocalizedStringKey(subtitle))
                    .font(RUFont.sans(.label))
                    .foregroundColor(RUColor.text2)
                    .lineSpacing(4)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 18)
    }
}

struct ObNext: View {
    var label: String = "CONTINUER"
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            // `LocalizedStringKey(label)`, pas `Text(label)` : le libellé arrive ici sous forme de
            // `String`, donc déjà absorbé comme texte brut avant d'atteindre un `Text` — même
            // raison que `EyebrowLabel`/`SelectableChip`. Un libellé réellement dynamique retombe
            // sur le rendu verbatim qu'il avait déjà.
            Text(LocalizedStringKey(label))
        }
        .buttonStyle(PrimaryButtonStyle(isDisabled: disabled))
        .disabled(disabled)
        // On top of whatever horizontal padding the screen around it already applies — a
        // full-bleed edge-to-edge CTA read as too heavy/dominant; this pulls it in further so it
        // sits with real breathing room instead of touching the screen's margins.
        .padding(.horizontal, 12)
        // OnboardingContainerView's root .ignoresSafeArea() (needed so the background bleeds
        // behind the notch/home indicator) also strips the bottom safe area from this button, so
        // a plain .padding(.bottom, 24) sits almost flush with the home indicator instead of
        // clearing it — safeAreaPadding re-adds that inset on top of the 24pt so the button sits
        // with real breathing room above it, like a normal app's CTA.
        .safeAreaPadding(.bottom, 24)
    }
}

struct ObProgress: View {
    var step: Int
    var total: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? RUColor.rose : RUColor.line)
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, RUSpacing.pagePadding)
        .padding(.top, 10)
    }
}

/// Text field styled to match `.card` inputs across onboarding.
struct ObTextField: View {
    var placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField("", text: $text, prompt: Text(LocalizedStringKey(placeholder)).foregroundColor(RUColor.text3))
            .keyboardType(keyboard)
            .font(RUFont.sans(.title))
            .foregroundColor(RUColor.textPrimary)
            .padding(RUSpacing.cardPadding)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }
}
