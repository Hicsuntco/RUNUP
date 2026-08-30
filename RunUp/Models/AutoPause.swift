import Foundation

/// La règle de pause automatique, séparée de l'écran qui l'applique.
///
/// Elle vivait entièrement dans `tick()`, mêlée au chrono, aux consignes vocales et aux Live
/// Activities — donc invérifiable autrement qu'en allant courir. C'est comme ça qu'elle a pu
/// partir à la dixième seconde de chaque course sans que rien ne le signale : le défaut n'était
/// pas subtil, il était simplement hors de portée du moindre test.
///
/// Trois principes, et chacun répare une panne constatée sur le terrain :
///
/// 1. **Une vitesse inconnue n'est pas un arrêt.** `CLLocation.speed` vaut une valeur négative
///    quand l'appareil ne sait pas — les premiers points de chaque course, et tout point calculé
///    sans effet Doppler. Le code écrivait `max(0, speed)`, ce qui rangeait « je ne sais pas »
///    avec « 0 m/s ». Ici l'inconnu est un `nil` que l'on ne peut pas confondre.
///
/// 2. **On ne met en pause que quelqu'un qu'on a vu courir.** Tant que la course n'a pas été
///    armée par une vitesse franche, il n'y a rien à suspendre : l'état juste est « on attend le
///    départ ». Sans ce verrou, dix ticks à vitesse nulle pendant que la puce GNSS accroche
///    suffisaient à déclencher la pause avant même le premier pas.
///
/// 3. **Repartir ne dépend pas de la vitesse seule.** Un éloignement mesuré depuis le point
///    d'arrêt reste lisible là où la vitesse disparaît — c'est-à-dire à l'arrêt, sous un immeuble
///    ou sous les arbres, au moment précis où la reprise en a besoin.
enum AutoPause {
    /// ~2,2 km/h — bien en dessous d'une marche lente, pour qu'une alternance course/marche ou un
    /// coup d'œil au feu rouge ne déclenche rien ; seul un vrai arrêt passe sous ce seuil.
    static let pauseSpeedThreshold: Double = 0.6
    /// Volontairement plus haut que le seuil de pause (hystérésis) : repartir exactement à la
    /// vitesse qui a déclenché la pause ferait clignoter pause/reprise à chaque fluctuation.
    static let resumeSpeedThreshold: Double = 1.3
    static let delaySeconds: Double = 10
    /// Vingt-cinq mètres ne s'expliquent pas par le tremblement du GPS à l'arrêt (quelques
    /// mètres, une quinzaine dans le pire des cas), et représentent moins de dix secondes de
    /// course.
    static let resumeDisplacementMeters: Double = 25

    struct State: Equatable {
        /// Faux tant qu'aucune vitesse franche n'a été observée depuis le départ.
        var armed = false
        /// Secondes consécutives passées sous le seuil, une fois armée.
        var stationarySeconds: Double = 0
    }

    /// Un tour d'horloge, une seconde. `speed` à `nil` = vitesse indisponible sur ce point.
    /// Retourne `true` quand la pause doit se déclencher maintenant.
    static func tick(_ state: inout State, speed: Double?, enabled: Bool) -> Bool {
        // L'armement se fait même quand la fonctionnalité est coupée : si elle la réactive en
        // pleine course, la règle ne doit pas repartir de zéro et la mettre en pause à tort.
        if let speed, speed > resumeSpeedThreshold { state.armed = true }
        guard enabled, state.armed else {
            state.stationarySeconds = 0
            return false
        }
        guard let speed, speed < pauseSpeedThreshold else {
            state.stationarySeconds = 0
            return false
        }
        state.stationarySeconds += 1
        guard state.stationarySeconds >= delaySeconds else { return false }
        state.stationarySeconds = 0
        return true
    }

    /// Deux preuves indépendantes qu'elle est repartie ; une seule suffit.
    static func shouldResume(speed: Double?, metersSincePause: Double) -> Bool {
        if let speed, speed > resumeSpeedThreshold { return true }
        return metersSincePause > resumeDisplacementMeters
    }
}
