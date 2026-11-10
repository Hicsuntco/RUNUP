import Foundation

/// Les allures d'entraînement, par la méthode de Jack Daniels.
///
/// # POURQUOI CE FICHIER EXISTE
///
/// `PaceModel` calculait les quatre allures du plan comme des POURCENTAGES FIXES d'une allure
/// d'ancrage : footing × 1,20, marathon × 1,08, seuil × 1,00, VMA × 0,87. Son propre commentaire
/// en reconnaissait l'origine : « deliberately simple […] in the spirit of standard recreational
/// running pace calculators ». Autrement dit, aucune source. C'est l'item B1 de `PHASE2.md`, et
/// c'est le fond du produit : un plan dont les allures ne se défendent pas n'est pas un plan
/// d'entraînement.
///
/// Confrontés à la table publiée de Daniels, trois des quatre coefficients étaient faux, et le
/// quatrième était juste. Les mesures sont dans `PROGRESS.md` ; en deux lignes :
///
///   · le FOOTING, × 1,20, tombait au bord le plus rapide de la plage facile de Daniels pour un
///     VDOT de 30, et PASSAIT DEVANT pour tout le monde au-dessus — 18 à 25 s/km trop vite, à
///     tous les niveaux, sur l'allure qui porte 70 à 80 % du volume d'une semaine ;
///   · la VMA, × 0,87, n'était pas l'allure d'intervalle de Daniels (0,925 à 0,957 de l'allure
///     du 10 km) mais son allure de RÉPÉTITION (0,872 à 0,893) — l'allure du mile, tenable deux
///     cents mètres, prescrite pour des répétitions de trois à cinq minutes ;
///   · le SEUIL, posé égal à l'allure du 10 km, est 0,3 à 3,7 % trop rapide ;
///   · le MARATHON, × 1,08, est juste : Daniels donne 1,076 à 1,094.
///
/// Et surtout : AUCUN COEFFICIENT FIXE NE PEUT ÊTRE JUSTE, parce que les rapports de Daniels
/// varient avec le niveau. Le rapport footing/10 km passe de 1,25 à 1,27, le rapport VMA/10 km de
/// 0,925 à 0,957 entre un VDOT de 30 et un VDOT de 60. Un seul nombre ne peut pas couvrir la
/// plage, quel qu'il soit.
///
/// # LA MÉTHODE, ET LE PEU QU'ELLE DEMANDE
///
/// Jack Daniels et Jimmy Gilbert, *Oxygen Power* (1979), deux équations :
///
///   · le coût en oxygène d'une vitesse de course, `coutEnOxygene(_:)` ;
///   · la fraction de VO2max qu'on soutient pendant une durée donnée,
///     `fractionSoutenable(minutes:)` — elle décroît avec la durée.
///
/// Leur quotient sur une performance réelle donne le VDOT, l'indice de Daniels. Et en sens
/// inverse, un VDOT et une fraction donnent une allure. Les allures d'entraînement deviennent
/// alors des fractions NOMMÉES de VO2max, et non des coefficients.
///
/// # LES FRACTIONS NE SONT PAS RECOPIÉES D'UN BLOG, ELLES SONT MESURÉES
///
/// Trois sites donnent trois valeurs différentes pour la même allure — pour le seuil, 83-88 %,
/// 86-92 % et 88-92 %, et l'un des trois confond %VO2max et %FCmax. Les recopier aurait été
/// exactement ce que la règle 8 interdit.
///
/// Elles sont donc RETROUVÉES depuis la table publiée : pour chaque allure et chaque VDOT de la
/// table, `coutEnOxygene(allure) / VDOT` donne la fraction que cette allure implique. Le résultat
/// est constant à un dixième de point sur tout l'intervalle VDOT 30-60, ce qui n'arrive pas par
/// hasard :
///
///   footing, bord lent    62,0 %   (61,9 - 62,1)
///   footing, bord rapide  70,0 %   (69,9 - 70,1)
///   seuil                 88,0 %   (87,8 - 88,1)
///   intervalle            97,5 %   (97,3 - 97,7)
///
/// L'allure marathon, elle, n'est PAS une fraction fixe : la fraction qu'elle implique dérive de
/// 80,5 à 82,5 %. C'est normal, et la table le dit — l'allure marathon de Daniels est l'allure du
/// marathon PRÉDIT. Elle se calcule donc comme telle, par `allureDeCourse(vdot:km:)`, ce qui
/// redonne la table à un demi-seconde près au lieu de trois secondes.
///
/// `VdotTests` vérifie que cette inversion reproduit la table publiée, valeur par valeur.
///
/// # CE QUE CE MODÈLE NE SAIT PAS FAIRE
///
/// Il ne vaut pas en ULTRA. Cent kilomètres en vingt heures lui donnent un VDOT de 14 — celui de
/// quelqu'un qui MARCHE, alors que finir cent kilomètres demande d'être solide. C'est que l'on
/// finit un ultra en marchant les montées, et que la durée totale ne dit donc rien de la vitesse
/// de personne. La méthode de Daniels couvre du 1 500 m au marathon, et `depuisPerformance` refuse
/// donc par la DISTANCE tout ce qui sort de cette plage — pas par la valeur obtenue, qui tombe ici
/// dans la plage plausible et serait acceptée sans cette garde.
///
/// Et il ne mesure pas une VO2max. Le VDOT est un indice de PERFORMANCE : deux personnes de même
/// VDOT courent le même 10 km sans avoir la même physiologie. C'est précisément ce qui le rend
/// utilisable ici, où l'on n'a qu'un questionnaire et pas de laboratoire.
enum Vdot {

