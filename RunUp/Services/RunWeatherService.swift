import Foundation
import CoreLocation
import WeatherKit

/// Les prévisions horaires du jour, pour décider si la séance doit changer d'heure.
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

    /// Les heures de prévision du jour, ou un tableau vide — et un tableau vide n'est PAS du beau
    /// temps : `WeatherAdvice` refuse de conseiller quoi que ce soit sans prévisions.
    func hoursToday(fallback: CLLocationCoordinate2D?) async -> [WeatherAdvice.Hour] {
        guard let point = await position(fallback: fallback) else { return [] }
        do {
            let previsions = try await WeatherKit.WeatherService.shared.weather(
                for: point, including: .hourly)
            let finDuJour = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
            return previsions.forecast
                .filter { $0.date >= .now.addingTimeInterval(-3600) && $0.date <= finDuJour }
                .map {
                    WeatherAdvice.Hour(
                        date: $0.date,
                        precipitationChance: $0.precipitationChance,
                        precipitationIntensity: $0.precipitationIntensity
                            .converted(to: .millimetersPerHour).value)
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
