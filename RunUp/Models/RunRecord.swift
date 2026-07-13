import Foundation
import SwiftData

/// One completed run — a growing collection, queried newest-first. Mirrors `history` in app.jsx.
@Model
final class RunRecord {
    var date: Date
    var title: String
    var distanceKm: Double
    var durationSeconds: Int
    var avgPace: String
    var avgHeartRate: Int
    var kcal: Int
    var elevationGainM: Int
    var splits: [String]

    init(
        date: Date = .now,
        title: String,
        distanceKm: Double,
        durationSeconds: Int,
        avgPace: String,
        avgHeartRate: Int,
        kcal: Int,
        elevationGainM: Int = 0,
        splits: [String] = []
    ) {
        self.date = date
        self.title = title
        self.distanceKm = distanceKm
        self.durationSeconds = durationSeconds
        self.avgPace = avgPace
        self.avgHeartRate = avgHeartRate
        self.kcal = kcal
        self.elevationGainM = elevationGainM
        self.splits = splits
    }
}
