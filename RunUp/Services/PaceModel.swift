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
        /// Raw seconds/km behind `threshold` — the same anchor `referenceThresholdPace` computed,
        /// exposed so `StatsView` can project real race-time predictions from it too (via Riegel,
        /// same as here) when there's no run history yet to predict from instead.
        var thresholdSecPerKm: Double
    }

    static func zones(for profile: UserProfile) -> Zones {
        let thresholdSecPerKm = referenceThresholdPace(for: profile)
        return Zones(
            easy: paceText(thresholdSecPerKm * 1.20),
            marathon: paceText(thresholdSecPerKm * 1.08),
            threshold: paceText(thresholdSecPerKm * 1.0),
            // 13% faster than threshold, not the previous 8%. vVO2max — what "VMA" actually means —
            // sits around 3-5K race pace, typically 12-18% faster than a threshold/10K pace. At 8%
            // the "Fractionné VMA" session was effectively a second tempo run at threshold effort
            // and never delivered the aerobic-power stimulus the session exists to produce.
            interval: paceText(thresholdSecPerKm * 0.87),
            easySecPerKm: thresholdSecPerKm * 1.20,
            thresholdSecPerKm: thresholdSecPerKm
        )
    }

    /// Projects a known pace at one distance onto any other distance via Riegel's formula —
    /// exposed for `StatsView`'s race-time predictions, reusing the same model that seeds the
    /// plan's own paces instead of a second, disconnected formula.
    static func projectedPace(fromSecPerKm refSecPerKm: Double, fromKm refKm: Double, toKm targetKm: Double) -> Double {
        guard refKm > 0, targetKm > 0 else { return refSecPerKm }
        let refTotalSeconds = refSecPerKm * refKm
        let projectedTotalSeconds = refTotalSeconds * pow(targetKm / refKm, 1.06)
        return projectedTotalSeconds / targetKm
    }

    /// Exposed so `StatsView` can compare a real predicted race time against the user's actual
    /// target — same parsing `referenceThresholdPace` uses internally.
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

    /// Seconds-per-km at "threshold" — the anchor every other zone is a percentage offset of.
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
    private static func referenceThresholdPace(for profile: UserProfile) -> Double {
        if let recent = profile.bestRecentPerf, let parsed = parseFreeformPerf(recent), parsed.seconds > 0 {
            return thresholdPace(fromPerformanceSeconds: parsed.seconds, km: parsed.km)
        }
        // L'allure de footing est une allure FACILE : le seuil se trouve 20 % plus vite, par le
        // même rapport que `zones` applique dans l'autre sens pour redescendre du seuil au
        // footing. Un seul coefficient pour les deux sens, qui ne peut donc pas diverger.
        if let allure = AllureFooting(rawValue: profile.allureFooting ?? "")?.secondesParKm {
            return min(540, max(150, allure / 1.20))
        }
        // `== .race` ET PAS « tout objectif qui a un chrono ». C'est volontaire, et c'est le genre
        // de condition qu'on « corrige » en croyant bien faire : un temps d'ultra passé dans
        // Riegel donne une absurdité. Cent kilomètres en vingt heures se projette sur un 10 km en
        // 1 h 45, soit une allure seuil de 9:00/km — et toutes les zones du plan en découleraient.
        // Riegel vaut d'un 5 km à un marathon, pas d'un 100 miles à un 10 km : un ultra se finit
        // en marchant les montées, ce qui ne dit rien de la vitesse de quiconque. Un objectif
        // d'ultra garde donc l'ancrage par meilleure perf récente, puis par niveau déclaré.
        if profile.goalId == .race,
           let chrono = profile.raceChrono,
           let km = profile.effectiveRaceDistanceKm,
           let totalSeconds = parseChrono(chrono, distance: profile.raceDistance),
           totalSeconds > 0 {
            return thresholdPace(fromPerformanceSeconds: totalSeconds, km: km)
        }
        switch profile.level {
        case .debutante: return 330      // ≈ 5:30/km reference
        case .intermediaire: return 285  // ≈ 4:45/km
        case .confirmee: return 240      // ≈ 4:00/km
        }
    }

    /// Projects any real performance onto a 10K-equivalent time via Riegel's formula (a standard,
    /// widely-used race-time conversion), then treats that 10K pace as the threshold-pace anchor
    /// — a common approximation in recreational pace calculators.
    private static func thresholdPace(fromPerformanceSeconds seconds: Double, km: Double) -> Double {
        guard km > 0, seconds > 0 else { return 285 }
        let projected10k = seconds * pow(10.0 / km, 1.06)
        // Clamped to a plausible human range (≈2:30/km world-class down to ≈9:00/km walk-run) —
        // a freeform "meilleure perf récente" entry (typos, a wildly mismatched distance/time
        // pair) could otherwise project an absurd pace that then seeds every zone in the plan.
        return min(540, max(150, projected10k / 10.0))
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
