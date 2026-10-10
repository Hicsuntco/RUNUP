import Foundation

/// Les réponses à choix de l'inscription : l'identifiant qui part en base, et le libellé qui
/// s'affiche.
///
/// # POURQUOI CES LISTES NE VIVENT PLUS DANS LES VUES
///
/// Elles étaient écrites en dur dans le `ForEach` qui les affiche — quatre tableaux dans
/// `DeepDiveStepView`, un cinquième dans `WellbeingFieldsView`. Tant que personne d'autre ne
/// lisait ces réponses, ça tenait : la vue qui pose la question était la seule à savoir que
/// `"1y+"` veut dire « Plus d'1 an ».
///
/// L'écran de récapitulatif de fin d'inscription a changé ça. Il RELIT les réponses pour les
/// montrer, donc il a besoin de la même correspondance — et la recopier aurait donné deux
/// tableaux à tenir d'accord, avec une traduction qui dérive d'un côté sans que rien ne le
/// signale. C'est l'identifiant persisté qui fait le lien entre les deux écrans ; il appartient
/// au modèle, pas à la vue qui l'a posé en premier.
enum OnboardingChoices {
    /// L'identifiant est ce qui est PERSISTÉ (et lu par le moteur de plan) ; le libellé n'est
    /// qu'un habillage, et peut changer de langue sans rien casser.
    typealias Choix = (id: String, label: String)

    /// Des propriétés calculées, et non des `static let` : les libellés passent par
    /// `String(localized:)`, donc une constante les figerait dans la langue du premier accès —
    /// et « Être régulière » s'accorde en plus avec la personne, qui n'est pas connue au
    /// chargement de la classe.
    static var priorites: [Choix] {
        [
            ("speed", String(localized: "Aller plus vite")),
            ("endurance", String(localized: "Tenir plus longtemps")),
            ("consistency", Accord.selon(f: String(localized: "Être régulière"),
                                         m: String(localized: "Être régulier"))),
            ("trail", String(localized: "Dénivelé / trail")),
        ]
    }

    static var recences: [Choix] {
        [
            ("1m", String(localized: "Moins d'1 mois")),
            ("6m", String(localized: "1 à 6 mois")),
            ("1y", String(localized: "6 mois à 1 an")),
            ("1y+", String(localized: "Plus d'1 an")),
        ]
    }

    static var budgetsHebdo: [Choix] {
        [
            ("1h", String(localized: "Moins d'1h")),
            ("2h", String(localized: "1 à 2h")),
            ("3h", String(localized: "2 à 3h")),
            ("3h+", String(localized: "Plus de 3h")),
        ]
    }

    static var momentsDeLaJournee: [Choix] {
        [
            ("morning", String(localized: "Matin")),
            ("noon", String(localized: "Midi")),
            ("evening", String(localized: "Soir")),
            ("varies", String(localized: "Ça varie")),
        ]
    }

    /// `"none"` est une réponse à part : elle se CHOISIT (« Aucune » doit pouvoir être cochée,
    /// sinon on ne sait pas distinguer « rien à signaler » de « pas répondu »), mais elle ne se
    /// RELIT pas — un récapitulatif qui annonce « on surveille : aucune » ne dit rien.
    static let aucuneBlessure = "none"

    static var blessures: [Choix] {
        [
            (aucuneBlessure, String(localized: "Aucune")),
            ("knee", String(localized: "Genou")),
            ("ankle", String(localized: "Cheville")),
            ("back", String(localized: "Dos")),
            ("other", String(localized: "Autre")),
        ]
    }

    /// Le libellé d'un identifiant, ou `nil` si l'identifiant est absent ou inconnu.
    ///
    /// Inconnu arrive pour de vrai : un brouillon d'inscription repris après une mise à jour qui
    /// a retiré un choix porte encore l'ancien identifiant. Mieux vaut une pastille en moins
    /// qu'une pastille portant `"1y+"`.
    static func libelle(_ id: String?, dans liste: [Choix]) -> String? {
        guard let id else { return nil }
        return liste.first { $0.id == id }?.label
    }
}
