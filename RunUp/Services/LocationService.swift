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
    private(set) var distanceMeters: Double = 0
    private(set) var currentSpeedMetersPerSecond: Double = 0
    private(set) var isSignalUnstable = false
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    /// Sum of positive altitude deltas between consecutive fixes with a trustworthy
    /// `verticalAccuracy` — real GPS-derived elevation gain, not the flat 0 `RunRecord` used to
    /// always ship with (nothing tracked altitude at all).
    private(set) var elevationGainMeters: Double = 0

    /// Horizontal accuracy above this (meters) is treated as an unstable fix.
    private let unstableAccuracyThreshold: CLLocationAccuracy = 30
    private var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
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
        distanceMeters = 0
        elevationGainMeters = 0
        lastLocation = nil
        resume()
    }

    /// Restarts GPS delivery without touching accumulated data. Drops `lastLocation` first so the
    /// pause gap itself is never counted as distance — if she walked 200 m during the pause, the
    /// next fix starts a fresh segment instead of bridging from where she pressed pause.
    func resume() {
        lastLocation = nil
        applyBackgroundUpdatesIfAuthorized()
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
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

        // All delivered fixes, not just the last — batched background delivery otherwise cuts
        // the corners off every curve and undercounts distance.
        for loc in locations {
            guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy < 65 else { continue }

            if let last = lastLocation {
                let meters = loc.distance(from: last)
                let dt = loc.timestamp.timeIntervalSince(last.timestamp)
                // Re-acquired fix after signal loss (tunnel, dense blocks) arrives as one huge
                // straight-line jump — an implied speed no runner reaches (12 m/s ≈ 1:23/km)
                // means the gap wasn't run, so start a fresh segment instead of counting it.
                if dt > 0, meters / dt <= 12 {
                    distanceMeters += meters
                    // Vertical accuracy is typically much worse than horizontal — negative means
                    // invalid, and a loose 20m threshold keeps out the worst GPS altitude noise
                    // without discarding every real fix.
                    if loc.verticalAccuracy >= 0, loc.verticalAccuracy < 20 {
                        let delta = loc.altitude - last.altitude
                        if delta > 0 { elevationGainMeters += delta }
                    }
                }
            }
            currentSpeedMetersPerSecond = max(0, loc.speed)
            lastLocation = loc
            route.append(loc.coordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isSignalUnstable = true
    }
}
