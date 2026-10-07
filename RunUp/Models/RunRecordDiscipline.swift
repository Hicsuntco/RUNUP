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

    /// Quand le total porte bien sur TOUT, disciplines confondues — l'assiduité, la série, le
    /// nombre de jours actifs. Explicite exprès : « toutes » doit être une décision écrite, pas
    /// l'absence de décision.
    var allDisciplines: [RunRecord] { self }
}
