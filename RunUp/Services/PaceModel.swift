import Foundation

/// Real training paces derived from what's already collected at onboarding (target race time,
/// best recent performance, or declared level) — replaces the fixed pace/zone literals every
/// session archetype used to carry regardless of who was training. Deliberately simple (a
/// threshold-pace anchor + fixed percentage offsets per zone, in the spirit of standard
/// recreational-running pace calculators) rather than a full physiological model — this app has
/// no lab test, just a questionnaire, and a plausible estimate beats the same 3 fixed numbers for
/// every runner.
enum PaceModel {
    struct Zones {
        var easy: String       // Z2 — footings, long runs
        var marathon: String   // Z2-3 — allure semi-longue / rythme course longue distance
        var threshold: String  // Z3 — tempo / seuil
        var interval: String   // Z4 — fractionné / VMA
        /// Raw seconds/km behind `easy` — kept alongside the formatted string so
        /// `AdaptivePlanEngine` can compute a realistic long-run duration from a target distance
        /// without re-parsing the "M:SS" text.
        var easySecPerKm: Double
        /// Raw seconds/km behind `threshold` — exposé pour les écrans qui ont besoin d'un
        /// nombre d'ancrage plutôt que du texte, et pour les prédictions de temps de course.
        var thresholdSecPerKm: Double
        /// L'indice de Daniels dont les quatre allures ci-dessus découlent.
        ///
        /// Exposé pour que les prédictions de temps de course des statistiques repartent du MÊME
        /// nombre que le plan, au lieu d'une seconde formule. Deux méthodes de prédiction dans la
        /// même app finissent toujours par s'écarter, et c'est toujours sur l'écran qui les montre
        /// côte à côte que ça se voit.
        var vdot: Double
    }

    /// Les quatre allures du plan, par la méthode de Jack Daniels — voir `Vdot`.
    ///
    /// # CE QUI A CHANGÉ, ET POURQUOI
    ///
    /// Ces quatre allures étaient des POURCENTAGES FIXES d'une allure d'ancrage : × 1,20, × 1,08,
    /// × 1,00, × 0,87. Confrontés à la table publiée de Daniels, trois des quatre étaient faux —
    /// le footing de 18 à 25 s/km trop vite à tous les niveaux, la VMA à l'allure du MILE au lieu
    /// de celle d'un intervalle de trois à cinq minutes, le seuil légèrement trop rapide. Seul le
    /// marathon, × 1,08, était juste.
    ///
    /// Et aucun coefficient fixe ne pouvait l'être : les rapports de Daniels varient avec le
    /// niveau. Les mesures, les fractions de VO2max et la façon dont elles ont été retrouvées sont
    /// dans l'en-tête de `Vdot`.
    ///
    /// # LES PLANS DÉJÀ EN COURS
    ///
    /// Rien n'est réécrit sous les pieds de personne : une séance porte son allure en texte, posée
    /// à la génération de la semaine. Les nouvelles allures paraissent donc à la prochaine
    /// régénération — un changement de réglage, ou le lundi suivant — et la semaine commencée
    /// reste celle qu'on a sous les yeux. C'est la bonne bascule, et c'est aussi la seule qui ne
    /// change pas une séance entre le moment où on la lit et le moment où on la court.
    static func zones(for profile: UserProfile) -> Zones {
        let vdot = referenceVdot(for: profile)
        let seuil = Vdot.allure(vdot: vdot, fraction: Vdot.Fraction.seuil)
        let footing = Vdot.allure(vdot: vdot, fraction: Vdot.Fraction.footing)
        return Zones(
            easy: paceText(footing),
            // L'allure marathon de Daniels est l'allure du marathon PRÉDIT, et non une fraction
            // fixe de VO2max : la fraction qu'elle implique dérive de 80,5 à 82,5 % le long de la
            // table. La calculer comme une course de 42,195 km redonne la table à un demi-seconde
            // près, là où une fraction fixe se tromperait de trois secondes au kilomètre.
            marathon: paceText(Vdot.allureDeCourse(vdot: vdot, km: 42.195)),
            threshold: paceText(seuil),
            interval: paceText(Vdot.allure(vdot: vdot, fraction: Vdot.Fraction.intervalle)),
            easySecPerKm: footing,
            thresholdSecPerKm: seuil,
            vdot: vdot
        )
    }

