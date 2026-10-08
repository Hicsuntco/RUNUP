import Foundation

extension Array where Element == RunRecord {
    /// LE SEUL PASSAGE pour agréger des relevés.
    ///
    /// Écrire `runs.reduce(0) { $0 + $1.distanceKm }` était juste tant qu'il n'y avait qu'une
    /// discipline, et devient faux sans prévenir le jour où il y en a deux. Passer par ici force
    /// à répondre à la question « de quoi parle ce total ? » — et `check_disciplines.py` refuse
    /// les sommes qui ne sont pas passées par là.
    func only(_ discipline: Discipline) -> [RunRecord] {
        filter { $0.discipline == discipline }
    }

    /// Tout ce qui se court À PIED : la route et le trail.
    ///
    /// # POURQUOI IL A FALLU CE TROISIÈME FILTRE
    ///
    /// Les agrégations disaient toutes `.only(.run)`, et c'était juste tant que la seule autre
    /// discipline était le vélo : « de la course » et « pas du vélo » désignaient le même
    /// ensemble. Le trail les sépare, et il l'a fait en silence — il est arrivé en ne comptant
    /// NULLE PART. Pas dans la distance du mois, pas dans les statistiques, pas dans les badges,
    /// pas dans l'usure des chaussures.
    ///
    /// Le modèle disait pourtant le contraire : `Discipline.trail.wearsShoes` vaut vrai. Ce
    /// drapeau était déclaré, testé, et utilisé NULLE PART — pendant que `Shoe.totalKm` filtrait
    /// sur `.only(.run)` à côté. Un drapeau qui affirme une chose et un calcul qui en fait une
    /// autre, à deux fichiers d'écart : le genre de contradiction qui ne casse rien et qui rend
    /// les chiffres faux.
    ///
    /// Ce filtre-ci est maintenant le seul endroit qui répond à « ce kilomètre est-il couru », et
    /// il répond en lisant le drapeau plutôt qu'en énumérant les disciplines — donc la natation,
    /// le jour venu, n'aura pas à repasser par les quinze sites d'agrégation.
    ///
    /// # CE QUI N'EST PAS DEDANS
    ///
    /// L'ALLURE. Une allure de trail et une allure de route ne se comparent pas : la même foulée
    /// donne 4:20 sur le plat et 9:30 dans une montée à 15 %. Un record d'allure, une allure
    /// moyenne, une comparaison de semaine à semaine restent sur `.only(.run)` — pour la même
    /// raison que `Discipline.followsPaceTargets` est faux en trail.
    var onFoot: [RunRecord] { filter { $0.discipline.wearsShoes } }

    /// Quand le total porte bien sur TOUT, disciplines confondues — l'assiduité, la série, le
    /// nombre de jours actifs. Explicite exprès : « toutes » doit être une décision écrite, pas
    /// l'absence de décision.
    var allDisciplines: [RunRecord] { self }
}
