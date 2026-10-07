import Foundation

/// L'estimation de dépense, écrite une seule fois.
///
/// Elle l'était trois fois : dans `LiveRunViewModel.kcal`, dans `AddRunSheet` au moment
/// d'enregistrer une course saisie à la main, et dans `AppState` au moment de marquer une séance
/// comme faite. Les trois valaient 62, et les trois portaient un commentaire expliquant qu'elles
/// devaient rester d'accord — c'est le signe qu'on protégeait à la main ce qu'un seul endroit
/// garantit tout seul. Le commentaire d'`AppState` le dit mot pour mot : « deux constantes
/// différentes pour la même approximation feraient diverger une course au GPS et une course
/// saisie à la main sur des chiffres identiques ». Elles ne peuvent plus.
///
/// C'est une APPROXIMATION PLATE, et assumée comme telle : pas de poids, pas de fréquence
/// cardiaque, pas de dénivelé. Elle n'est pas là pour être juste, elle est là pour ne pas
/// afficher 0 kcal après une vraie sortie — et pour que le même effort donne le même nombre
/// quelle que soit la façon dont il a été enregistré.
enum Calories {
    /// ~62 kcal au kilomètre : l'ordre de grandeur courant pour la course à pied, toutes
    /// corpulences confondues.
    static let perKm: Double = 62

    /// Le repli quand aucune distance n'est connue — une séance marquée faite sans l'avoir
    /// mesurée. Sept kcal la minute, soit environ dix kilomètres à l'heure au tarif ci-dessus :
    /// la même hypothèse, exprimée dans l'unité qui reste disponible.
    static let perMinuteWithoutDistance: Double = 7

    /// À VÉLO, C'EST LA DURÉE QUI COMPTE, PAS LA DISTANCE.
    ///
    /// En courant, chaque kilomètre coûte à peu près la même chose : on porte son poids, on ne
    /// roule pas. À vélo non — une descente de cinq kilomètres ne coûte rien, et les cinq
    /// kilomètres de la montée coûtent dix fois plus. Appliquer un tarif au kilomètre à une
    /// sortie vélo donnerait un chiffre faux dans un sens ou dans l'autre selon le profil du
    /// terrain, et le même chiffre pour une sortie plate tranquille et pour un col.
    ///
    /// Neuf kcal la minute : l'ordre de grandeur d'une sortie de loisir soutenue. Aussi
    /// approximatif que le reste de ce fichier, et assumé — mais approximatif sur la bonne
    /// grandeur.
    static let perCyclingMinute: Double = 9

    /// La règle, par discipline. `durationMinutes` n'est plus un dernier recours à vélo : c'est
    /// la mesure principale.
    static func estimate(_ discipline: Discipline, distanceKm: Double, durationMinutes: Int) -> Double {
        switch discipline {
        case .run:  return estimate(distanceKm: distanceKm, durationMinutes: durationMinutes)
        case .bike: return Double(durationMinutes) * perCyclingMinute
        }
    }

    /// La distance d'abord, parce qu'elle est mesurée ; la durée seulement en dernier recours.
    /// Course uniquement — voir la variante par discipline ci-dessus.
    static func estimate(distanceKm: Double, durationMinutes: Int) -> Double {
        distanceKm > 0 ? distanceKm * perKm : Double(durationMinutes) * perMinuteWithoutDistance
    }

    /// Ce que montre l'écran de course : une distance en train d'être mesurée, donc jamais de
    /// repli à la durée — tant que le GPS n'a pas accroché, zéro kilomètre vaut zéro kcal, et
    /// c'est la vérité.
    static func estimate(distanceKm: Double) -> Double {
        distanceKm * perKm
    }
}
