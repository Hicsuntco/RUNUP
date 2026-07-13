import Foundation

/// Every navigable top-level screen (mirrors the `screen` string in app.jsx's `SCREENS` map).
enum AppScreen: String, Hashable {
    case home = "prog"
    case plan
    case rings
    case live
    case recap
    case coach
    case stats
    case club
    case race
    case profile
    case history
}
