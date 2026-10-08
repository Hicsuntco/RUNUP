import Foundation
import SwiftData
import CoreLocation

/// Une passe de conseil météo : décider, annoncer, retenir.
///
/// # POURQUOI CE SERVICE EXISTE SÉPARÉMENT D'`AppState`
///
/// Parce qu'il a maintenant DEUX appelants, et qu'un seul des deux a un `AppState`.
///
/// Le premier est l'ouverture de l'app, par le rafraîchissement quotidien. Le second est
/// `WeatherBackgroundRefresh`, qu'iOS réveille sans interface : `AppState` est construit dans
/// l'`onAppear` de `RootView`, qui ne se produit pas quand l'app est lancée en arrière-plan. La
/// logique ne pouvait donc pas rester une méthode privée d'`AppState` — elle aurait été
/// inatteignable depuis le seul chemin qui fait arriver la notification sans qu'on ouvre l'app.
///
/// Il ne DÉCIDE rien lui-même : `WeatherAdvice` décide, et c'est une fonction pure et testée. Ici
/// il n'y a que le va-et-vient — lire le profil, aller chercher la prévision, écrire ce qu'on a
/// retenu.
@MainActor
struct WeatherAdviceService {

    /// D'où vient la passe. Ne sert qu'à la mesure, et cette mesure est le SEUL moyen de savoir si
    /// le réveil en arrière-plan se produit vraiment : iOS décide seul quand l'accorder, rien ne
    /// le signale, et sans ce champ on ne pourrait que supposer.
    enum Source: String {
        case app
        case arrierePlan = "background"
    }

    /// Deux heures entre deux messages météo, quel que soit leur contenu.
    ///
    /// Et non plus « un seul par jour », qui empêchait la rectification — c'est-à-dire tout
    /// l'intérêt d'un conseil donné la veille. Deux heures écartent le seul cas vraiment fâcheux :
    /// un conseil et son démenti à quelques minutes d'écart, qui se lisent comme une app qui
    /// s'affole.
    static let delaiEntreDeuxMessages: TimeInterval = 2 * 3600

    let modelContext: ModelContext
    let weather: RunWeatherService

    /// Une passe complète. Ne rend rien : tout ce qu'elle fait est visible dans le profil et,
    /// éventuellement, sur l'écran verrouillé.
    ///
    /// `demanderLaPosition` est faux en arrière-plan, et ce n'est pas une optimisation. Avec une
    /// autorisation « pendant l'utilisation », une demande de position ponctuelle depuis un
    /// processus réveillé sans interface n'a aucune raison d'aboutir — l'app n'est pas « en cours
    /// d'utilisation ». Le repli, lui, est déjà sur le téléphone : le départ de la dernière
    /// course. On court presque toujours du même endroit, et deux kilomètres ne changent pas la
    /// réponse à « est-ce qu'il va pleuvoir demain à 18 h ».
    func conseiller(profile: UserProfile, source: Source,
                    demanderLaPosition: Bool = true) async {
        guard profile.weatherAlertsEnabled else { return }

        let creneauHabituel = WeatherAdvice.Slot.from(profile.preferredTimeOfDay)
        let jourVise = WeatherAdvice.jourAConseiller(usual: creneauHabituel)
        // Un jour sans séance n'a rien à déplacer.
        guard Self.courtElle(le: jourVise, profile) else { return }
        if let dernier = profile.lastWeatherAdviceDate,
           Date.now.timeIntervalSince(dernier) < Self.delaiEntreDeuxMessages { return }
        guard await NotificationService.shared.isAuthorized() else { return }

        let heures = await weather.hours(pour: jourVise, fallback: departDeLaDerniereCourse(),
                                         demanderLaPosition: demanderLaPosition)
        let dejaDit = WeatherAdvice.DejaDit(
            jour: profile.weatherAdviceDay,
            conseil: Self.conseilEnMemoire(profile),
            rectifiee: profile.weatherAdviceAmended)
        let annonce = WeatherAdvice.annonce(pour: jourVise, hours: heures,
                                            usual: creneauHabituel, dejaDit: dejaDit)

        // La mémoire se met à jour MÊME SANS ANNONCE : « on a regardé demain, il n'y avait rien à
        // dire » est une information. Sans elle, une pluie qui apparaît ensuite serait annoncée
        // comme un premier conseil, et surtout une pluie qui DISPARAÎT ne serait jamais démentie.
        Self.enregistrer(WeatherAdvice.memoire(apres: annonce, pour: jourVise, dejaDit: dejaDit),
                         dans: profile)
        guard let annonce else { return }

        profile.lastWeatherAdviceDate = .now
        let pourDemain = !Calendar.current.isDateInToday(jourVise)
        NotificationService.shared.postWeatherAnnonce(annonce, pourDemain: pourDemain)
        Analytics.shared.track(.weatherAdviceSent, [
            "source": .string(source.rawValue),
            "nature": .string(Self.nature(annonce)),
            "target": .string(pourDemain ? "tomorrow" : "today")
        ])
    }

    private static func nature(_ annonce: WeatherAdvice.Annonce) -> String {
        switch annonce {
        case .conseil: return "advice"
        case .rectification: return "amended"
        case .annulation: return "cancelled"
        }
    }