    /// Projette une allure connue sur une autre distance.
    ///
    /// # RIEGEL N'EST PLUS LA PREMIÈRE RÉPONSE
    ///
    /// Cette fonction appliquait la formule de Riegel, `t₂ = t₁ · (d₂/d₁)^1,06`. L'exposant 1,06 a
    /// été ajusté par Peter Riegel sur des RECORDS DU MONDE (« Athletic Records and Human
    /// Endurance », *American Scientist* 69(3), 1981) ; c'était un travail descriptif, pas un
    /// prédicteur individuel, et il surestime le marathon de quelqu'un qui court pour le plaisir.
    ///
    /// Le plan, lui, calcule désormais ses allures par Daniels, qui prédit un temps de course pour
    /// n'importe quelle distance de sa plage. Garder Riegel ici aurait laissé DEUX méthodes de
    /// prédiction dans la même app, sur deux écrans voisins — et le même reproche que le dépôt
    /// s'adresse partout ailleurs sur la duplication d'une vérité.
    ///
    /// Daniels passe donc en premier : la performance de référence donne un VDOT, le VDOT donne le
    /// temps sur la distance visée. Riegel reste le repli pour ce que la méthode ne couvre pas —
    /// en dessous de 1 500 m, au-delà du marathon — où un nombre approximatif vaut mieux que rien,
    /// puisque l'appelant affiche une prédiction et non une consigne d'entraînement.
    static func projectedPace(fromSecPerKm refSecPerKm: Double, fromKm refKm: Double, toKm targetKm: Double) -> Double {
        guard refKm > 0, targetKm > 0 else { return refSecPerKm }
        // LE VDOT **BRUT**, ET PAS LE BORNÉ. Un plan a besoin d'un ancrage même pour une saisie
        // extravagante ; une prédiction, non. Avec le borné, une référence hors plage ressortait
        // ramenée au plancher, et la prédiction devenait un chiffre faux affiché avec aplomb —
        // sur l'écran précis où quelqu'un décide de viser un marathon ou d'y renoncer.
        if let brut = Vdot.depuisPerformanceBrut(km: refKm, secondes: refSecPerKm * refKm),
           brut >= Vdot.vdotMin, brut <= Vdot.vdotMax,
           targetKm >= Vdot.kmMin, targetKm <= Vdot.kmMax {
            return Vdot.allureDeCourse(vdot: brut, km: targetKm)
        }
        let refTotalSeconds = refSecPerKm * refKm
        let projectedTotalSeconds = refTotalSeconds * pow(targetKm / refKm, 1.06)
        return projectedTotalSeconds / targetKm
    }

    /// Exposed so `StatsView` can compare a real predicted race time against the user's actual
    /// target — same parsing `referenceVdot` uses internally.
    static func parseChronoSeconds(_ text: String, distance: RaceDistance?) -> Double? {
        parseChrono(text, distance: distance)
    }

    static func formatDuration(_ seconds: Double) -> String {
        TimeFormat.horloge(seconds)
    }

    /// A `RunRecord.avgPace` string ("m:ss") → seconds/km — shared by every screen that averages
    /// or compares real per-run paces (`StatsView`, `WeeklyRecapView`) instead of each keeping its
    /// own copy of the same split.
    static func parseSecPerKm(_ pace: String) -> Double? {
        let parts = pace.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }

    /// Total elapsed time across possibly many runs, e.g. "1h23" or "45 min" — distinct from
    /// `formatDuration` above, which formats a single pace/split as "m:ss". Shared by `StatsView`'s
    /// and `WeeklyRecapView`'s "temps total" tiles.
    static func formatTotalDuration(_ seconds: Int) -> String {
        TimeFormat.duree(seconds)
    }

