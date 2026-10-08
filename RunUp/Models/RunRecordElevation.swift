import Foundation

extension ElevationGain {

    /// Le nombre d'altitudes connues sous lequel on ne recalcule rien.
    ///
    /// Dix. En dessous, la bande morte et le lissage n'ont pas de quoi travailler, et le chiffre
    /// qui sortirait serait un autre chiffre faux — pas une correction. Mieux vaut laisser une
    /// sortie avec son ancienne valeur, visiblement issue de l'ancien calcul, qu'y écrire un
    /// résultat tiré de trois points.
    static let minimumPourRejouer = 10

    /// Rejoue un tracé déjà enregistré pour en recalculer le dénivelé.
    ///
    /// # POURQUOI CE REJEU EST FIDÈLE
    ///
    /// L'ancien calcul créditait `loc.altitude - last.altitude` où `last` était le fix précédent
    /// ACCEPTÉ — celui qui venait de passer le plancher de bruit horizontal. Et `route` recevait
    /// ses points juste après, dans le même tour de boucle, à partir des mêmes fixes. Les
    /// altitudes du tracé enregistré sont donc EXACTEMENT la suite sur laquelle l'ancien total a
    /// été calculé, ni plus ni moins. Rejouer le tracé, ce n'est pas approximer la sortie : c'est
    /// refaire le même calcul sur les mêmes nombres.
    ///
    /// # CE QUE LE TRACÉ N'A PAS GARDÉ
    ///
    /// **La précision verticale de chaque fix.** Elle n'a pas besoin d'être gardée : une altitude
    /// n'a été écrite dans le tracé que si elle avait passé le contrôle de précision au moment de
    /// l'enregistrement, et sinon la valeur stockée est `nil`. Le filtre est déjà appliqué, dans
    /// la donnée elle-même. D'où le `precisionVerticale: 0` plus bas — ce n'est pas la précision
    /// réelle, c'est la façon de dire « celle-ci a déjà été jugée digne de foi ».
    ///
    /// Une nuance pour les sorties anciennes : le seuil valait vingt mètres et vaut quinze
    /// aujourd'hui. Quelques altitudes conservées sont donc un peu moins sûres que ce qu'on
    /// accepterait maintenant. Il n'y a pas moyen de faire mieux : l'information est perdue.
    ///
    /// **L'horodatage de chaque point.** Il manque, et le contrôle de plausibilité verticale en a
    /// besoin pour borner une vitesse. L'intervalle MOYEN le remplace — la durée divisée par le
    /// nombre de points. C'est une estimation, mais le contrôle ne sert qu'à écarter les sauts de
    /// signal, qui se comptent en dizaines de mètres par seconde : il n'a pas besoin d'une seconde
    /// près. Les trous (`nil`) font avancer l'horloge sans livrer de mesure, ce qui relâche la
    /// borne au bon endroit — un trou dans le signal est exactement le moment où l'altitude a le
    /// droit d'avoir changé beaucoup.
    ///
    /// **Les pauses.** Rien ne les distingue dans le tracé. L'ancien calcul ne créditait pas
    /// l'écart par-dessus une pause (`lastLocation = nil` à la reprise) ; le rejeu, lui, le
    /// crédite. Sur un escalier de métro gravi pendant une pause, ça fait quelques mètres de trop
    /// — bornés par la bande morte, et sans commune mesure avec ce qu'on retire.
    static func rejoue(altitudes: [Double?], intervalleSecondes: Double) -> Double? {
        guard intervalleSecondes > 0 else { return nil }
        guard altitudes.compactMap({ $0 }).count >= minimumPourRejouer else { return nil }

        var calcul = ElevationGain()
        var horloge = Date(timeIntervalSince1970: 0)
        for altitude in altitudes {
            horloge = horloge.addingTimeInterval(intervalleSecondes)
            guard let altitude else { continue }
            calcul.ajoute(altitude: altitude, precisionVerticale: 0, instant: horloge)
        }
        return calcul.metres
    }
}

extension RunRecord {

    /// Le dénivelé que cette sortie AURAIT eu si elle avait été enregistrée avec le calcul
    /// d'aujourd'hui — ou `nil` quand il n'y a pas lieu d'y toucher.
    ///
    /// # IL NE PEUT QUE BAISSER
    ///
    /// Le défaut corrigé est un SUR-comptage : redresser un bruit symétrique ne peut qu'ajouter.
    /// Un rejeu qui proposerait DAVANTAGE que la valeur enregistrée ne révélerait donc pas une
    /// sortie plus montagneuse qu'on ne croyait — il révélerait que le rejeu est en désaccord avec
    /// l'original, c'est-à-dire un défaut dans ce fichier-ci. Dans ce cas on ne touche à rien.
    ///
    /// Ce garde-fou ne protège pas la donnée contre elle-même, il la protège contre MON code :
    /// une réparation s'écrit sur le téléphone de quelqu'un, une seule fois, sans retour possible.
    /// Elle doit pouvoir rater en ne faisant rien plutôt qu'en inventant du dénivelé.
    var deniveleRecalcule: Int? {
        // Testé AVANT de toucher au tracé, et pas seulement pour la logique : un dénivelé nul ne
        // peut pas baisser, donc il n'y a rien à calculer — et SwiftData charge ses propriétés à
        // la demande, si bien que sortir ici évite de décoder le tracé entier. Les sorties saisies
        // à la main et celles importées de Santé, qui sont justement celles sans dénivelé, ne
        // coûtent donc rien du tout à la réparation.
        guard elevationGainM > 0 else { return nil }
        guard !route.isEmpty, durationSeconds > 0 else { return nil }
        let intervalle = Double(durationSeconds) / Double(route.count)
        guard let rejoue = ElevationGain.rejoue(altitudes: route.map(\.altitude),
                                               intervalleSecondes: intervalle) else { return nil }
        let arrondi = Int(rejoue.rounded())
        guard arrondi < elevationGainM else { return nil }
        return arrondi
    }
}
