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

    func start() {
        route = []
        distanceMeters = 0
        elevationGainMeters = 0
        lastLocation = nil
        // Only valid once authorization is actually granted — setting this beforehand risks the
        // manager silently ignoring it (or worse, depending on OS version) since background
        // delivery has nothing to attach to without at least When-In-Use authorization.
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
        }
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }

        isSignalUnstable = loc.horizontalAccuracy > unstableAccuracyThreshold || loc.horizontalAccuracy < 0

        guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy < 65 else { return }

        if let last = lastLocation {
            distanceMeters += loc.distance(from: last)
            // Vertical accuracy is typically much worse than horizontal — negative means invalid,
            // and a loose 20m threshold keeps out the worst GPS altitude noise without discarding
            // every real fix (altitude readings are noisy by nature, even accepted ones).
            if loc.verticalAccuracy >= 0, loc.verticalAccuracy < 20 {
                let delta = loc.altitude - last.altitude
                if delta > 0 { elevationGainMeters += delta }
            }
        }
        currentSpeedMetersPerSecond = max(0, loc.speed)
        lastLocation = loc
        route.append(loc.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isSignalUnstable = true
    }
}
