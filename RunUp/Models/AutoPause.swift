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

    /// LES SEUILS NE SE TRANSPOSENT PAS D'UNE DISCIPLINE À L'AUTRE.
    ///
    /// Ceux du dessus sont réglés sur une coureuse : 1,3 m/s pour repartir, c'est une allure de
    /// marche rapide, et vingt-cinq mètres, c'est moins de dix secondes de course.
    ///
    /// À vélo, les deux sont faux. Une cycliste à l'arrêt roule encore quelques mètres sur son
    /// élan et repasse au-dessus de 1,3 m/s au moindre coup de pédale dans un embouteillage :
    /// la pause se lèverait à chaque fois. Et vingt-cinq mètres se parcourent en trois secondes
    /// à vingt-cinq à l'heure, donc la deuxième preuve de reprise ne prouve plus rien — elle se
    /// déclencherait sur la dérive GPS d'un vélo immobile à un feu.
    ///
    /// Le seuil de PAUSE bouge aussi, mais pour une seule discipline : en trail. Sur route comme
    /// sur une selle, être arrêtée c'est être arrêtée, et 0,6 m/s le dit bien. Dans une montée à
    /// 15 %, avancer VRAIMENT se fait à deux kilomètres-heure — soit 0,55 m/s, juste en dessous
    /// du seuil. L'app se mettrait donc en pause toute seule au milieu de l'ascension, c'est-à-dire
    /// sur la portion la plus dure de la sortie, et la coureuse retrouverait un chrono arrêté et
    /// un dénivelé tronqué précisément là où elle a fourni le plus d'effort.
    struct Seuils: Equatable {
        var pause: Double
        var reprise: Double
        var eloignement: Double

        static func pour(_ discipline: Discipline) -> Seuils {
            switch discipline {
            case .run:
                // Qualifiées : un type imbriqué ne voit pas les membres de celui qui l'entoure.
                return Seuils(pause: AutoPause.pauseSpeedThreshold,
                              reprise: AutoPause.resumeSpeedThreshold,
                              eloignement: AutoPause.resumeDisplacementMeters)
            case .bike:
                // 3 m/s ≈ 11 km/h : au-dessus, on roule vraiment, on ne pousse pas son vélo.
                // 60 m : deux à trois secondes de roulage, et bien au-delà de toute dérive GPS.
                return Seuils(pause: AutoPause.pauseSpeedThreshold, reprise: 3.0, eloignement: 60)
            case .trail:
                // 0,3 m/s ≈ 1,1 km/h : plus lent que toute progression vers l'avant, y compris une
                // marche de randonnée dans une pente raide. C'est ce qui empêche la pause de se
                // déclencher dans une montée qu'on gravit en marchant — ce qui est de la course en
                // trail, pas une interruption.
                //
                // 1,0 m/s pour la reprise : marcher, en trail, EST une progression. Exiger
                // 1,3 m/s ferait tenir la pause pendant une relance au pas.
                //
                // L'éloignement reste à 25 m : sous les arbres, c'est la preuve de reprise la plus
                // fiable des deux, puisque `CLLocation.speed` est justement ce qui devient
                // indisponible sous le couvert.
                return Seuils(pause: 0.3, reprise: 1.0, eloignement: AutoPause.resumeDisplacementMeters)
            case .swim:
                // AUCUNE PAUSE AUTOMATIQUE, ET C'EST ÉCRIT DANS LES NOMBRES.
                //
                // La pause se décide sur la vitesse GPS, et il n'y a pas de GPS sous l'eau :
                // aucun chemin de l'app n'atteint cette branche, puisque la natation ne se
                // démarre pas depuis le téléphone (voir `Discipline.seDemarreDepuisLeTelephone`).
                //
                // Elle doit répondre quand même, et la réponse juste est « jamais ». Un seuil de
                // reprise infini n'arme jamais la règle — `tick` exige `speed > reprise` avant de
                // compter quoi que ce soit — donc elle rend toujours faux. Rendre les seuils de
                // la course aurait été plus court et faux : si cette branche devenait un jour
                // atteignable, elle mettrait une nageuse en pause toutes les cinq secondes.
                return Seuils(pause: 0, reprise: .infinity, eloignement: .infinity)
            }
        }
    }

    struct State: Equatable {
        /// Faux tant qu'aucune vitesse franche n'a été observée depuis le départ.
        var armed = false
        /// Secondes consécutives passées sous le seuil, une fois armée.
        var stationarySeconds: Double = 0
    }

    /// Un tour d'horloge, une seconde. `speed` à `nil` = vitesse indisponible sur ce point.
    /// Retourne `true` quand la pause doit se déclencher maintenant.
    static func tick(_ state: inout State, speed: Double?, enabled: Bool,
                     seuils: Seuils = Seuils.pour(.run)) -> Bool {
        // L'armement se fait même quand la fonctionnalité est coupée : si elle la réactive en
        // pleine course, la règle ne doit pas repartir de zéro et la mettre en pause à tort.
        if let speed, speed > seuils.reprise { state.armed = true }
        guard enabled, state.armed else {
            state.stationarySeconds = 0
            return false
        }
        guard let speed, speed < seuils.pause else {
            state.stationarySeconds = 0
            return false
        }
        state.stationarySeconds += 1
        guard state.stationarySeconds >= delaySeconds else { return false }
        state.stationarySeconds = 0
        return true
    }

    /// Deux preuves indépendantes qu'elle est repartie ; une seule suffit.
    static func shouldResume(speed: Double?, metersSincePause: Double,
                             seuils: Seuils = Seuils.pour(.run)) -> Bool {
        if let speed, speed > seuils.reprise { return true }
        return metersSincePause > seuils.eloignement
    }
}
