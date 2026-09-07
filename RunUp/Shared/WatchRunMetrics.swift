import Foundation

/// Les tailles de l'écran de course de la montre, dérivées de la hauteur réellement disponible.
///
/// # Pourquoi ces tailles ne sont pas écrites dans la vue
///
/// Cet écran ne peut être regardé par personne. Il n'y a ni simulateur ni montre dans
/// l'environnement où il est écrit, et la personne qui décide n'en a pas non plus — elle court
/// avec une Garmin. Un écran que personne ne peut regarder ne doit pas pouvoir déborder, et la
/// seule façon de s'en assurer sans le voir est de rendre son encombrement CALCULABLE.
///
/// D'où ce type, sans SwiftUI, avec deux responsabilités : donner à la vue chaque taille, et
/// donner au test la hauteur que l'empilement occupera. Les deux lisent les mêmes valeurs — une
/// taille modifiée déplace le calcul du même coup, et le test le dit.
///
/// # Ce que le calcul vaut, et ce qu'il ne vaut pas
///
/// La hauteur d'une ligne de texte est ESTIMÉE, pas mesurée : Inter occupe environ 1,211 fois sa
/// taille de point (0,969 de montée, 0,242 de descente). C'est une bonne approximation du moteur
/// de rendu, pas le moteur de rendu. D'où la marge de sécurité conservée sur chaque décision
/// plutôt qu'un ajustement au point près, qu'une estimation ne mérite pas.
///
/// Les marges système de watchOS, elles, ne sont pas estimées du tout : la vue lit la hauteur que
/// le système lui donne, quelle qu'elle soit. C'est précisément ce qui permet de ne pas avoir à
/// les deviner.
struct WatchRunMetrics {
    /// La hauteur pour laquelle l'écran a été dessiné — la zone utile d'un boîtier 45 mm. Toutes
    /// les tailles ci-dessous sont exprimées en proportion d'elle.
    static let referenceHeight: CGFloat = 214

    /// Ce qu'on garde libre entre le bas de l'empilement et le bord, pour absorber l'écart entre
    /// la hauteur estimée d'une ligne et celle que le rendu produira.
    static let safetyMargin: CGFloat = 6

    let availableHeight: CGFloat
    /// Plafonné à 1 : au-delà on gonflerait un dessin validé à sa taille, sur un Ultra par exemple.
    /// Planché à 0,55 : en dessous, les planchers de lisibilité dominent et la proportion ne veut
    /// plus rien dire.
    let scale: CGFloat

    init(availableHeight: CGFloat) {
        self.availableHeight = availableHeight
        self.scale = min(1, max(0.55, availableHeight / Self.referenceHeight))
    }

    // MARK: Les tailles
    //
    // Le dessin d'origine — héros 50, espacement 6, bouton 36, secondaire 17 — occupait 212,9
    // points sur les 214 d'un 45 mm. Il tenait à un point près, et seulement si les marges
    // système de watchOS valent bien ce qu'on leur suppose. Quatre valeurs ont donc été reprises,
    // à l'endroit où quelques points ne se voient pas : le héros perd 4 points sur 50, les
    // espacements 1 sur 6, les boutons 2 sur 36, les chiffres du bas 1 sur 17. L'écran garde
    // douze points de libre sur un 45 mm et sept sur un 40 mm — et la légende de progression,
    // qui autrement disparaissait partout sauf sur un Ultra.
    //
    // Les planchers ne protègent pas les mêmes choses que l'échelle. Un grand chiffre peut
    // rétrécir beaucoup et rester lisible — c'est le plus gros objet de l'écran. Une capitale de
    // 8 points, non : sous ce seuil elle cesse d'être un mot pour devenir une texture grise.

    var spacing: CGFloat { 5 * scale }
    var horizontalPadding: CGFloat { 4 }

    var statusDot: CGFloat { max(5, 6 * scale) }
    var statusText: CGFloat { max(8, 10 * scale) }

    var hero: CGFloat { 46 * scale }
    var heroGap: CGFloat { 2 * scale }
    var heroLabel: CGFloat { max(8, 10 * scale) }

    var progressTop: CGFloat { 6 * scale }
    /// Non mise à l'échelle : quatre points est déjà l'épaisseur minimale d'une barre visible.
    var progressBar: CGFloat { 4 }
    var progressGap: CGFloat { 4 * scale }
    var progressCaption: CGFloat { max(7.5, 9 * scale) }

    var secondaryValue: CGFloat { 16 * scale }
    var secondaryGap: CGFloat { 1 * scale }
    var secondaryUnit: CGFloat { max(7, 8.5 * scale) }

    var buttonTop: CGFloat { 2 }
    /// Plancher à 28 : c'est une cible tactile qu'on vise en courant, pas une décoration.
    var buttonHeight: CGFloat { max(28, 34 * scale) }
    var buttonIcon: CGFloat { max(13, 16 * scale) }

    // MARK: L'arbitrage

    /// La légende sous la barre — « SÉANCE · 85 % » — est le premier élément sacrifié quand la
    /// place manque, et le seul.
    ///
    /// La barre porte déjà l'information ; le pourcentage n'en est que la version chiffrée. Tout
    /// le reste de l'écran est soit le chiffre qu'on est venu lire, soit un bouton dont on a
    /// besoin. Sur un 40 mm, cette ligne est ce qui sépare un écran juste d'un écran rogné.
    var showsProgressCaption: Bool {
        height(showsProgress: true, showsCaption: true) + Self.safetyMargin <= availableHeight
    }

    // MARK: L'encombrement

    /// Inter : 0,969 de montée + 0,242 de descente ≈ 1,211 fois la taille de point.
    private static let interLineFactor: CGFloat = 1.211

    static func sansLine(_ size: CGFloat) -> CGFloat { size * interLineFactor }

    /// Les grands chiffres passent par `DisplayFont`, qui applique son facteur de compensation
    /// avant de demander la police : c'est cette taille-là qui occupe la place.
    static func displayLine(_ size: CGFloat) -> CGFloat {
        DisplayFont.pointSize(for: size) * interLineFactor
    }

    /// La hauteur qu'occupera l'empilement, dans une composition donnée.
    ///
    /// La même arithmétique que le `VStack` de la vue : les blocs, plus un espacement entre
    /// chaque paire. Les deux `Spacer` n'y figurent pas — ils valent zéro dès que la place manque,
    /// et c'est le seul cas qui nous intéresse ici.
    func height(showsProgress: Bool, showsCaption: Bool) -> CGFloat {
        var blocks: [CGFloat] = [
            Self.sansLine(statusText),
            Self.displayLine(hero) + heroGap + Self.sansLine(heroLabel),
        ]
        if showsProgress {
            var progress = progressTop + progressBar
            if showsCaption { progress += progressGap + Self.sansLine(progressCaption) }
            blocks.append(progress)
        }
        blocks.append(Self.displayLine(secondaryValue) + secondaryGap + Self.sansLine(secondaryUnit))
        blocks.append(buttonTop + buttonHeight)
        return blocks.reduce(0, +) + spacing * CGFloat(blocks.count - 1)
    }

    /// L'encombrement réel, une fois l'arbitrage de la légende appliqué.
    func height(showsProgress: Bool) -> CGFloat {
        height(showsProgress: showsProgress, showsCaption: showsProgress && showsProgressCaption)
    }
}
