import Foundation

/// QUELQU'UN, ÉCRIT DE LA MÊME FAÇON PARTOUT.
///
/// # CE QUI ÉTAIT SIGNALÉ : « ÇA FAIT APPROXIMATIF »
///
/// La même personne ne portait pas le même nom d'un écran à l'autre. Au fil, au classement, sous
/// un commentaire, sur un record du club et dans la liste des membres, on lisait « Charlotte ».
/// Dans la recherche d'amis, « Charlotte Grudé ». Sur sa page, « Charlotte Grudé » puis
/// « @charlotte ». Trois écritures pour une personne, et aucune règle qui dise laquelle quand.
///
/// Ce n'était pas un oubli isolé mais une absence de décision : chaque écran a été composé
/// séparément, et chacun a affiché ce que son modèle portait. Or les modèles ne portaient pas la
/// même chose — `PublicUser` et `PublicProfile` avaient le nom de famille, `FeedItem`,
/// `CommentItem`, `LeaderboardRow`, `ClubRecord` et `ClubRunner` ne l'avaient pas, alors que le
/// serveur l'avait sous la main dans la même requête.
///
/// # LA RÈGLE, UNE FOIS
///
/// Prénom et nom partout où l'on NOMME quelqu'un : le fil, les commentaires, le classement, les
/// records, les membres, les participants d'une course, sa page. Le pseudo garde son rôle, qui
/// n'est pas de nommer mais d'identifier sans ambiguïté — la recherche et la page de quelqu'un.
///
/// Dix-huit membres dans un club suffisent à ce que deux prénoms se répètent. Un prénom seul ne
/// dit alors plus QUI a couru, et c'est précisément sur un classement et sur un fil que la
/// question se pose.
///
/// # UN PROTOCOLE, ET PAS UNE FONCTION LIBRE
///
/// Parce qu'il répond à deux questions au lieu d'une. « Comment écrit-on un nom » — la fonction
/// y suffirait. Et « de quoi parle ce type » : `: Nomme` dit qu'une structure décrit une
/// PERSONNE, donc qu'elle doit porter son nom de famille et ne jamais afficher `name` seul.
/// C'est cette seconde question qui a manqué : rien ne distinguait `ClubRecord`, qui nomme
/// quelqu'un, de `SharedRoute`, qui nomme un itinéraire.
protocol Nomme {
    /// Le prénom. Il s'appelle `name` partout — côté serveur c'est `users.name`, et le renommer
    /// ici obligerait à écrire une clé de décodage sur une douzaine de structures.
    var name: String { get }
    /// `nil` tant qu'il n'y en a pas. L'inscription l'exige depuis `NameStepView`, mais les
    /// comptes créés avant, et ceux ouverts avec Apple sans partager le nom, n'en ont pas.
    var nomDeFamille: String? { get }
}

extension Nomme {
    /// « Charlotte Grudé », ou « Charlotte » quand il n'y a pas de nom de famille.
    ///
    /// Prénom d'abord dans les trois langues livrées (français, anglais, espagnol). Le jour où
    /// l'app parlerait une langue qui met le nom devant, c'est ici — et seulement ici — que
    /// l'ordre se discuterait.
    var nomComplet: String {
        guard let nomDeFamille, !nomDeFamille.trimmingCharacters(in: .whitespaces).isEmpty else {
            return name
        }
        return "\(name) \(nomDeFamille)"
    }
}
