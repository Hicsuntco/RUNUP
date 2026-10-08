import Foundation

/// Le déroulé d'une vidéo de course : à chaque image, ce qu'il y a à dessiner et ce qu'il y a à
/// écrire.
///
/// # POURQUOI UN MODÈLE SÉPARÉ DU RENDU
///
/// Fabriquer une vidéo, c'est deux problèmes qui n'ont rien à voir : décider ce que montre
/// l'image 173, et la peindre. Le second demande un encodeur et un appareil ; le premier est de
/// l'arithmétique, et c'est là que vivent les erreurs qui comptent — un compteur qui recule, un
/// kilométrage qui ne tombe pas juste, un tracé qui se dessine à vitesse constante alors que la
/// coureuse a marché dans la côte.
///
/// Ce fichier ne contient que le premier, et il est donc vérifiable sans appareil.
///
/// # TROIS CHOIX QUI DÉCIDENT DE TOUT
///
/// **1. Le tracé dessiné est le tracé ROGNÉ, et il passe par la même porte que le partage.**
/// `RouteGeometry.shareablePayload` retire les trois cents premiers et derniers mètres et refuse
/// les parcours trop courts pour qu'il en reste quelque chose. Une vidéo se poste : c'est
/// exactement la surface où un tracé brut publie une adresse. Rien ici ne recalcule cette règle,
/// pour qu'elle ne puisse pas diverger.
///
/// **2. Le temps vient des SPLITS RÉELS, pas d'une vitesse moyenne.** Les points du tracé ne
/// portent pas d'horodatage, mais `RunRecord.splits` porte le temps réel de chaque kilomètre. On
/// peut donc bâtir une vraie fonction distance → temps, au kilomètre près : le trait avance vite
/// là où elle courait vite, et traîne dans la côte. C'est tout ce qui sépare une vidéo qui
/// ressemble à sa course d'une animation à vitesse constante.
///
/// **3. La dernière image porte les chiffres RÉELS de la sortie.** Le rognage fait que le trait
/// s'arrête trois cents mètres avant l'arrivée : laisser le compteur s'arrêter là aussi afficherait
/// « 9,7 km » au bout d'un dix kilomètres, sur l'image précisément faite pour être regardée. Les
/// compteurs montent donc en disant vrai, puis se posent sur les chiffres de la course.
enum RunVideoTimeline {

    /// Trente images par seconde : c'est la cadence que tous les réseaux acceptent sans
    /// réencoder, et la plus basse qui ne fasse pas saccader un trait qui se dessine.
    static let imagesParSeconde = 30

    /// Douze secondes. Sous les trente secondes qu'Apple accepte pour un aperçu App Store, et
    /// au-dessus des dix secondes en dessous desquelles une boucle ne laisse pas voir le parcours.
    static let secondesDeVideo: Double = 12

    static var imagesParDefaut: Int { Int(secondesDeVideo * Double(imagesParSeconde)) }

    /// Ce qu'une image montre.
    struct Instant: Equatable {
        /// Combien de points du tracé rogné sont dessinés. Jamais zéro quand il y a un tracé :
        /// une première image vide se lit comme une vidéo qui n'a pas démarré.
        var pointsDessines: Int
        /// La distance parcourue DEPUIS LE DÉPART RÉEL, en mètres — pas depuis le début du tracé
        /// dessiné, qui commence trois cents mètres plus loin.
        var metres: Double
        /// Le temps de course écoulé, en secondes.
        var secondes: Double
        /// Le dénivelé positif accumulé, ou `nil` quand le tracé ne porte pas assez d'altitudes
        /// fiables pour qu'un chiffre intermédiaire soit vrai. Nul n'oblige à afficher un nombre
        /// à chaque image ; afficher un faux, si.
        var denivelePositifM: Double?
    }

    struct Rendu {
        /// Le tracé rogné — le seul qu'on dessine, et le seul qui sorte du téléphone.
        var route: [RunRecord.RoutePoint]
        var instants: [Instant]
    }

    // MARK: Les distances