    /// Le VDOT de cette personne — l'indice dont les quatre allures découlent.
    ///
    /// # L'ORDRE A CHANGÉ, ET C'EST LE FOND DE L'AFFAIRE
    ///
    /// Le temps visé passait en premier. C'est une AMBITION, pas une capacité : quelqu'un qui
    /// vise 45 min au 10 km et en court 58 recevait un plan entier calé sur 45 — footings trop
    /// rapides, seuil hors de portée, fractionné intenable. Le plan ne l'emmenait pas vers son
    /// objectif, il supposait qu'elle y était déjà.
    ///
    /// L'ordre est désormais celui d'un entraîneur : ce qu'elle a FAIT, puis ce qu'elle DIT
    /// faire, puis seulement ce qu'elle VISE, puis ce qu'elle se déclare.
    ///
    ///   1. une performance récente réelle — une distance et un temps, donc projetable ;
    ///   2. l'allure de footing déclarée, le repli de ceux qui n'ont pas de chrono à donner
    ///      (voir `AllureFooting`) — et ils sont la majorité ;
    ///   3. le temps visé, pour une course, quand on ne sait rien d'autre : il reste une
    ///      indication, et il vaut mieux que la quatrième ligne ;
    ///   4. les trois constantes du niveau déclaré, qui décidaient jusqu'ici du plan de tout le
    ///      monde sauf des coureurs sur route.
    private static func referenceVdot(for profile: UserProfile) -> Double {
        if let recent = profile.bestRecentPerf, let parsed = parseFreeformPerf(recent),
           let vdot = Vdot.depuisPerformance(km: parsed.km, secondes: parsed.seconds) {
            return vdot
        }
        // L'allure de footing est une allure FACILE : son VDOT se lit donc à la fraction du
        // footing, dans le même sens que `zones` l'applique pour redescendre. Une seule fraction
        // pour les deux sens, qui ne peut donc pas diverger.
        //
        // L'ancien code faisait l'aller-retour avec `/ 1.20`, le coefficient du footing. Il se
        // trompait des deux côtés à la fois : le rapport footing/seuil de Daniels vaut 1,25 à
        // 1,27, donc d'une allure de footing déclarée on déduisait un seuil 14 s/km trop LENT,
        // pendant que d'un chrono on déduisait un footing 25 s/km trop RAPIDE. Deux chemins
        // d'entrée, deux erreurs de signe opposé, et rien qui les rapproche.
        if let allure = AllureFooting(rawValue: profile.allureFooting ?? "")?.secondesParKm,
           let vdot = Vdot.depuisAllure(secondesParKm: allure, fraction: Vdot.Fraction.footing) {
            return vdot
        }
        // `== .race` ET PAS « tout objectif qui a un chrono ». C'est volontaire, et c'est le genre
        // de condition qu'on « corrige » en croyant bien faire : un temps d'ultra n'est pas une
        // performance au sens de Daniels. Cent kilomètres en vingt heures lui donnent un VDOT de
        // 14 — un ultra se finit en marchant les montées, ce qui ne dit rien de la vitesse de
        // quiconque. `Vdot.depuisPerformance` refuse donc tout ce qui dépasse le marathon, et un
        // objectif d'ultra retombe sur la meilleure perf récente, puis sur le niveau déclaré.
        if profile.goalId == .race,
           let chrono = profile.raceChrono,
           let km = profile.effectiveRaceDistanceKm,
           let totalSeconds = parseChrono(chrono, distance: profile.raceDistance),
           let vdot = Vdot.depuisPerformance(km: km, secondes: totalSeconds) {
            return vdot
        }
        // LE NIVEAU DÉCLARÉ : LA TRANCHE DE FOOTING QU'ELLE AURAIT PROBABLEMENT COCHÉE.
        //
        // Plus aucun VDOT en dur ici. Les trois anciens — 36,34 / 43,61 / 53,94 — supposaient des
        // footings de 6:54, 5:58 et 5:02 au kilomètre, alors que l'app propose elle-même « plus de
        // 7 min/km » : une débutante qui répondait « je ne sais pas » recevait donc un plan PLUS
        // RAPIDE que si elle avait coché la tranche la plus lente. Le raisonnement complet et la
        // table avant/après sont sur `ExperienceLevel.allureDeFootingSupposee`.
        //
        // Et c'est le MÊME appel que le chemin de l'allure déclarée, trois lignes plus haut, sur
        // la même valeur : les deux ne peuvent plus diverger.
        if let allure = profile.level.allureDeFootingSupposee.secondesParKm,
           let vdot = Vdot.depuisAllure(secondesParKm: allure, fraction: Vdot.Fraction.footing) {
            return vdot
        }
        // `secondesParKm` ne rend `nil` que pour `jeNeSaisPas`, et aucun niveau ne la désigne —
        // un cas de test le vérifie. Mais un repli doit rendre un nombre, et celui-ci est le plus
        // bas de l'échelle, donc le plus prudent si quelqu'un ajoute un niveau sans allure.
        return Vdot.vdotMin
    }

