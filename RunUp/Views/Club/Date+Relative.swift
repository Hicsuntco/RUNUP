import Foundation

/// Sortie de `ClubView.swift`, où elle n'avait rien à faire : une extension de `Date` au bas
/// d'un écran de 2 400 lignes ne se trouve que par hasard, et deux autres fichiers s'en servent
/// déjà. Le fichier porte son nom pour qu'on la cherche là où elle est.
extension Date {
    /// Formatter construction (locale lookup included) is the expensive part, and this is called
    /// once per feed row on every redraw — one shared instance instead of a fresh allocation each
    /// call. Safe as a plain static: everything touching it runs on the main actor.
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.unitsStyle = .short
        return formatter
    }()

    /// Shared with `ActivityCommentsSheet` — one relative-time formatter for the feed and its
    /// comment threads instead of two copies.
    var relativeDescription: String {
        Self.relativeFormatter.localizedString(for: self, relativeTo: .now)
    }
}
