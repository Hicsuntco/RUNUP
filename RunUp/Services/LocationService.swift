import Foundation
import Observation
import CoreLocation

/// Real GPS tracking for the Live Run screen (MapKit + CoreLocation, per architecture decision —
/// see README § Live Run, which leaves stylized-vs-real map as an implementation choice).
/// Publishes route points, cumulative distance, and a GPS-instability flag driven by actual
/// horizontal accuracy degradation rather than a scripted timer.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    private(set) var route: [CLLocationCoordinate2D] = []
    /// Parallel to `route` (same index, same length) — real GPS altitude per point when the fix's
    /// vertical accuracy was trustworthy, nil otherwise. Feeds the elevation profile chart; kept
    /// separate from `route` rather than folding into a richer point type since most call sites
    /// (distance/route-trace rendering) only ever needed lat/lng.
    private(set) var routeAltitudes: [Double?] = []
    private(set) var distanceMeters: Double = 0
    /// Vitesse instantanée, ou `nil` quand l'appareil ne la connaît pas.
    ///
    /// `CLLocation.speed` vaut une valeur NÉGATIVE quand elle est indisponible — c'est le cas des
    /// premiers points de chaque course, et de tout point calculé sans effet Doppler. Le code
    /// écrivait `max(0, newest.speed)`, ce qui transformait « je ne sais pas » en « 0 m/s », donc
    /// en « elle est à l'arrêt » pour la pause automatique. Rendre l'inconnu explicite est la
    /// seule façon que l'appelant ne puisse pas le confondre avec un arrêt.
    private(set) var currentSpeedMetersPerSecond: Double?
    private(set) var isSignalUnstable = false
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    /// Vrai dès qu'un point exploitable est arrivé. Une puce GNSS froide met 5 à 30 secondes à
    /// accrocher, et pendant tout ce temps le service n'a strictement rien à dire sur la course —
    /// ni la distance, ni l'allure, ni surtout si la coureuse bouge. Sans ce drapeau, l'appelant
    /// ne peut pas distinguer « immobile » de « pas encore de signal », et l'écran ne peut pas
    /// distinguer « l'app cherche » de « l'app est cassée ».
    private(set) var hasFix = false
    /// Distance à vol d'oiseau depuis l'endroit où l'accumulation a été suspendue.
    ///
    /// La reprise automatique ne s'appuyait que sur `CLLocation.speed`. Or c'est précisément à
    /// l'arrêt, sous un immeuble ou sous les arbres, que ce champ devient indisponible — donc au
    /// moment exact où la reprise en a besoin. Un déplacement mesuré entre deux points, lui,
    /// reste lisible quoi qu'il arrive : si elle s'est éloignée de vingt-cinq mètres du feu
    /// rouge, elle est repartie, que l'appareil sache dire à quelle vitesse ou non.
    private(set) var metersSincePause: Double = 0
    private var pauseAnchor: CLLocation?
    /// Sum of positive altitude deltas between consecutive fixes with a trustworthy
    /// `verticalAccuracy` — real GPS-derived elevation gain, not the flat 0 `RunRecord` used to
    /// always ship with (nothing tracked altitude at all).
    private(set) var elevationGainMeters: Double = 0

    /// Horizontal accuracy above this (meters) is treated as an unstable fix.
    private let unstableAccuracyThreshold: CLLocationAccuracy = 30
    private var lastLocation: CLLocation?
    /// True while GPS fixes still accumulate distance/route/elevation. Auto-pause (see
    /// `LiveRunViewModel`) sets this false via `pauseAccumulation()` WITHOUT calling `stop()` —
    /// it still needs live `currentSpeedMetersPerSecond` readings to notice her start running
    /// again, which a full `stop()` (no more delegate callbacks at all) would make impossible.
    private(set) var isAccumulating = true

    override init() {
        super.init()
        manager.delegate = self
        // `Best` et non `BestForNavigation`. Apple documente ce dernier comme réservé à un
        // appareil branché sur secteur : fusion de capteurs supplémentaire, puce GNSS à plein
        // régime. C'est le chemin le plus long de l'app — 45 à 90 minutes, écran éteint,
        // localisation en arrière-plan — donc le plus gros poste de batterie qui existe ici.
        //
        // L'argument décisif n'est pas le coût, c'est l'inutilité : le gestionnaire ci-dessous
        // écarte lui-même tout point ayant bougé de moins de `max(hAcc, 8)` mètres, soit environ
        // deux fixes sur trois à allure de course. On payait la précision sub-métrique pour des
        // mesures qu'on refusait ensuite d'utiliser. `Best` vise ~5 m, largement sous ce plancher
        // de bruit de 8 m, et c'est ce qu'utilisent Strava et Nike Run Club.
        //
        // Volontairement PAS de `distanceFilter` : l'auto-pause lit `currentSpeedMetersPerSecond`
        // à chaque fix reçu, et un filtre de distance couperait précisément les callbacks à
        // l'arrêt — donc la détection de pause, qui a besoin de savoir qu'on ne bouge plus.
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Begins a FRESH run — zeroes route/distance/elevation. Resuming after a pause must go
    /// through `resume()` instead: this reset living in the same method as "turn GPS on" is
    /// exactly what used to wipe a paused run's 5 km back to 0.00 at the traffic light.
    func start() {
        route = []
        routeAltitudes = []
        distanceMeters = 0
        elevationGainMeters = 0
        lastLocation = nil
        hasFix = false
        currentSpeedMetersPerSecond = nil
        isSignalUnstable = false
        resume()
    }

    /// Restarts GPS delivery without touching accumulated data. Drops `lastLocation` first so the
    /// pause gap itself is never counted as distance — if she walked 200 m during the pause, the
    /// next fix starts a fresh segment instead of bridging from where she pressed pause.
    func resume() {
        isAccumulating = true
        lastLocation = nil
        pauseAnchor = nil
        metersSincePause = 0
        applyBackgroundUpdatesIfAuthorized()
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    /// Auto-pause: keeps GPS delivery running (so speed readings stay live) but stops crediting
    /// distance/route/elevation — `lastLocation` is dropped so the stationary gap itself is never
    /// counted as distance once accumulation resumes, same reasoning as `resume()`.
    func pauseAccumulation() {
        isAccumulating = false
        lastLocation = nil
        pauseAnchor = nil
        metersSincePause = 0
    }

    /// Only valid once authorization is actually granted — setting the flag beforehand risks the
    /// manager silently ignoring it, since background delivery has nothing to attach to without
    /// at least When-In-Use authorization. Called again from the authorization callback because
    /// on the very first run the grant arrives AFTER `start()` (the system prompt is still up),
    /// and without the retry the whole first run would freeze the moment she locked the screen.
    private func applyBackgroundUpdatesIfAuthorized() {
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        applyBackgroundUpdatesIfAuthorized()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newest = locations.last else { return }
        isSignalUnstable = newest.horizontalAccuracy > unstableAccuracyThreshold || newest.horizontalAccuracy < 0
        if newest.horizontalAccuracy >= 0 { hasFix = true }
        // Always kept live, even while accumulation is paused — auto-pause's whole resume
        // detection depends on seeing speed pick back up. Négatif = indisponible, et cela reste
        // `nil` jusqu'au prochain point qui porte une vraie mesure.
        currentSpeedMetersPerSecond = newest.speed >= 0 ? newest.speed : nil

        guard isAccumulating else {
            // Suspendue : on n'accumule plus ni distance ni tracé, mais on continue de mesurer
            // de combien elle s'est éloignée du point d'arrêt — c'est ce qui permet de repartir
            // sans dépendre d'une vitesse que l'appareil ne sait pas toujours donner.
            guard newest.horizontalAccuracy >= 0, newest.horizontalAccuracy < 65 else { return }
            if let anchor = pauseAnchor {
                metersSincePause = newest.distance(from: anchor)
            } else {
                pauseAnchor = newest
                metersSincePause = 0
            }
            return
        }

        // All delivered fixes, not just the last — batched background delivery otherwise cuts
        // the corners off every curve and undercounts distance.
        for loc in locations {
            guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy < 65 else { continue }

            if let last = lastLocation {
                let meters = loc.distance(from: last)
                let dt = loc.timestamp.timeIntervalSince(last.timestamp)
                // Re-acquired fix after signal loss (tunnel, dense blocks, tree canopy) arrives as
                // one huge straight-line jump — an implied speed no runner reaches (12 m/s ≈
                // 1:23/km) means the gap wasn't run, so start a fresh segment instead of counting
                // it. This point is also skipped from `route`/`lastLocation` below — recording it
                // anyway used to draw a spurious spike/tangle on the trace even though the distance
                // math already knew not to trust it, and kept comparing the *next* fix against this
                // same bad point instead of the last known-good one.
                guard dt > 0, meters / dt <= 12 else { continue }
                // Degraded signal (tree canopy, urban canyon) doesn't just occasionally throw a
                // huge implausible jump — far more often it makes a genuinely stationary or
                // slow-moving runner's fix wander a few meters back and forth between updates.
                // Each of those legs is individually far too small/slow to trip the checks above,
                // but at ~1 fix/sec over a 25+ minute run, that jitter silently summed to a real,
                // wrong +2 km on top of an actual 4 km run. A fix that moved less than the worse
                // of the two accuracies isn't distinguishable from standing still, so it's
                // dropped entirely — including from `lastLocation` below — rather than credited:
                // real slow movement just keeps measuring against the same last trusted fix until
                // it clears the floor, instead of losing a little distance on every noisy step.
                let noiseFloor = max(loc.horizontalAccuracy, last.horizontalAccuracy, 8)
                guard meters > noiseFloor else { continue }
                distanceMeters += meters
                // Vertical accuracy is typically much worse than horizontal — negative means
                // invalid, and a loose 20m threshold keeps out the worst GPS altitude noise
                // without discarding every real fix.
                if loc.verticalAccuracy >= 0, loc.verticalAccuracy < 20 {
                    let delta = loc.altitude - last.altitude
                    if delta > 0 { elevationGainMeters += delta }
                }
            }
            lastLocation = loc
            route.append(loc.coordinate)
            routeAltitudes.append(loc.verticalAccuracy >= 0 && loc.verticalAccuracy < 20 ? loc.altitude : nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isSignalUnstable = true
        // La vitesse connue devient périmée à l'instant où la localisation échoue : la garder
        // ferait croire à la pause automatique qu'elle mesure encore quelque chose.
        currentSpeedMetersPerSecond = nil
    }
}
