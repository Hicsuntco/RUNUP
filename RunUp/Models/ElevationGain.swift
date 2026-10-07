import Foundation

/// Le dénivelé positif d'une sortie, accumulé fix GPS par fix GPS.
///
/// # LE DÉFAUT QUE CE TYPE EXISTE POUR CORRIGER
///
/// `LocationService` sommait chaque écart d'altitude positif entre deux fixes :
///
/// ```swift
/// let delta = loc.altitude - last.altitude
/// if delta > 0 { elevationGainMeters += delta }
/// ```
///
/// Ça paraît juste, et c'est faux. L'altitude GPS est bruitée de quelques mètres d'un fix au
/// suivant, même téléphone posé sur une table. Ne garder que la MOITIÉ POSITIVE d'un bruit
/// symétrique, c'est le redresser : chaque oscillation vers le haut est créditée, chaque
/// oscillation vers le bas est jetée. Le total ne revient donc jamais à zéro, il monte — et il
/// monte à peu près linéairement avec la DURÉE de la sortie, pas avec son relief.
///
/// `RunUpTests/ElevationGainTests` mesure l'écart sur des suites déterministes :
///
/// | scénario                                   | vrai D+ | ancien calcul | ce calcul |
/// |--------------------------------------------|--------:|--------------:|----------:|
/// | une heure immobile, bruit de 2 m           |       0 |     **2 023** |   **0,0** |
/// | sortie trail, 6 montées de 167 m           |   1 000 |     **4 669** |   **976** |
///
/// Quatre mille six cent soixante-neuf mètres de D+ sur une sortie qui en fait mille. Sur bitume,
/// avec quarante mètres de vrai dénivelé noyés dans le même bruit, personne ne regardait le
/// chiffre d'assez près pour s'en apercevoir. En trail, le D+ EST la mesure de la sortie.
///
/// # LES TROIS MÉCANISMES, ET LE TRAVAIL DE CHACUN
///
/// 1. **Plausibilité verticale** — un écart qui impliquerait de monter plus vite que
///    `vitesseVerticaleMax` n'est pas une montée, c'est un saut de signal. Il est ignoré, et
///    l'instant de référence n'est PAS avancé : au fix suivant le `dt` est donc plus grand, la
///    même dérive redevient plausible, et la mesure se raccroche toute seule au nouveau palier au
///    lieu de rejeter indéfiniment.
///
///    Elle compare deux altitudes BRUTES consécutives, pas la brute à la lissée. C'est la
///    première version qui faisait ça, et elle rejetait de VRAIES montées : la moyenne glissante
///    retarde de quelques mètres par construction, donc l'écart entre la brute et la lissée
///    frôlait le seuil en permanence dès que ça grimpait. Une sortie de 100 m de D+ en perdait
///    vingt. Borner une vitesse verticale, c'est comparer deux mesures, pas une mesure et un
///    souvenir amorti.
///
/// 2. **Lissage exponentiel** — ce qui alimente la suite n'est pas l'altitude brute mais sa
///    moyenne glissante. Le bruit perd les deux tiers de son amplitude ; une vraie montée, elle,
///    converge.
///
/// 3. **Bande morte** — rien n'est crédité avant que l'altitude lissée se soit écartée de
///    `seuilMetres` de la dernière valeur RETENUE. En dessous, on ne sait pas si ça monte ou si ça
///    bruite, donc on ne compte rien. Au-dessus, l'écart entier est crédité et la référence
///    avance : une montée soutenue est comptée en entier, par paliers de trois mètres.
///
/// # CE QUE CE CALCUL NE SAIT PAS FAIRE, ET IL FAUT LE SAVOIR
///
/// **Il sous-estime les petites bosses.** La bande morte coûte quelques mètres à chaque
/// renversement de pente : un vallon de 100 m de D+ réparti en trois versants n'en rend que 86, et
/// trente bosses de dix mètres n'en rendent que la moitié. Sur une sortie de trail ordinaire —
/// quelques longues montées — la perte est de 2 à 3 % (976 pour 1 000). Sur du micro-relief, elle
/// est franchement mauvaise.
///
/// C'est un choix, pas un oubli : sous-compter du micro-relief est une erreur bornée par le
/// relief réel, alors que l'ancien calcul inventait un chiffre borné par la DURÉE. Mieux vaut
/// 86 que 100 quand l'alternative est 400.
///
/// **Et au-delà de deux mètres de bruit, il fuit.** À 3 m d'écart-type — une sortie sous couvert
/// dense — il laisse encore passer trente à soixante-dix mètres par heure d'immobilité. Le seuil
/// ne peut pas monter plus sans effacer le relief réel : à cette échelle, le signal et le bruit
/// ont la même taille, et aucun filtre ne les sépare.
///
/// La vraie réponse à ça n'est pas un meilleur filtre, c'est un autre capteur. `CMAltimeter` mesure
/// l'altitude RELATIVE au mètre près par la pression, sans aucun bruit GPS — c'est ce qu'utilisent
/// les montres de sport, et c'est exactement la grandeur dont le D+ a besoin. Il coûte
/// l'autorisation « Mouvement et forme », donc une clé `NSMotionUsageDescription` et une invite de
/// plus au premier démarrage. Ce fichier est ce qui empêche le chiffre d'être FAUX ; le baromètre
/// est ce qui le rendrait JUSTE. Dans cet ordre, et pas dans l'autre.
struct ElevationGain: Equatable {