    /// `chronoPresets` use "MM:SS" for 5K/10K but "H:MM" for semi/marathon (the presets
    /// themselves are already in whichever format fits the distance — see `GoalType.swift`). A
    /// custom chrono ("Mon propre temps") is free text, though, and its own placeholder
    /// (`RaceDetailsStepView`'s "Ex. 1:52:00") suggests full H:MM:SS — which used to fail to parse
    /// entirely (the old code only accepted exactly 2 colon-separated parts) and silently fall
    /// back to a generic level-based pace, regardless of the real chrono she'd just typed.
    private static func parseChrono(_ text: String, distance: RaceDistance?) -> Double? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 3:
            return Double(parts[0] * 3600 + parts[1] * 60 + parts[2])
        case 2:
            switch distance {
            case .k5, .k10: return Double(parts[0] * 60 + parts[1])
            // EN ULTRA, « 13:00 » EST TREIZE HEURES. Le repli ci-dessous tranche sur
            // `parts[0] >= 10` → des minutes, ce qui était juste tant qu'aucun format de la liste
            // ne dépassait dix heures. Depuis les quatre formats d'ultra, il lisait « 13:00 »,
            // « 20:00 », « 24:00 », « 36:00 », « 44:00 » — les deux tiers des temps proposés —
            // comme des minutes, donc une allure de huit secondes au kilomètre sur cent bornes.
            case .ultra50, .ultra80, .ultra100, .ultra100M:
                return Double(parts[0] * 3600 + parts[1] * 60)
            default:
                // "1:45" for a semi/marathon is H:MM — but a custom distance's "45:00" is MM:SS,
                // and the old blanket H:MM read that as 45 HOURS (→ absurd "162:00 /km" plans).
                // No real race chrono here starts at 10+ hours, so a first part ≥ 10 is minutes.
                return parts[0] >= 10 ? Double(parts[0] * 60 + parts[1]) : Double(parts[0] * 3600 + parts[1] * 60)
            }
        default:
            return nil
        }
    }

    /// Lecture au mieux d'une « meilleure perf récente » écrite à la main.
    ///
    /// # L'EXEMPLE AFFICHÉ PAR L'APP NE PASSAIT PAS SON PROPRE ANALYSEUR
    ///
    /// Le champ suggère « Ex. 10 km en 52 min ». L'analyseur, lui, exigeait un temps à DEUX
    /// POINTS — `\d{1,2}:\d{2}` — donc « 52 min » était rejeté, en silence, et la réponse
    /// tombait dans l'oubli. Quelqu'un qui recopiait l'exemple mot pour mot n'obtenait rien.
    ///
    /// Ça restait discret tant que ce champ n'était qu'un repli sur un objectif sur neuf. Il est
    /// devenu la PREMIÈRE source de toutes les allures du plan, pour tout le monde : une lecture
    /// qui rate est désormais un plan entier recalé sur une constante de niveau.
    ///
    /// Deux autres manières d'écrire la même chose échouaient aussi, et toutes les deux sont ce
    /// que le clavier donne naturellement :
    ///
    ///   • « 10,5 km » — la VIRGULE décimale française. Le filtre ne gardait que le point, donc
    ///     « 10,5 » devenait « 105 », et un dix-kilomètres se lisait comme un cent-cinq ;
    ///   • « 6 miles » — l'app est en anglais aussi, et personne aux États-Unis n'écrit en km.
    ///
    /// La prudence d'origine reste : sans une distance ET un temps clairement reconnus, on rend
    /// `nil` et le plan retombe sur son repli. Mieux vaut ne pas lire que mal lire — c'est de ce
    /// nombre que descendent les quatre zones.
    static func parseFreeformPerf(_ text: String) -> (km: Double, seconds: Double)? {
        let lowered = text.lowercased().replacingOccurrences(of: ",", with: ".")

        // ── La distance ──────────────────────────────────────────────────────────────────
        guard let distanceRange = lowered.range(of: #"\d+(\.\d+)?\s*(km|k\b|miles?\b|mi\b)"#,
                                                options: .regularExpression) else { return nil }
        let morceau = String(lowered[distanceRange])
        guard let nombre = Double(morceau.filter { $0.isNumber || $0 == "." }), nombre > 0 else { return nil }
        // `\bmi\b` et `miles?` ne peuvent pas mordre sur « min » — la frontière de mot tombe
        // avant le « n » — donc « 52 min » ne sera jamais pris pour 52 miles.
        let enMiles = morceau.contains("mi")
        let km = enMiles ? nombre * 1.609344 : nombre

        // ── Le temps, cherché APRÈS avoir retiré la distance ─────────────────────────────
        //
        // Sans ce retrait, « 10 km en 52 min » offrirait d'abord le « 10 » de la distance à la
        // recherche d'un nombre de minutes, et rendrait dix minutes au lieu de cinquante-deux.
        // Une copie avec la distance remplacée, plutôt qu'une suppression sur place : un indice
        // de chaîne appartient à l'instance qui l'a produit, et le réutiliser pour muter une
        // autre instance est le genre de construction qui marche jusqu'au jour où elle ne marche
        // plus.
        let reste = lowered.replacingCharacters(in: distanceRange, with: " ")

        if let t = reste.range(of: #"\d{1,2}:\d{2}(:\d{2})?"#, options: .regularExpression) {
            let parts = reste[t].split(separator: ":").compactMap { Int($0) }
            switch parts.count {
            // « 52:00 » sur une perf récente se lit mm:ss, pas hh:mm — c'est un chrono de
            // course, et personne n'écrit une sortie de cinquante-deux heures.
            case 2: return (km, Double(parts[0] * 60 + parts[1]))
            case 3: return (km, Double(parts[0] * 3600 + parts[1] * 60 + parts[2]))
            default: return nil
            }
        }
        // « 1h05 », « 1 h 05 », « 1hr05 », « 1h » — les minutes sont facultatives.
        if let t = reste.range(of: #"\d{1,2}\s*h(r|rs|eures?|eure)?\s*\d{0,2}"#, options: .regularExpression) {
            let nombres = String(reste[t]).split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            guard let heures = nombres.first else { return nil }
            let minutes = nombres.count > 1 ? nombres[1] : 0
            return (km, Double(heures * 3600 + minutes * 60))
        }
        // « 52 min », « 52min », « 52 minutes », « 52 mn » — et l'exemple que l'app affiche.
        if let t = reste.range(of: #"\d{1,3}\s*(min|minutes?|mn)\b"#, options: .regularExpression) {
            guard let minutes = Int(String(reste[t]).filter(\.isNumber)) else { return nil }
            return (km, Double(minutes * 60))
        }
        return nil
    }

    /// « 6:26 » à partir de secondes par kilomètre. LE seul formateur d'allure de l'app.
    ///
    /// Rendue accessible hors de ce fichier plutôt que recopiée : l'accueil affiche aussi une
    /// allure moyenne, et deux formateurs finissent toujours par diverger sur l'arrondi — une
    /// seconde d'écart entre deux écrans qui montrent la même course.
    ///
    /// Ce qui était déjà arrivé, et pendant longtemps. `AdaptivePlanEngine.fmt` faisait le même
    /// travail en TRONQUANT là où celle-ci arrondit : à 299,6 s/km, le plan annonçait « 5:00 »
    /// et la ligne d'historique de la course écrite dessus « 4:59 ». Les deux chiffres étaient
    /// le même, calculés deux fois. `fmt` n'existe plus ; ses six appels passent ici.
    ///
    /// Comme elle, cette fonction ne passe jamais aux heures : c'est une allure au kilomètre, pas
    /// une durée. Un temps total se formate avec `formatDuration`, sans quoi une sortie longue de
    /// 95 minutes s'écrit « 95:00 » au lieu de « 1:35:00 ».
    static func paceText(_ secondsPerKm: Double) -> String {
        TimeFormat.allure(secondesParKm: secondsPerKm)
    }
}