    // MARK: - Les deux équations de Daniels et Gilbert

    /// Le coût en oxygène d'une vitesse de course, en ml/kg/min.
    ///
    /// `VO2 = -4,60 + 0,182258 · v + 0,000104 · v²`, v en mètres par minute.
    static func coutEnOxygene(vitesseMetresParMinute v: Double) -> Double {
        -4.60 + 0.182258 * v + 0.000104 * v * v
    }

    /// La fraction de VO2max qu'on soutient pendant une course de `minutes`.
    ///
    /// `%VO2max = 0,8 + 0,1894393 · e^(-0,012778 t) + 0,2989558 · e^(-0,1932605 t)`, t en minutes.
    ///
    /// Elle décroît avec la durée, et c'est tout l'intérêt : c'est elle qui fait qu'une même
    /// personne court son 5 km plus vite que son marathon, sans qu'on ait à le poser à la main.
    static func fractionSoutenable(minutes t: Double) -> Double {
        0.8 + 0.1894393 * exp(-0.012778 * t) + 0.2989558 * exp(-0.1932605 * t)
    }

    // MARK: - Les fractions, mesurées sur la table publiée

    /// Les fractions de VO2max des allures d'entraînement.
    ///
    /// Retrouvées depuis la table de Daniels, pas recopiées — voir l'en-tête du fichier. L'allure
    /// marathon n'y est pas : elle n'est pas une fraction fixe, c'est l'allure du marathon prédit.
    enum Fraction {
        /// Le bord LENT de la plage facile. 62,0 % mesuré.
        static let footingLent = 0.620
        /// Le bord RAPIDE de la plage facile. 70,0 % mesuré.
        static let footingRapide = 0.700
        /// Le milieu de la plage facile, pour les écrans qui n'affichent qu'un nombre.
        ///
        /// Le milieu de la FRACTION, pas la moyenne des deux allures : les deux ne diffèrent que
        /// d'une seconde au kilomètre sur tout l'intervalle, et une fraction se nomme.
        static let footing = 0.660
        /// 88,0 % mesuré. Daniels le décrit comme l'allure d'une course d'environ une heure ;
        /// 88,0 % correspond exactement à 67,5 minutes par `fractionSoutenable`, ce qui est la
        /// même chose dite autrement.
        static let seuil = 0.880
        /// 97,5 % mesuré. Pas 100 % : l'allure d'intervalle de Daniels est à peine plus lente que
        /// l'allure du 5 km — 1 à 4 % selon le niveau — et c'est ce qu'on tient trois à cinq
        /// minutes, plusieurs fois.
        static let intervalle = 0.975
    }