    /// Distances cumulées le long d'un tracé, en mètres. Le premier élément vaut toujours zéro.
    static func distancesCumulees(_ route: [RunRecord.RoutePoint]) -> [Double] {
        guard !route.isEmpty else { return [] }
        var cumul: [Double] = [0]
        cumul.reserveCapacity(route.count)
        for i in 1..<route.count {
            cumul.append(cumul[i - 1] + RouteGeometry.distanceMeters(route[i - 1], route[i]))
        }
        return cumul
    }

    // MARK: Le temps

    /// Le temps de course atteint à une distance donnée, d'après les splits réels.
    ///
    /// `splits` est le temps de chaque kilomètre ENTIER, en secondes. Le dernier kilomètre d'une
    /// sortie est presque toujours partiel et n'a donc pas de split : son temps est ce qui reste
    /// de la durée totale, réparti sur ce qui reste de la distance.
    ///
    /// Sans aucun split — une sortie saisie à la main, une course importée de Santé — on n'a
    /// strictement aucune information sur l'allure. La répartition uniforme est alors la seule
    /// honnête : elle est exacte aux deux bouts et ne prétend rien entre les deux.
    static func secondes(aMetres metres: Double, splits: [Double],
                         metresTotaux: Double, secondesTotales: Double) -> Double {
        guard metresTotaux > 0, secondesTotales > 0 else { return 0 }
        let d = min(max(0, metres), metresTotaux)

        // Un split de plus que de kilomètres entiers parcourus serait un split inventé.
        let utilisables = Array(splits.prefix(max(0, Int(metresTotaux / 1000)))).map { max(0, $0) }
        guard !utilisables.isEmpty else { return secondesTotales * d / metresTotaux }

        var cumul: [Double] = [0]
        for s in utilisables { cumul.append(cumul[cumul.count - 1] + s) }
        let metresDesSplits = Double(utilisables.count) * 1000
        let tempsDesSplits = cumul[cumul.count - 1]
        guard tempsDesSplits > 0 else { return secondesTotales * d / metresTotaux }

        /// Le temps brut donné par les splits, sans recalage.
        func brut(_ x: Double) -> Double {
            if x <= metresDesSplits {
                let i = min(utilisables.count - 1, Int(x / 1000))
                return cumul[i] + utilisables[i] * (x - Double(i) * 1000) / 1000
            }
            // Le bout partiel du dernier kilomètre n'a pas de split : on lui prête l'allure
            // moyenne des kilomètres mesurés. Lui donner « ce qui reste de la durée » serait
            // circulaire — c'est justement la durée qu'on recale juste en dessous.
            return tempsDesSplits + (tempsDesSplits / metresDesSplits) * (x - metresDesSplits)
        }

        let total = brut(metresTotaux)
        guard total > 0 else { return secondesTotales * d / metresTotaux }

        // LE RECALAGE, ET C'EST LUI QUI REND LA COURBE EXACTE AUX DEUX BOUTS.
        //
        // Les splits donnent la FORME de l'allure — vite ici, lent dans la côte — mais leur somme
        // ne tombe pas sur la durée enregistrée : chacun est arrondi à la seconde, et la durée
        // compte aussi les arrêts, que les splits ignorent. Sur un dix kilomètres pile, les dix
        // splits couvrent toute la distance : sans facteur, le chronomètre finissait à 47:00 pour
        // une sortie de 50:00, et la dernière image sautait de trois minutes d'un coup.
        return min(secondesTotales, brut(d) * secondesTotales / total)
    }

    // MARK: Le dénivelé

    /// Le dénivelé positif accumulé à chaque point, ou `nil` quand il n'y a pas de quoi le dire.
    ///
    /// Le même calcul que partout — `ElevationGain`, avec sa bande morte et son lissage — mais
    /// relevé à chaque pas au lieu d'une seule fois à la fin. Le seuil de dix altitudes connues
    /// est celui de `ElevationGain.rejoue` : en dessous, le chiffre qui sortirait serait un autre
    /// chiffre faux, pas une approximation.
    static func denivelesCumules(_ route: [RunRecord.RoutePoint],
                                 intervalleSecondes: Double) -> [Double]? {
        guard intervalleSecondes > 0 else { return nil }
        let connues: Int = route.reduce(0) { $0 + ($1.altitude == nil ? 0 : 1) }
        guard connues >= ElevationGain.minimumPourRejouer else { return nil }

        var calcul = ElevationGain()
        var horloge = Date(timeIntervalSince1970: 0)
        var cumul: [Double] = []
        cumul.reserveCapacity(route.count)
        for point in route {
            horloge = horloge.addingTimeInterval(intervalleSecondes)
            if let altitude = point.altitude {
                calcul.ajoute(altitude: altitude, precisionVerticale: 0, instant: horloge)
            }
            cumul.append(calcul.metres)
        }
        return cumul
    }

