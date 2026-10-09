import Foundation

/// Le mode démonstration, celui des captures d'écran de l'App Store.
///
/// Six écrans sont photographiés par `RunUpUITests.CapturesUITests` dans un simulateur, sur un
/// profil posé de toutes pièces par `CaptureSeed`. Un simulateur n'a ni Santé, ni session, ni
/// abonnement, ni serveur en face — et chacun de ces manques se voyait sur l'image :
///
///   — « Trois objectifs par jour » montrait trois zéros ;
///   — « Un plan qui s'adapte » montrait un graphique FLOUTÉ derrière un verrou RUNUP Plus ;
///   — « Tu ne cours jamais seule » montrait un bouton SE CONNECTER sur un écran vide.
///
/// Trois accroches sur six affirmaient exactement ce que l'image démentait. Ce drapeau permet
/// aux services concernés de répondre ce qu'ils répondraient à quelqu'un de réellement
/// installé, sans réseau et sans rien inventer que le profil de démonstration ne contienne.
///
/// # CE QU'IL NE PEUT PAS DEVENIR DANS LA CONSTRUCTION ENVOYÉE À L'APP STORE
///
/// `commencer()` n'existe qu'en débogage. La construction de l'App Store ne contient donc PAS
/// une ligne de code capable de mettre ce drapeau à vrai : il y est une constante fausse, et
/// aucun argument de lancement, aucun réglage, aucune réponse de serveur ne peut l'y réveiller.
///
/// Le drapeau lui-même, lui, est compilé partout. C'est délibéré : le mettre sous `#if DEBUG`
/// obligerait chacun des endroits qui le consultent à porter sa propre condition de
/// compilation, et c'est précisément le genre de garde qu'on finit par oublier d'un côté — avec
/// pour seul symptôme un écran qui ne compile plus que dans une configuration sur deux.
enum Demonstration {
    /// `nonisolated(unsafe)` : écrit une seule fois, au tout début du lancement, avant que le
    /// moindre autre fil n'existe. Les lectures qui suivent ne voient jamais qu'une constante.
    nonisolated(unsafe) private(set) static var enCours = false

    #if DEBUG
    static func commencer() { enCours = true }
    #endif
}
