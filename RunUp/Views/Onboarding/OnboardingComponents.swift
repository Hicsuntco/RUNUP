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
            Text(LocalizedStringKey(title)).displayStyle(.figure).foregroundColor(RUColor.textPrimary).lineSpacing(-2)
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
    /// Le nombre d'écrans de QUESTIONS, pas d'étapes du modèle de vue : l'écran de construction
    /// ne demande rien, et le compter donnerait une barre qui n'atteint jamais son bout tant
    /// qu'il reste quelque chose à faire.
    var total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? RUColor.rose : RUColor.line)
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, RUSpacing.pagePadding)
        .padding(.top, 10)
        // Dix traits de trois points ne disent pas où on en est : ils se lisent comme une
        // décoration, et pour VoiceOver ils n'existent pas du tout. Le compte est donné en
        // toutes lettres ici, et le chiffre affiché à côté est masqué pour ne pas le doubler.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Écran \(min(step + 1, total)) sur \(total)"))
    }
}

/// « Plus que deux écrans, et ton plan est prêt. »
///
/// # POURQUOI CETTE LIGNE EXISTE
///
/// Les huit vidéos qui vendent l'app montrent trois écrans — « Why do you run ? », l'écran de
/// l'objectif, et le plan — et leur bouton dit « BUILD MY PLAN ». Dans l'app, ce bouton-là est
/// le troisième de onze : après lui viennent le point de départ, un mot sur toi, les jours, le
/// niveau et la montre. Ces cinq écrans ne sont pas du remplissage, ce sont eux qui rendent le
/// plan vraiment sur mesure — mais quelqu'un qui installe après avoir vu la vidéo croit avoir
/// fini, et on lui en demande encore cinq sans un mot.
///
/// D'où une phrase, et seulement À PARTIR DU MOMENT OÙ LA SURPRISE TOMBE : après l'écran que la
/// vidéo présentait comme le dernier. L'afficher dès le début dirait « encore huit écrans » à
/// quelqu'un qui n'avait rien demandé — c'est-à-dire décourager pour rassurer.
struct ObResteALire: View {
    var step: Int

    var body: some View {
        // Le calcul vit dans `OnboardingViewModel.resteALire(apres:)`, avec les bornes dont il
        // dépend et sous test. Ici, il n'y a plus qu'une phrase à poser.
        if let phrase = OnboardingViewModel.resteALire(apres: step) {
            Text(phrase)
                .font(RUFont.sans(.micro, weight: .medium))
                .foregroundColor(RUColor.text3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.horizontal, RUSpacing.pagePadding)
        }
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
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCard, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }
}
