import Foundation

/// The 6 onboarding objectives. See README § Onboarding step 3.
enum GoalType: String, Codable, CaseIterable, Identifiable {
    case race, progress, restart, weight, health, hyrox

    var id: String { rawValue }

    /// `String(localized:)` et non un littéral nu : ces libellés sont composés au niveau du
    /// MODÈLE, donc rendus comme de simples `String` que SwiftUI ne localise pas tout seul —
    /// contrairement à un `Text("…")` écrit dans une vue. Ils apparaissent sur l'onboarding, le
    /// profil, l'écran objectif et le plan : c'est le libellé le plus vu de l'app.
    var title: String {
        switch self {
        case .race: return String(localized: "Préparer une course")
        case .progress: return String(localized: "Progresser")
        case .restart: return String(localized: "(Re)commencer")
        case .weight: return String(localized: "Perdre du poids")
        case .health: return String(localized: "Rester en forme")
        case .hyrox: return String(localized: "Préparer un HYROX")
        }
    }

    var subtitle: String {
        switch self {
        case .race: return String(localized: "Un dossard en vue — on construit le plan pour le jour J")
        case .progress: return String(localized: "Courir plus vite ou plus longtemps, sans course précise")
        case .restart: return String(localized: "Reprendre en douceur, sans se blesser")
        case .weight: return String(localized: "Un programme qui allie course et rééquilibrage alimentaire")
        case .health: return String(localized: "Une routine régulière qui tient dans ta semaine")
        case .hyrox: return String(localized: "8 × 1 km de course + stations fonctionnelles — un vrai plan hybride")
        }
    }

    var emoji: String {
        switch self {
        case .race: return "🏁"
        case .progress: return "📈"
        case .restart: return "🌱"
        case .weight: return "🔥"
        case .health: return "⚡"
        case .hyrox: return "🏋️"
        }
    }

    /// Recovery length (days) once a 9-week program built for this goal ends. See README § 14.
    var recoveryDays: Int {
        switch self {
        case .race: return 6
        case .weight: return 3
        case .progress: return 4
        case .restart: return 5
        case .health: return 3
        case .hyrox: return 6
        }
    }
}

/// HYROX division — Open uses lighter prescribed loads than Pro. Deliberately no kg figures
/// anywhere in the app for either division (see `AdaptivePlanEngine.hyroxArchetypes`) — this app
/// has no verified current-season rulebook weights to assert as fact, and a wrong "real" number
/// would be exactly the kind of fake precision this codebase has been fixing everywhere else.
enum HyroxDivision: String, Codable, CaseIterable, Identifiable {
    case open, pro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open: return "Open"
        case .pro: return "Pro"
        }
    }

    var subtitle: String {
        switch self {
        case .open: return String(localized: "Charges standard — le format le plus couru")
        case .pro: return String(localized: "Charges renforcées — pour un niveau confirmé")
        }
    }
}

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case debutante, intermediaire, confirmee

    var id: String { rawValue }

    var title: String {
        switch self {
        case .debutante: return String(localized: "Débutante")
        case .intermediaire: return String(localized: "Intermédiaire")
        case .confirmee: return String(localized: "Confirmée")
        }
    }

    var subtitle: String {
        switch self {
        case .debutante: return String(localized: "Je cours depuis moins de 6 mois")
        case .intermediaire: return String(localized: "Je cours 2-3 fois par semaine")
        case .confirmee: return String(localized: "Je m'entraîne sérieusement depuis des années")
        }
    }
}

enum RaceDistance: String, Codable, CaseIterable, Identifiable {
    case k5, k10, semi, marathon, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .k5: return "5 km"
        case .k10: return "10 km"
        case .semi: return String(localized: "Semi")
        case .marathon: return String(localized: "Marathon")
        case .other: return String(localized: "Autre distance")
        }
    }

    var chronoPresets: [String] {
        switch self {
        case .k5: return ["20:00", "22:30", "25:00", "28:00"]
        case .k10: return ["42:00", "47:30", "52:00", "58:00"]
        case .semi: return ["1:40", "1:50", "2:00", "2:15"]
        case .marathon: return ["3:30", "3:50", "4:15", "4:45"]
        case .other: return []
        }
    }

    /// nil for `.other` — a bare enum case has no way to hold the number from a free-text custom
    /// distance ("Trail 22 km"). That number still exists on `UserProfile.raceDistanceCustom`
    /// though, so anything scaling pace/periodization to the real race distance should read
    /// `UserProfile.effectiveRaceDistanceKm` instead of this property directly — it falls back to
    /// parsing the custom text rather than silently discarding a real, just-not-preset distance.
    var km: Double? {
        switch self {
        case .k5: return 5
        case .k10: return 10
        case .semi: return 21.0975
        case .marathon: return 42.195
        case .other: return nil
        }
    }
}

enum ConnectedSource: String, Codable, CaseIterable, Identifiable {
    case apple, strava, garmin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: return String(localized: "Apple Santé")
        case .strava: return "Strava"
        case .garmin: return "Garmin Connect"
        }
    }

    var subtitle: String {
        switch self {
        case .apple: return String(localized: "FC, sommeil, course")
        case .strava: return String(localized: "Historique & segments")
        case .garmin: return String(localized: "Montre & données avancées")
        }
    }

    /// Apple Health (HealthKit) and Strava (real OAuth, see `StravaService`) both have a real
    /// integration; Garmin is still a UI stub.
    var isNativelySupported: Bool { self == .apple || self == .strava }
}

enum ProgramPhase: String, Codable {
    case active, recovery, choice, freerun
}

enum RPE: Int, Codable, CaseIterable, Identifiable {
    case tropDur, dur, justeBien, facile

    var id: Int { rawValue }

    var emoji: String {
        switch self {
        case .tropDur: return "😮‍💨"
        case .dur: return "😤"
        case .justeBien: return "🙂"
        case .facile: return "😎"
        }
    }

    var label: String {
        switch self {
        case .tropDur: return String(localized: "Trop dur")
        case .dur: return String(localized: "Dur")
        case .justeBien: return String(localized: "Juste bien")
        case .facile: return String(localized: "Facile")
        }
    }
}
