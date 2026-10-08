import Foundation
import CoreLocation
import WeatherKit

/// Les prévisions horaires d'un jour, pour décider si la séance doit changer d'heure.
///
/// # POURQUOI CE SERVICE EST AUSSI PETIT
///
/// Il ne décide rien. Il va chercher des heures et les rend à `WeatherAdvice`, qui est une
/// fonction pure et testée. Tout ce qui est ici — réseau, position, WeatherKit — est
/// invérifiable sans appareil ; tout ce qui est décidable vit ailleurs. La frontière est posée
/// exactement là pour que la partie qu'on peut prouver soit la partie qui compte.
///
/// # LA POSITION
///
/// Une demande ponctuelle, pas un suivi : `requestLocation()` rend un point puis s'arrête de
/// lui-même. Le repli est le départ de la dernière course, qui est déjà sur l'appareil — on court
/// presque toujours du même endroit, et une prévision à deux kilomètres près ne change pas la
/// réponse à « est-ce qu'il va pleuvoir à 18 h ».
///
/// AUCUNE NOUVELLE AUTORISATION N'EST DEMANDÉE. Si la position n'est pas déjà accordée pour les
/// courses, le service se tait : faire surgir une demande d'accès à la position pour une
/// fonctionnalité que personne n'a encore vue est le meilleur moyen de la faire refuser, et avec
/// elle le suivi GPS des courses.
final class RunWeatherService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var enAttente: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        // Le kilomètre suffit largement, et c'est le réglage le moins coûteux en batterie.
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Les heures de prévision d'un JOUR DONNÉ, ou un tableau vide — et un tableau vide n'est PAS
    /// du beau temps : `WeatherAdvice` refuse de conseiller quoi que ce soit sans prévisions.
    ///
    /// Le jour est un paramètre, et c'est ce qui permet au conseil d'arriver la veille. La version
    /// d'avant prenait de maintenant à « maintenant plus vingt-quatre heures », ce qui recouvrait
    /// la journée en cours et un bout de la suivante — donc jamais la soirée de demain en entier.
    /// Une fenêtre glissante répondait à « que va-t-il se passer dans les prochaines heures » ; la
    /// question est « que va-t-il se passer DEMAIN ENTRE 17 ET 20 H », et elle se borne par un
    /// jour civil. WeatherKit donne une dizaine de jours à l'heure, demain y est largement.
    ///
    /// `demanderLaPosition` est faux quand l'app a été réveillée en arrière-plan. Avec une
    /// autorisation « pendant l'utilisation », une demande ponctuelle depuis un processus sans
    /// interface n'a aucune raison d'aboutir — l'app n'est pas « en cours d'utilisation » — et
    /// l'attendre consommerait le peu de temps accordé au réveil. Le repli suffit : on court
    /// presque toujours du même endroit.
    func hours(pour jour: Date, fallback: CLLocationCoordinate2D?,
               demanderLaPosition: Bool = true) async -> [WeatherAdvice.Hour] {
        // Un `if` et non un ternaire : une branche contient un `await`, l'autre un `map`, et un
        // ternaire qui mêle les deux est le genre d'inférence qui ne se découvre qu'au bout d'un
        // quart d'heure de compilation.
        let depart: CLLocation?
        if demanderLaPosition {
            depart = await position(fallback: fallback)
        } else {
            depart = fallback.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        }
        guard let point = depart else { return [] }
        do {
            let previsions = try await WeatherKit.WeatherService.shared.weather(
                for: point, including: .hourly)
            let debutDuJour = Calendar.current.startOfDay(for: jour)
            let finDuJour = Calendar.current.date(byAdding: .day, value: 1, to: debutDuJour) ?? jour
            return previsions.forecast
                .filter { $0.date >= debutDuJour && $0.date < finDuJour }
                .map {
                    WeatherAdvice.Hour(
                        date: $0.date,
                        precipitationChance: $0.precipitationChance,
                        // `precipitationAmount` et non « intensité » : WeatherKit donne, pour
                        // chaque heure, la HAUTEUR d'eau attendue pendant cette heure-là. Sur une
                        // heure, une hauteur en millimètres et une intensité en millimètres par
                        // heure sont le même nombre — c'est exactement ce que `WeatherAdvice`
                        // attend, et le seuil de bruine à 0,1 garde son sens.
                        precipitationIntensity: $0.precipitationAmount
                            .converted(to: .millimeters).value)
                }
        } catch {
            // Silencieux, et c'est le bon comportement : pas de prévision, pas de conseil. Une
            // erreur météo ne doit rien annoncer ni rien interrompre.
            return []
        }
    }

    private func position(fallback: CLLocationCoordinate2D?) async -> CLLocation? {
        let statut = manager.authorizationStatus
        guard statut == .authorizedWhenInUse || statut == .authorizedAlways else { return nil }
        let fraiche = await withCheckedContinuation { (suite: CheckedContinuation<CLLocation?, Never>) in
            enAttente = suite
            manager.requestLocation()
        }
        if let fraiche { return fraiche }
        return fallback.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        reprendre(locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        reprendre(nil)
    }

    /// Une continuation reprise deux fois fait tomber le processus, et `requestLocation()` peut
    /// très bien rendre un point PUIS une erreur. Elle est donc consommée en la mettant à `nil`
    /// avant de l'utiliser — le second appel ne trouve plus rien à reprendre.
    private func reprendre(_ location: CLLocation?) {
        guard let suite = enAttente else { return }
        enAttente = nil
        suite.resume(returning: location)
    }
}