    // MARK: - Les bornes

    /// La plage de distances où la méthode vaut : du 1 500 m au marathon.
    ///
    /// Bornes de la table de Daniels elle-même. Hors de là, `depuisPerformance` rend `nil` — un
    /// ultra, un sprint ou une faute de frappe ne doivent pas ancrer un plan entier.
    static let kmMin = 1.5
    static let kmMax = 42.3

    /// La plage de VDOT plausibles. Les deux bornes se nomment.
    ///
    /// # LE PREMIER JET AVAIT TORT DES DEUX CÔTÉS, ET C'ÉTAIT LE MÊME DÉFAUT QU'AILLEURS
    ///
    /// Il posait 25 et 85, sans rien derrière. Un test rouge a montré ce que ça coûtait. Quelqu'un
    /// qui court son 10 km en 1 h 40 — une vraie personne, pas une faute de frappe — a un VDOT de
    /// 17,2. Ramené de force à 25, son plan lui prescrivait des footings à **9:11/km**, c'est-à-dire
    /// PLUS RAPIDES que son allure de course, et lui prédisait un marathon en 5 h 34 là où son
    /// propre 10 km en annonce plus de 7. Un plancher inventé produisait exactement le genre de
    /// mensonge que ce chantier existe pour retirer.
    ///
    /// Et le plafond était trop bas : le record du monde du marathon au moment où ces lignes sont
    /// écrites — 1 h 59 min 30 s, Sabastian Sawe, Londres, 26 avril 2026 — vaut un VDOT de
    /// **86,45**. Une performance humaine réelle était donc rabotée.
    ///
    /// # CE QUE LES DEUX BORNES DISENT MAINTENANT
    ///
    /// Le PLANCHER est la frontière entre marcher et courir. Une marche rapide se tient vers
    /// 12:00/km ; un 10 km à cette allure — deux heures — donne un VDOT de 13,45. Le plancher est
    /// posé juste en dessous pour que cette frontière elle-même reste dedans. Sous ce chiffre, on
    /// ne décrit plus une course : un 10 km en trois heures vaut 7,1, un 5 km en deux heures 3,8.
    ///
    /// Le PLAFOND est posé bien au-dessus du record, et ce n'est pas un oubli : son travail est
    /// d'écarter une faute de frappe, pas de suivre les records. Un 5 km tapé « 8 min » vaut 145,
    /// un marathon tapé « 1 h » vaut 197 — l'écart avec 86 est si large que la valeur exacte du
    /// plafond n'a aucune importance. Le dire évite qu'on vienne le corriger à chaque record, et
    /// évite surtout qu'on l'abaisse en croyant le resserrer.
    static let vdotMin = 13.0
    static let vdotMax = 90.0

    // MARK: - Dans un sens : d'une performance au VDOT

    /// Le VDOT d'une performance, SANS bornage — ou `nil` si la distance sort de la plage de la
    /// méthode.
    ///
    /// Séparé de `depuisPerformance` parce que les deux appelants ne veulent pas la même chose, et
    /// que les confondre a produit un défaut. UN PLAN a besoin d'un point d'ancrage même pour une
    /// saisie extravagante : il vaut mieux un plan borné qu'aucun plan. UNE PRÉDICTION, non — si
    /// la performance de référence sort de ce que le modèle décrit, le borner revient à répondre
    /// avec aplomb à une question qu'on n'a pas comprise.
    static func depuisPerformanceBrut(km: Double, secondes: Double) -> Double? {
        guard km >= kmMin, km <= kmMax, secondes > 0 else { return nil }
        let vitesse = km * 1000 / (secondes / 60)
        let brut = coutEnOxygene(vitesseMetresParMinute: vitesse)
            / fractionSoutenable(minutes: secondes / 60)
        guard brut.isFinite, brut > 0 else { return nil }
        return brut
    }