    // MARK: Le déroulé

    /// Le déroulé image par image.
    ///
    /// `teteRogneeM` est la distance entre le départ réel et le premier point dessiné : c'est elle
    /// qui fait que le compteur de kilomètres dit où la coureuse était, et non où le trait commence.
    static func deroule(routeRognee: [RunRecord.RoutePoint],
                        teteRogneeM: Double,
                        splits: [Double],
                        metresTotaux: Double,
                        secondesTotales: Double,
                        denivelePositifTotalM: Double,
                        images: Int) -> [Instant] {
        guard routeRognee.count > 1, images >= 2, metresTotaux > 0, secondesTotales > 0 else { return [] }

        let cumul = distancesCumulees(routeRognee)
        let deniveles = denivelesCumules(routeRognee,
                                         intervalleSecondes: secondesTotales / Double(routeRognee.count))
        // Le temps de course atteint à chaque point du tracé dessiné.
        let instantsDesPoints = cumul.map {
            secondes(aMetres: teteRogneeM + $0, splits: splits,
                     metresTotaux: metresTotaux, secondesTotales: secondesTotales)
        }

        var instants: [Instant] = []
        instants.reserveCapacity(images)
        var point = 1
        for f in 0..<images {
            let t = secondesTotales * Double(f) / Double(images - 1)
            // Le curseur ne revient jamais en arrière : il avance tant que le point suivant est
            // déjà passé. Une recherche par image coûterait `images × points` comparaisons pour
            // le même résultat.
            while point < routeRognee.count, instantsDesPoints[point] <= t { point += 1 }
            instants.append(Instant(
                pointsDessines: point,
                metres: teteRogneeM + cumul[point - 1],
                secondes: t,
                denivelePositifM: deniveles?[point - 1]
            ))
        }

        // La dernière image porte les chiffres de la COURSE, pas ceux du tracé rogné.
        instants[instants.count - 1] = Instant(
            pointsDessines: routeRognee.count,
            metres: metresTotaux,
            secondes: secondesTotales,
            // Toujours le chiffre enregistré, même quand les images précédentes n'en montraient
            // aucun : c'est la valeur de la course, et la dernière image est faite pour la dire.
            denivelePositifM: denivelePositifTotalM
        )
        return instants
    }

    // MARK: La porte d'entrée

    /// Le déroulé d'une sortie, ou `nil` quand cette sortie ne doit pas donner de vidéo.
    ///
    /// Les trois refus, et ils sont tous délibérés : pas de tracé (une sortie saisie à la main, un
    /// tapis de course), un tracé qui ne survit pas au rognage de confidentialité, ou une durée
    /// nulle. Mieux vaut pas de bouton qu'une vidéo d'un trait de trois points.
    static func pour(_ run: RunRecord, images: Int? = nil) -> Rendu? {
        guard run.durationSeconds > 0, run.distanceKm > 0 else { return nil }
        // LA MÊME PORTE QUE LE PARTAGE. `shareablePayload` applique le rognage ET la longueur
        // minimale ; `sharingBounds` relit la même coupe pour dire où elle commence. Aucune des
        // deux règles n'est réécrite ici.
        guard let payload = RouteGeometry.shareablePayload(run.route),
              let bornes = RouteGeometry.sharingBounds(run.route)
        else { return nil }

        let tete = RouteGeometry.lengthMeters(Array(run.route[0...bornes.start]))
        let splits = run.splits.compactMap(PaceModel.parseSecPerKm)
        let instants = deroule(routeRognee: payload.points,
                               teteRogneeM: tete,
                               splits: splits,
                               metresTotaux: run.distanceKm * 1000,
                               secondesTotales: Double(run.durationSeconds),
                               denivelePositifTotalM: Double(run.elevationGainM),
                               images: images ?? imagesParDefaut)
        guard !instants.isEmpty else { return nil }
        return Rendu(route: payload.points, instants: instants)
    }
}