    /// La bande morte, en mètres. Trois : quatre fois l'écart-type du bruit lissé ordinaire, donc
    /// celui-ci ne la franchit pratiquement jamais, et c'est assez fin pour qu'un faux plat
    /// montant compte.
    static let seuilMetres: Double = 3.0

    /// Le facteur de lissage. Un cinquième : le bruit tombe au tiers de son amplitude. Mesuré
    /// contre 0,15 et 0,30 sur cinq profils et six graines — en dessous le relief réel s'efface,
    /// au-dessus le bruit repasse la bande morte.
    static let lissage: Double = 0.20

    /// 3 m/s de vitesse verticale entre deux fixes. Un escalier gravi en courant fait environ
    /// 1 m/s, une montée de trail soutenue 0,2 à 0,4. Trois laisse passer le relief le plus raide
    /// qui existe et coupe les sauts de signal, qui se comptent en dizaines de mètres par seconde.
    static let vitesseVerticaleMax: Double = 3.0

    /// L'altitude GPS est beaucoup moins précise que la position. Quinze mètres : au-delà,
    /// l'appareil annonce lui-même qu'il ne sait pas à quelle hauteur il est.
    static let precisionVerticaleMax: Double = 15

    /// Le dénivelé positif accumulé, en mètres.
    private(set) var metres: Double = 0

    /// L'altitude lissée — celle que la bande morte regarde.
    private var lissee: Double?
    /// La dernière altitude BRUTE retenue, pour la seule plausibilité verticale.
    private var brute: Double?
    /// La dernière altitude lissée RETENUE : l'origine depuis laquelle la bande morte se mesure.
    private var reference: Double?
    private var dernierInstant: Date?

    /// Un fix. `precisionVerticale` est le `verticalAccuracy` de `CLLocation` : négatif quand
    /// l'appareil n'a aucune estimation d'altitude.
    mutating func ajoute(altitude: Double, precisionVerticale: Double, instant: Date) {
        guard precisionVerticale >= 0, precisionVerticale < Self.precisionVerticaleMax else { return }

        if let brute, let dernierInstant {
            let dt = instant.timeIntervalSince(dernierInstant)
            // Un fix qui arrive à la même seconde ou avant n'apporte pas d'écart mesurable, et la
            // division en donnerait un infini.
            guard dt > 0 else { return }
            // Ignoré SANS rien avancer — c'est ce qui permet au `dt` de grandir et à la mesure de
            // se raccrocher d'elle-même si le signal s'est vraiment déplacé.
            guard abs(altitude - brute) / dt <= Self.vitesseVerticaleMax else { return }
        }

        brute = altitude
        dernierInstant = instant
        let nouvelle = lissee.map { $0 + Self.lissage * (altitude - $0) } ?? altitude
        lissee = nouvelle

        guard let origine = reference else {
            reference = nouvelle
            return
        }
        let ecart = nouvelle - origine
        if ecart >= Self.seuilMetres {
            metres += ecart
            reference = nouvelle
        } else if ecart <= -Self.seuilMetres {
            // Une descente ne se soustrait pas — c'est du dénivelé POSITIF. Mais la référence
            // descend avec elle, sinon la remontée suivante serait comptée depuis le sommet et non
            // depuis le creux, et on perdrait tout un vallon.
            reference = nouvelle
        }
    }

    /// Reprise après une pause : l'historique repart de zéro, le total est conservé.
    ///
    /// Même raison que `lastLocation = nil` dans `LocationService.resume()` : si elle a monté deux
    /// étages pendant la pause, cet écart-là n'est pas de la sortie. La distance ne le compte pas,
    /// le dénivelé non plus.
    mutating func reprend() {
        lissee = nil
        brute = nil
        reference = nil
        dernierInstant = nil
    }

    /// Sortie neuve : tout repart de zéro, total compris.
    mutating func remetAZero() {
        metres = 0
        reprend()
    }
}
