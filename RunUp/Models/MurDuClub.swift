import Foundation

/// Une entrée de l'onglet Activité : une sortie, ou un message du mur.
///
/// Deux formes, une seule liste triée — le même motif que le fil unique, pour la même raison.
/// Elle vivait en `private enum` au milieu de `ClubView` ; elle en sort avec la règle qui la
/// trie, parce que les deux ne se comprennent qu'ensemble.
enum EntreeDuClub: Identifiable {
    case sortie(FeedItem)
    case message(ClubPost)

    var id: String {
        switch self {
        case .sortie(let item): return "s-\(item.id)"
        case .message(let post): return "m-\(post.id)"
        }
    }

    var date: Date {
        switch self {
        case .sortie(let item): return item.createdAt
        case .message(let post): return post.createdAt
        }
    }
}

/// CE QUE QUELQU'UN EST EN TRAIN DE FAIRE SUR LE MUR DU CLUB.
///
/// # POURQUOI CET OBJET EXISTE
///
/// Le mur fait 242 lignes dans `ClubView` et touchait **onze** des dix-huit états de la vue. Les
/// quatre découpes précédentes de ce fichier sortaient chacune une carte qui n'en demandait zéro
/// ou un : c'est ce qui les rendait sûres, et c'est pour ça qu'elles sont passées en premier.
///
/// Onze n'est pas un signe de complexité, c'est un signe que PERSONNE NE LES POSSÈDE. Ils
/// traînaient tous à plat dans la grande vue, et sortir le mur tel quel aurait voulu dire passer
/// onze fils à la main — chacun une occasion de brancher le mauvais, sans que rien ne le dise,
/// dans un remaniement qui ne doit RIEN changer.
///
/// Ici, ils sont huit et ils ont un propriétaire. `reportTarget` et `pendingBlock` restent dehors,
/// et ce n'est pas un oubli : ils sont posés aussi par le classement et par la page du club, donc
/// ce ne sont pas des états du mur. Les ranger ici aurait fabriqué un propriétaire faux.
///
/// # CE QU'IL PORTE EN PLUS, ET POURQUOI C'EST LE VRAI GAIN
///
/// Deux règles qui vivaient en propriétés privées d'une vue de 1 400 lignes, donc vérifiables
/// seulement en ouvrant l'écran avec les bonnes données — c'est-à-dire jamais. Elles sont pures,
/// elles sont maintenant éprouvées, et chacune porte une décision qui n'était écrite nulle part.
@MainActor
@Observable
final class MurDuClub {

    // ── Ce qu'elle est en train d'écrire ─────────────────────────────────────────────────────

    /// Le texte en cours de frappe. Il appartient à l'écran, pas au magasin : le magasin publie
    /// et recharge le mur, il rend si ça a marché, et c'est la vue qui décide alors de vider.
    var brouillon = ""

    /// Un envoi est parti et n'est pas revenu. Sert à éteindre le bouton le temps de l'aller-retour.
    var envoiEnCours = false

    /// Le message auquel elle répond, s'il y en a un.
    var reponseA: ClubPost?

    // ── Ce qu'elle est en train d'ouvrir ─────────────────────────────────────────────────────

    var messageEnModification: ClubPost?
    var commentsActivity: FeedItem?
    var editingActivity: FeedItem?
    var pendingDeleteActivity: FeedItem?

    // ── L'apparition du fil ──────────────────────────────────────────────────────────────────

    /// Passe à vrai à la première activité reçue, et ne redescend pas : l'animation de révélation
    /// ne doit jouer qu'une fois par ouverture de l'écran, pas à chaque rechargement.
    var filDevoile = false

    // ── Les règles ───────────────────────────────────────────────────────────────────────────

    /// ON NE PUBLIE PAS DU VIDE, ET PAS DEUX FOIS.
    ///
    /// Le garde doit être lu AVANT de lever `envoiEnCours` : un brouillon vide ne doit pas faire
    /// clignoter le bouton en « envoi en cours » le temps d'un `await` qui ne partira pas.
    ///
    /// Les espaces et les retours à la ligne ne comptent pas — un message qui n'est que des
    /// retours à la ligne est un message vide, et il partait.
    var peutPublier: Bool {
        !brouillon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !envoiEnCours
    }

    /// LES SORTIES ET LES MESSAGES, ENTRELACÉS PAR DATE — PAS EMPILÉS EN DEUX LISTES.
    ///
    /// Un mur posé au-dessus des sorties se lit comme une annonce épinglée ; mêlés, un message de
    /// lundi et une sortie de lundi se répondent, et c'est ce qui fait une conversation de club.
    ///
    /// Seuls les messages de PREMIER NIVEAU entrent : une réponse s'affiche sous le sien, pas au
    /// milieu du fil où elle n'aurait plus de question. C'est la décision la moins visible des
    /// deux, et celle qu'un remaniement fait disparaître sans rien casser — le fil se remplit
    /// simplement de répliques orphelines.
    nonisolated static func entrees(sorties: [FeedItem], messages: [ClubPost]) -> [EntreeDuClub] {
        let premierNiveau = messages.filter { $0.parentId == nil }.map(EntreeDuClub.message)
        return (sorties.map(EntreeDuClub.sortie) + premierNiveau).sorted { $0.date > $1.date }
    }

    /// Les réponses à un message, de la plus ancienne à la plus récente.
    ///
    /// L'ordre est l'INVERSE de celui du fil, et c'est voulu : un fil se lit du plus récent au
    /// plus ancien parce qu'on vient voir les nouvelles, une conversation se lit dans l'ordre où
    /// elle s'est tenue. Deux tris opposés sur le même écran est exactement le genre d'écart
    /// qu'on « corrige » en croyant bien faire.
    nonisolated static func reponses(a message: ClubPost, dans messages: [ClubPost]) -> [ClubPost] {
        messages.filter { $0.parentId == message.id }.sorted { $0.createdAt < $1.createdAt }
    }
}