    /// Le VDOT d'une performance réelle, borné à la plage plausible, ou `nil` si la distance sort
    /// de ce que la méthode couvre.
    ///
    /// `nil` plutôt qu'un repli : c'est l'appelant qui sait quoi faire d'une absence, et un
    /// nombre faux ancrerait les quatre allures d'un plan entier.
    static func depuisPerformance(km: Double, secondes: Double) -> Double? {
        guard let brut = depuisPerformanceBrut(km: km, secondes: secondes) else { return nil }
        return min(vdotMax, max(vdotMin, brut))
    }

    /// Le VDOT qu'implique une allure tenue à une fraction connue de VO2max.
    ///
    /// Le chemin de repli du questionnaire : quelqu'un qui ne donne aucun chrono donne parfois son
    /// allure de footing, qui est une allure facile — donc une fraction connue.
    static func depuisAllure(secondesParKm: Double, fraction: Double) -> Double? {
        guard secondesParKm > 0, fraction > 0 else { return nil }
        let brut = coutEnOxygene(vitesseMetresParMinute: 60000 / secondesParKm) / fraction
        guard brut.isFinite, brut > 0 else { return nil }
        return min(vdotMax, max(vdotMin, brut))
    }

    // MARK: - Dans l'autre : du VDOT à une allure

    /// L'allure, en secondes par kilomètre, qui coûte `fraction` du VDOT donné.
    ///
    /// L'inverse du coût en oxygène, qui est un polynôme du second degré en la vitesse :
    /// `0,000104 v² + 0,182258 v - (4,60 + VDOT · fraction) = 0`. Une seule racine est positive.
    static func allure(vdot: Double, fraction: Double) -> Double {
        let cible = 4.60 + vdot * fraction
        let a = 0.000104, b = 0.182258
        let vitesse = (-b + (b * b + 4 * a * cible).squareRoot()) / (2 * a)
        guard vitesse > 0 else { return 600 }
        return 60000 / vitesse
    }

    /// L'allure de course sur `km`, pour ce VDOT — donc le temps de course prédit.
    ///
    /// Sert à deux choses : l'allure marathon du plan, qui EST l'allure du marathon prédit chez
    /// Daniels, et les prédictions de temps de course des statistiques, qui passaient par Riegel.
    ///
    /// Par dichotomie et non par formule : la durée entre dans `fractionSoutenable`, donc la
    /// vitesse de course est définie implicitement. Soixante itérations sur un intervalle de
    /// 100 à 1 200 s/km laissent une incertitude très inférieure à la seconde, ce qui est
    /// largement sous la précision d'une allure affichée à la seconde près.
    static func allureDeCourse(vdot: Double, km: Double) -> Double {
        guard km > 0 else { return 600 }
        // Les bornes sont nommées par l'ALLURE qu'elles portent, pas par leur valeur : 100 s/km
        // est l'allure la plus rapide envisagée, 1 200 la plus lente. Le premier jet les appelait
        // l'inverse, ce qui rendait les deux lignes de dichotomie illisibles sans les relire trois
        // fois — et une dichotomie qu'on relit trois fois est une dichotomie qu'on finit par
        // inverser.
        var borneRapide = 100.0
        var borneLente = 1200.0
        for _ in 0..<60 {
            let milieu = (borneRapide + borneLente) / 2
            let obtenu = coutEnOxygene(vitesseMetresParMinute: 60000 / milieu)
                / fractionSoutenable(minutes: milieu * km / 60)
            // Plus l'allure est lente, plus le VDOT obtenu est bas : la recherche est monotone
            // sur cet intervalle, ce que `VdotTests` vérifie plutôt que de l'affirmer ici.
            if obtenu > vdot { borneRapide = milieu } else { borneLente = milieu }
        }
        return (borneRapide + borneLente) / 2
    }
}
