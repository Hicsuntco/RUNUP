import SwiftUI

/// Le mouvement de RUNUP, nommé et dosé en un seul endroit.
///
/// # POURQUOI UN FICHIER POUR ÇA
///
/// L'app animait déjà — dans neuf vues, avec neuf réglages écrits à la main. `.easeOut(0.45)`
/// ici, `.spring(response: 0.35, dampingFraction: 0.8)` là, `.easeInOut(0.3)` ailleurs. Aucun
/// n'est faux isolément ; ensemble ils ne forment pas une app, ils forment une collection
/// d'écrans. On ne le voit pas sur une capture — ça ne se voit qu'en se servant de l'app, et ça
/// s'appelle « ça fait bricolé » sans qu'on sache désigner quoi.
///
/// Une famille de courbes et trois tempos suffisent à tout. Le reste, c'est du dosage.
///
/// # DES RESSORTS, PAS DES COURBES DE BÉZIER
///
/// `.easeOut` décrit un mouvement qui s'arrête ; un ressort décrit un objet qui arrive. La
/// différence s'entend : une carte qui freine à l'arrivée paraît pilotée, une carte qui se pose
/// paraît physique. Les trois tempos partagent la même famille pour que deux éléments lancés
/// ensemble gardent le même caractère, même à des durées différentes.
///
/// # LE REBOND DESCEND QUAND LA DISTANCE MONTE
///
/// 0,26 de rebond sur un objet qui bouge de dix points se lit comme de la vivacité. Le même
/// rebond sur un anneau qui se remplit sur une seconde se lit comme une erreur de calcul : la
/// valeur dépasse, revient, et quelqu'un qui regarde un chiffre d'objectif croit l'avoir mal lu.
/// D'où `glide` à rebond nul — rien de ce qui porte une DONNÉE ne doit dépasser sa valeur.
enum RUMotion {

    /// Ce qui répond au doigt : pastilles, boutons, bascules. Court et vif.
    static let snap = Animation.spring(duration: 0.26, bounce: 0.26)

    /// Ce qui arrive à l'écran : cartes, feuilles, lignes de liste.
    static let settle = Animation.spring(duration: 0.44, bounce: 0.12)

    /// Ce qui porte une valeur et ne doit jamais la dépasser : anneaux, jauges, tracés, compteurs.
    static let glide = Animation.spring(duration: 0.80, bounce: 0)

    /// Le long voyage : un tracé de course qui se redessine en entier.
    static let draw = Animation.timingCurve(0.22, 0.61, 0.36, 1, duration: 1.45)

    /// Un chiffre qui change tout seul : chrono, distance, allure.
    ///
    /// À part, et volontairement hors de la famille à ressorts. Un ressort fait dépasser le
    /// glyphe au-dessus de sa ligne avant de le reposer ; sur un chrono qui change une fois par
    /// seconde, ce dépassement devient un tic permanent dans le coin de l'œil. Et 200 ms est le
    /// plafond : au-delà, la transition du chiffre suivant commence avant la fin de la
    /// précédente et le chrono passe la course entier à trembler.
    static let digit = Animation.easeOut(duration: 0.18)

    /// L'écart entre deux éléments d'une même série.
    ///
    /// 55 ms. En dessous, la cascade se lit comme un seul mouvement flou ; au-dessus, on ATTEND le
    /// dernier élément, et une attente sur l'écran d'accueil se paie à chaque ouverture.
    static let stagger: Double = 0.055

    /// Le rang au-delà duquel on cesse de décaler.
    ///
    /// Sans plafond, le douzième élément d'une liste démarre 660 ms après le premier — et une
    /// liste longue devient une animation qu'on regarde au lieu d'un contenu qu'on lit.
    static let staggerCap = 6

    /// Le délai d'entrée d'un élément selon son rang dans sa série.
    static func delay(_ index: Int) -> Double {
        Double(min(max(index, 0), staggerCap)) * stagger
    }

    /// De combien une carte monte en entrant par le bas de l'écran.
    ///
    /// Voir `View.ruRises` pour ce que ce nombre doit respecter : il reste sous le plus petit
    /// écart entre deux éléments auxquels le modificateur s'applique, sans quoi deux voisins se
    /// recouvrent pendant le défilement.
    ///
    /// Ici plutôt que dans l'extension de `View` : une extension de PROTOCOLE n'accepte aucune
    /// propriété stockée, pas même statique.
    static let riseOffset: CGFloat = 6

    /// La même animation, ou AUCUNE si la personne a demandé moins de mouvement.
    ///
    /// Rendre `nil` plutôt qu'une version plus courte : « Réduire les animations » ne veut pas
    /// dire « des animations plus rapides », ça veut dire que le mouvement déclenche un malaise
    /// physique chez certaines personnes. Une version accélérée du même déplacement le déclenche
    /// aussi. La valeur doit SAUTER.
    static func respecting(_ reduceMotion: Bool, _ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }
}

extension View {
    /// Les cartes se posent en montant quand elles entrent par le bas de l'écran.
    ///
    /// Seulement par le bas : `.scrollTransition(.interactive)` appliquerait le même effet en
    /// HAUT, et le prénom de l'accueil se mettrait à rétrécir dès qu'on effleure l'écran — un
    /// mouvement qu'on n'a pas demandé, sur l'élément qu'on regardait.
    ///
    /// Ni flou ni ombre ici : les deux se recalculent à chaque image pendant le défilement, et
    /// c'est exactement le budget qu'on n'a pas à 120 Hz. L'opacité et l'échelle sont gratuites,
    /// elles se font sur la couche déjà composée.
    ///
    /// # LE DÉCALAGE NE DÉPLACE RIEN DANS LA MISE EN PAGE, ET C'EST LE PIÈGE
    ///
    /// `offset` bouge ce qui est DESSINÉ sans toucher à la place réservée. Deux cartes voisines
    /// ne traversent pas le bord de l'écran en même temps, donc elles ne reçoivent pas le même
    /// décalage : celle du haut descend de 22 points pendant que celle du bas n'a pas encore
    /// bougé. L'écart entre deux cartes de l'accueil est de 12. Elles se RECOUVRAIENT donc de dix
    /// points pendant tout le défilement, et comme chaque carte porte un gros bouton, le symptôme
    /// visible était « des boutons les uns sur les autres ».
    ///
    /// La règle : le décalage doit rester sous le plus petit écart des éléments auxquels on
    /// applique ce modificateur. 6 points contre 12, donc, et la marge est intentionnelle.
    ///
    /// L'échelle, elle, est sûre quel que soit son réglage : ancrée en bas, une carte rétrécit
    /// vers le HAUT, donc elle s'éloigne de celle du dessous au lieu d'entrer dedans.
    func ruRises(_ reduceMotion: Bool = false) -> some View {
        scrollTransition(topLeading: .identity, bottomTrailing: .interactive) { content, phase in
            let d = reduceMotion ? 0.0 : abs(phase.value)
            return content
                .opacity(1 - 0.5 * d)
                .scaleEffect(1 - 0.05 * d, anchor: .bottom)
                .offset(y: RUMotion.riseOffset * d)
        }
    }
}
