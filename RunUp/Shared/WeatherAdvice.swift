import Foundation

/// « Il va pleuvoir ce soir, va courir plutôt ce midi. »
///
/// # CE QUE CE FICHIER EST, ET CE QU'IL N'EST PAS
///
/// Il ne parle à personne. Pas de réseau, pas de WeatherKit, pas de notification : une fonction
/// qui reçoit des prévisions horaires et rend un conseil, ou rien. C'est ce qui la rend testable
/// sans attendre qu'il pleuve — même raison que `WatchRunMetrics` ou `HealthRunImport`, et même
/// forme.
///
/// # LA RÈGLE, ET POURQUOI ELLE EST AUSSI PRUDENTE
///
/// Une notification météo a une seule façon d'échouer, et elle est fatale : crier au loup. Deux
/// « il va pleuvoir » suivis d'une journée sèche, et l'interrupteur est coupé pour toujours. La
/// règle exige donc trois choses ENSEMBLE, et se tait dès qu'une manque :
///
///   1. le créneau habituel est vraiment mauvais — pas « peut-être », une probabilité haute ;
///   2. un autre créneau du même jour est vraiment bon, et l'écart entre les deux est FRANC.
///      Soixante et un pour cent contre cinquante-neuf, ce n'est pas un conseil, c'est du bruit ;
///   3. il reste assez de temps pour changer ses plans.
///
/// Quand il pleut toute la journée, il n'y a rien à conseiller : elle courra sous la pluie ou pas
/// du tout, et lui envoyer un message ne change que son humeur. Le silence est la bonne réponse.
enum WeatherAdvice {

    // MARK: Les créneaux

    /// Les trois moments où l'on court, tels que l'app les propose déjà à l'inscription.
    enum Slot: String, CaseIterable, Equatable {
        case morning, noon, evening

        /// Les heures pleines couvertes, dans le fuseau de l'appareil. Bornes larges plutôt que
        /// justes : quelqu'un qui « court le matin » ne part pas à 7 h 00 pile, et une averse à
        /// 9 h le concerne.
        var heures: ClosedRange<Int> {
            switch self {
            case .morning: return 7...10
            case .noon: return 12...14
            case .evening: return 17...20
            }
        }

        /// Ce que `UserProfile.preferredTimeOfDay` enregistre depuis l'inscription.
        ///
        /// « Ça varie » retombe sur le soir : c'est l'heure du rappel quotidien de l'app, donc le
        /// moment que quelqu'un sans préférence déclarée finit par prendre. Se taire dans ce cas
        /// aurait été l'autre option — mais c'est précisément la personne dont la séance peut
        /// bouger le plus facilement.
        static func from(_ brut: String?) -> Slot {
            switch brut {
            case "morning": return .morning
            case "noon": return .noon
            default: return .evening
            }
        }
    }

    // MARK: Les prévisions

    /// Une heure de prévision. Le strict minimum pour décider — tout le reste est du décor.
    struct Hour: Equatable {
        let date: Date
        /// Probabilité de précipitations, de 0 à 1.
        let precipitationChance: Double
        /// Intensité en millimètres par heure. Zéro avec une probabilité haute décrit un ciel
        /// menaçant qui ne donnera rien : c'est ce qui distingue « il pourrait pleuvoir » de
        /// « il va pleuvoir », et la différence compte quand on demande à quelqu'un de décaler
        /// sa journée.
        let precipitationIntensity: Double
    }

    struct Advice: Equatable {
        let avoid: Slot
        let prefer: Slot
    }

    // MARK: Les seuils

    /// Au-delà, on parle de pluie. En deçà, on se tait.
    static let pluieProbable = 0.6
    /// En deçà, un créneau est sec au point qu'on peut l'annoncer.
    static let creneauSec = 0.25
    /// L'écart minimal entre les deux. Sans lui, la règle conseillerait de déplacer une séance
    /// pour gagner deux points de probabilité.
    static let ecartFranc = 0.35
    /// Une bruine à 0,1 mm/h mouille à peine. En dessous, la probabilité seule ne suffit pas.
    static let bruineMinimale = 0.1
    /// Le préavis : en dessous, le conseil arrive trop tard pour être suivi.
    static let preavisMinimum: TimeInterval = 2 * 3600

    // MARK: La décision

    /// La pluie attendue sur un créneau : la pire heure, pas la moyenne.
    ///
    /// Une averse d'une heure au milieu d'un créneau de quatre le gâche entièrement ; une moyenne
    /// la diluerait jusqu'à la faire disparaître. On court une fois, pas en continu.
    ///
    /// Rend `nil` quand aucune heure du créneau n'est couverte par les prévisions — ce qui n'est
    /// pas « il fera beau », et ne doit surtout pas être traité comme tel.
    static func pluie(surLe slot: Slot, _ hours: [Hour], jour: Date,
                      calendrier: Calendar = .current) -> Double? {
        let duJour = hours.filter {
            calendrier.isDate($0.date, inSameDayAs: jour)
                && slot.heures.contains(calendrier.component(.hour, from: $0.date))
        }
        guard !duJour.isEmpty else { return nil }
        return duJour.map { heure -> Double in
            // Une probabilité haute sans une goutte annoncée reste une menace, pas une averse.
            // On la retient à moitié : assez pour ne pas promettre le beau temps, pas assez pour
            // faire déplacer une séance.
            heure.precipitationIntensity >= bruineMinimale
                ? heure.precipitationChance
                : heure.precipitationChance * 0.5
        }.max()
    }

    /// Le début d'un créneau, dans le fuseau de l'appareil.
    static func debut(_ slot: Slot, jour: Date, calendrier: Calendar = .current) -> Date? {
        calendrier.date(bySettingHour: slot.heures.lowerBound, minute: 0, second: 0, of: jour)
    }

    /// Le conseil du jour, ou `nil` — et `nil` est la réponse la plus fréquente, par construction.
    static func advise(hours: [Hour], usual: Slot, now: Date = .now,
                       calendrier: Calendar = .current) -> Advice? {
        guard let pluieHabituelle = pluie(surLe: usual, hours, jour: now, calendrier: calendrier),
              pluieHabituelle >= pluieProbable else { return nil }

        // Le créneau habituel est-il encore devant nous ? S'il est passé, il n'y a rien à éviter :
        // soit elle a déjà couru, soit la journée est faite.
        guard let debutHabituel = debut(usual, jour: now, calendrier: calendrier),
              debutHabituel > now else { return nil }

        let candidats = Slot.allCases.filter { $0 != usual }.compactMap { slot -> (Slot, Double)? in
            guard let p = pluie(surLe: slot, hours, jour: now, calendrier: calendrier),
                  let debutCandidat = debut(slot, jour: now, calendrier: calendrier),
                  debutCandidat.timeIntervalSince(now) >= preavisMinimum
            else { return nil }
            return (slot, p)
        }

        // Le plus sec, et à égalité le plus proche — un conseil qui fait courir dans deux heures
        // se suit mieux qu'un qui fait attendre neuf heures.
        guard let (meilleur, pluieMeilleure) = candidats.min(by: { gauche, droite in
            if gauche.1 != droite.1 { return gauche.1 < droite.1 }
            let dg = debut(gauche.0, jour: now, calendrier: calendrier) ?? .distantFuture
            let dd = debut(droite.0, jour: now, calendrier: calendrier) ?? .distantFuture
            return dg < dd
        }) else { return nil }

        guard pluieMeilleure <= creneauSec,
              pluieHabituelle - pluieMeilleure >= ecartFranc else { return nil }

        return Advice(avoid: usual, prefer: meilleur)
    }
}
