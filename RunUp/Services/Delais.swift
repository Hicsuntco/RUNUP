import Foundation

/// Combien de temps l'app attend avant de dire qu'elle n'a pas pu.
///
/// # LE DÉFAUT
///
/// Aucun délai n'était déclaré nulle part. Les douze requêtes du dépôt partaient sur
/// `URLSession.shared` avec les valeurs par défaut d'Apple : **soixante secondes** par requête.
///
/// Soixante secondes de roue qui tourne, c'est une app cassée. Personne n'attend ça : on ferme,
/// on rouvre, on ferme encore — et si ça arrive au mauvais moment, on désinstalle. La phrase
/// « vérifie ta connexion », que `PanneReseau` sait déjà écrire correctement, n'arrivait qu'une
/// minute après que la personne avait compris toute seule.
///
/// # LES CHIFFRES SONT MESURÉS, PAS CHOISIS
///
/// Un aller-retour sur notre API, relevé le 10 novembre 2026 depuis une machine filaire sur
/// `GET /api/me`, cinq fois : **0,17 à 0,51 seconde**. Sur un téléphone en données mobiles,
/// compter quelques secondes de plus, et davantage au premier appel d'une fonction endormie.
///
/// Quinze secondes, c'est donc trente fois le temps mesuré et cinq fois un mauvais aller-retour
/// mobile qui FONCTIONNE. Ce n'est pas serré : c'est le quart de ce qu'Apple laisse par défaut,
/// et ça reste très au-delà de tout ce qu'on a mesuré.
///
/// # ET ÇA NE PERD RIEN
///
/// C'est la raison pour laquelle on peut se permettre d'être bref : ce qui compte est rejoué.
/// Une sortie publiée part dans `ClubActivityOutbox`, que le serveur accepte sans doublon
/// (`ON CONFLICT (client_id) DO NOTHING`). Les statistiques d'usage attendent dans leur tampon.
/// Les rapports de panne reviennent au lancement suivant. Abandonner vite ne jette donc rien —
/// ça remplace une minute de gel par une phrase honnête et un nouvel essai plus tard.
enum Delais {
    /// Ce qu'on attend en regardant l'écran : une connexion, le fil du club, une recherche, un
    /// profil. Le moment où quelqu'un décide que l'app est cassée arrive bien avant une minute.
    static let interactif: TimeInterval = 15

    /// La réponse du coach, et elle seule. C'est le seul appel où attendre est NORMAL — on vient
    /// de poser une question et un modèle rédige. Soixante secondes, c'est-à-dire le défaut
    /// d'Apple, gardé ici volontairement : le client n'a pas à renoncer avant le serveur.
    static let coach: TimeInterval = 60

    /// Un fichier qui monte — la photo de profil. Une image de plusieurs méga-octets sur un
    /// réseau lent prend légitimement plus de quinze secondes, et l'abandonner en chemin
    /// obligerait à tout recommencer.
    static let televersement: TimeInterval = 60

    /// Ce que personne n'attend : les événements d'usage, les rapports de panne, l'inscription
    /// aux notifications, la déconnexion côté serveur. Vingt secondes parce qu'il n'y a aucune
    /// raison d'aller plus vite qu'un écran, ni aucune raison d'attendre plus longtemps quelque
    /// chose que personne ne regarde et qui sera rejoué.
    static let arrierePlan: TimeInterval = 20
}