    /// Le départ de la dernière course, qui sert de repli de position.
    private func departDeLaDerniereCourse() -> CLLocationCoordinate2D? {
        let borne = Calendar.current.date(byAdding: .month, value: -3, to: .now) ?? .distantPast
        var descripteur = FetchDescriptor<RunRecord>(
            predicate: #Predicate { $0.date > borne },
            sortBy: [SortDescriptor(\RunRecord.date, order: .reverse)])
        descripteur.fetchLimit = 10
        let recentes = (try? modelContext.fetch(descripteur)) ?? []
        return recentes.compactMap { $0.route.first }.first
            .map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
    }

    /// Est-ce qu'elle court ce jour-là ?
    ///
    /// Trois réponses, parce que la question n'a pas la même source selon le jour :
    ///
    /// - **Aujourd'hui** : `todaySession`, la séance réellement posée, décalages compris.
    /// - **Un autre jour de CETTE semaine** : `weekSessions`, le plan généré de la semaine.
    /// - **Un jour de la semaine SUIVANTE** : `runningDays`, l'intention déclarée. Et c'est le cas
    ///   qui compte le plus ici — un dimanche soir, le jour visé est un lundi qui n'est pas encore
    ///   généré. Le chercher dans `weekSessions` rendrait le lundi PASSÉ, c'est-à-dire la séance
    ///   d'il y a six jours, et un dimanche soir sur deux donnerait la mauvaise réponse.
    static func courtElle(le jour: Date, _ profile: UserProfile,
                          maintenant: Date = .now, calendrier: Calendar = .current) -> Bool {
        if calendrier.isDate(jour, inSameDayAs: maintenant) {
            return profile.todaySession.durationMinutes > 0
        }
        let index = AdaptivePlanEngine.weekdayIndex(for: jour, calendrier: calendrier)
        guard Self.memeSemaineDePlan(jour, maintenant, calendrier) else {
            return profile.runningDays.contains(index)
        }
        let prevue = profile.weekSessions.first { $0.weekday == index }?.session
        return (prevue?.durationMinutes ?? 0) > 0
    }

    /// Deux dates tombent-elles dans la même semaine DE PLAN ?
    ///
    /// # POURQUOI PAS `isDate(_:equalTo:toGranularity: .weekOfYear)`
    ///
    /// Parce que cette granularité suit `Calendar.firstWeekday`, qui dépend de la LANGUE de
    /// l'appareil. En France la semaine commence le lundi et la réponse tombait juste ; aux
    /// États-Unis elle commence le dimanche, donc un dimanche et le lundi suivant sont déclarés
    /// dans la même semaine. Le conseil du dimanche soir allait alors chercher le lundi dans le
    /// plan de la semaine en cours — c'est-à-dire le lundi PASSÉ, la séance d'il y a six jours —
    /// exactement le défaut que ce code existe pour éviter, et seulement pour une partie des
    /// gens. C'est la pire forme : juste chez soi, faux ailleurs.
    ///
    /// La semaine du plan, elle, va TOUJOURS du lundi au dimanche : `weekSessions` est indexé par
    /// `weekdayIndex`, qui vaut 0 le lundi quelle que soit la langue. On compare donc des lundis,
    /// calculés par cette même fonction — la question « quelle semaine » reçoit ainsi la même
    /// réponse que la question « quel jour », ce qui est la seule façon qu'elles ne se
    /// contredisent pas.
    static func memeSemaineDePlan(_ une: Date, _ autre: Date, _ calendrier: Calendar) -> Bool {
        guard let lundiDUne = lundiDeLaSemaine(une, calendrier),
              let lundiDeLAutre = lundiDeLaSemaine(autre, calendrier) else { return false }
        return lundiDUne == lundiDeLAutre
    }

    private static func lundiDeLaSemaine(_ jour: Date, _ calendrier: Calendar) -> Date? {
        let index = AdaptivePlanEngine.weekdayIndex(for: jour, calendrier: calendrier)
        return calendrier.date(byAdding: .day, value: -index, to: calendrier.startOfDay(for: jour))
    }

    /// Le conseil en mémoire, relu depuis ses deux `rawValue`. Les deux doivent être là : un seul
    /// créneau ne décrit pas un conseil, qui est toujours un déplacement de l'un vers l'autre.
    static func conseilEnMemoire(_ profile: UserProfile) -> WeatherAdvice.Advice? {
        guard let eviter = profile.weatherAdviceAvoidRaw.flatMap(WeatherAdvice.Slot.init(rawValue:)),
              let preferer = profile.weatherAdvicePreferRaw.flatMap(WeatherAdvice.Slot.init(rawValue:))
        else { return nil }
        return WeatherAdvice.Advice(avoid: eviter, prefer: preferer)
    }

    static func enregistrer(_ memoire: WeatherAdvice.DejaDit, dans profile: UserProfile) {
        profile.weatherAdviceDay = memoire.jour
        profile.weatherAdviceAvoidRaw = memoire.conseil?.avoid.rawValue
        profile.weatherAdvicePreferRaw = memoire.conseil?.prefer.rawValue
        profile.weatherAdviceAmended = memoire.rectifiee
    }
}
