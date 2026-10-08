import Foundation

/// « Il va pleuvoir demain soir, prévois ta séance demain midi. »
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

    /// Le conseil pour un jour donné, ou `nil` — et `nil` est la réponse la plus fréquente, par
    /// construction.
    ///
    /// `jour` vaut `now` par défaut, ce qui est le comportement d'origine : conseiller la journée
    /// en cours. Le passer explicitement permet de parler de DEMAIN — c'est tout ce qui manquait
    /// pour qu'un conseil puisse arriver la veille. Rien d'autre ne change : les trois conditions
    /// sont les mêmes, et le préavis se mesure toujours depuis `now`, donc un conseil pour demain
    /// le satisfait d'office.
    static func advise(hours: [Hour], usual: Slot, now: Date = .now, jour: Date? = nil,
                       calendrier: Calendar = .current) -> Advice? {
        let vise = jour ?? now
        guard let pluieHabituelle = pluie(surLe: usual, hours, jour: vise, calendrier: calendrier),
              pluieHabituelle >= pluieProbable else { return nil }

        // Le créneau habituel est-il encore devant nous ? S'il est passé, il n'y a rien à éviter :
        // soit elle a déjà couru, soit la journée est faite.
        guard let debutHabituel = debut(usual, jour: vise, calendrier: calendrier),
              debutHabituel > now else { return nil }

        let candidats = Slot.allCases.filter { $0 != usual }.compactMap { slot -> (Slot, Double)? in
            guard let p = pluie(surLe: slot, hours, jour: vise, calendrier: calendrier),
                  let debutCandidat = debut(slot, jour: vise, calendrier: calendrier),
                  debutCandidat.timeIntervalSince(now) >= preavisMinimum
            else { return nil }
            return (slot, p)
        }

        // Le plus sec, et à égalité le plus proche — un conseil qui fait courir dans deux heures
        // se suit mieux qu'un qui fait attendre neuf heures.
        guard let (meilleur, pluieMeilleure) = candidats.min(by: { gauche, droite in
            if gauche.1 != droite.1 { return gauche.1 < droite.1 }
            let dg = debut(gauche.0, jour: vise, calendrier: calendrier) ?? .distantFuture
            let dd = debut(droite.0, jour: vise, calendrier: calendrier) ?? .distantFuture
            return dg < dd
        }) else { return nil }

        guard pluieMeilleure <= creneauSec,
              pluieHabituelle - pluieMeilleure >= ecartFranc else { return nil }

        return Advice(avoid: usual, prefer: meilleur)
    }

    // MARK: De quel jour parle-t-on

    /// Le prochain jour sur lequel un conseil a du sens : aujourd'hui tant que le créneau habituel
    /// n'a pas commencé, demain dès qu'il est entamé.
    ///
    /// C'EST CE CALCUL QUI FAIT ARRIVER LE CONSEIL LA VEILLE, et il n'a pas fallu d'heure butoir
    /// pour ça. Pour quelqu'un qui court le soir, dès 17 h le créneau du jour est entamé : le
    /// prochain conseil utile porte donc sur demain soir, et une app ouverte à 20 h le donne. Pour
    /// quelqu'un qui court le matin, le basculement a lieu à 7 h — elle apprend la météo de demain
    /// matin dès la fin de sa séance d'aujourd'hui, soit presque vingt-quatre heures de préavis.
    ///
    /// Une heure fixe — « après 18 h, parle de demain » — aurait été fausse pour les deux : trop
    /// tard pour la coureuse du soir, qui part à 17 h, et absurdement tard pour celle du matin.
    /// Le bon repère n'est pas l'heure qu'il est, c'est l'heure à laquelle ELLE court.
    static func jourAConseiller(usual: Slot, now: Date = .now,
                                calendrier: Calendar = .current) -> Date {
        guard let debutDuJour = debut(usual, jour: now, calendrier: calendrier),
              debutDuJour > now else {
            return calendrier.date(byAdding: .day, value: 1, to: now) ?? now
        }
        return now
    }

    // MARK: Ce qu'on a déjà dit

    /// L'état de ce qui a été annoncé, pour ne pas le répéter et pour savoir quoi rectifier.
    struct DejaDit: Equatable {
        /// Le jour dont parlait la dernière annonce. `nil` : on n'a jamais rien dit.
        ///
        /// `= nil` écrit, et pas seulement déduit du point d'interrogation : c'est ce qui garantit
        /// que l'initialiseur par membre offre un défaut pour ce champ, donc que `DejaDit()` sans
        /// argument compile. Trois caractères contre un aller-retour de CI d'un quart d'heure.
        var jour: Date? = nil
        /// Le conseil annoncé ce jour-là. `nil` avec un `jour` non nil veut dire « on a regardé,
        /// il n'y avait rien à dire » — et c'est une information, pas une absence : elle évite de
        /// re-notifier le même conseil, et permet de reconnaître un changement.
        var conseil: Advice? = nil
        /// Une rectification a déjà été envoyée pour ce jour-là.
        var rectifiee: Bool = false
    }

    /// Ce qu'il y a à annoncer.
    enum Annonce: Equatable {
        /// Première parole sur ce jour : « il va pleuvoir demain soir, cours plutôt demain midi ».
        case conseil(Advice)
        /// On avait conseillé un créneau, ce n'est plus le bon.
        case rectification(Advice)
        /// On avait annoncé de la pluie sur un créneau, il n'y en aura pas. Le créneau rendu est
        /// celui qu'on avait dit d'éviter — c'est lui qu'elle peut reprendre.
        case annulation(Slot)
    }

    /// Faut-il dire quelque chose, et quoi ?
    ///
    /// # POURQUOI LA RECTIFICATION EST LIMITÉE À UNE
    ///
    /// Une prévision à vingt heures d'échéance bouge. Sans limite, une journée hésitante
    /// enverrait quatre messages contradictoires, et c'est la façon exacte dont on perd un
    /// interrupteur pour toujours — le défaut contre lequel tout l'en-tête de ce fichier met en
    /// garde. Une annonce, au plus une rectification, puis silence : la rectification est ce qui
    /// rend le conseil de la veille fiable, pas un abonnement aux variations du ciel.
    ///
    /// Et il n'y a pas de rectification sans conseil préalable. Dire « finalement il ne pleut
    /// plus » à quelqu'un à qui on n'a jamais annoncé de pluie serait absurde ; dire « ça a
    /// changé » quand rien n'avait été dit, c'est juste un conseil, et c'est ce qui est rendu.
    static func annonce(pour jour: Date, hours: [Hour], usual: Slot, dejaDit: DejaDit,
                        now: Date = .now, calendrier: Calendar = .current) -> Annonce? {
        let nouveau = advise(hours: hours, usual: usual, now: now, jour: jour,
                             calendrier: calendrier)
        let memeJour = dejaDit.jour.map { calendrier.isDate($0, inSameDayAs: jour) } ?? false

        guard memeJour else {
            // Un jour neuf : ce qu'on avait dit sur le précédent ne pèse plus rien.
            return nouveau.map { Annonce.conseil($0) }
        }
        guard !dejaDit.rectifiee else { return nil }
        guard let ancien = dejaDit.conseil else {
            // On avait regardé sans rien trouver à dire. Si la pluie arrive maintenant, c'est une
            // première annonce sur ce jour, pas une rectification.
            return nouveau.map { Annonce.conseil($0) }
        }
        guard let nouveau else { return .annulation(ancien.avoid) }
        return ancien == nouveau ? nil : .rectification(nouveau)
    }

    /// Ce qu'il faut retenir après une annonce — ou après avoir regardé sans rien dire.
    ///
    /// Pure, et séparée de l'envoi, parce que c'est la partie où l'on se trompe. Trois champs à
    /// tenir d'accord, quatre issues possibles, et une erreur ne se verrait pas tout de suite :
    /// elle se verrait une semaine plus tard, sous la forme d'une rectification qui n'arrive
    /// jamais ou d'un conseil répété tous les matins. `AppState` ne fait plus que recopier ce
    /// qu'elle rend.
    static func memoire(apres annonce: Annonce?, pour jour: Date, dejaDit: DejaDit,
                        calendrier: Calendar = .current) -> DejaDit {
        guard let annonce else {
            // Rien dit. On note tout de même qu'on a REGARDÉ ce jour-là : sans cette trace, un
            // changement de prévision plus tard serait indistinguable d'un premier conseil, et la
            // rectification n'existerait pas. Si le jour était déjà le bon, on ne touche à rien —
            // écraser effacerait ce qu'on avait annoncé.
            let memeJour = dejaDit.jour.map { calendrier.isDate($0, inSameDayAs: jour) } ?? false
            return memeJour ? dejaDit : DejaDit(jour: jour, conseil: nil, rectifiee: false)
        }
        switch annonce {
        case .conseil(let advice):
            return DejaDit(jour: jour, conseil: advice, rectifiee: false)
        case .rectification(let advice):
            return DejaDit(jour: jour, conseil: advice, rectifiee: true)
        case .annulation:
            return DejaDit(jour: jour, conseil: nil, rectifiee: true)
        }
    }
}
