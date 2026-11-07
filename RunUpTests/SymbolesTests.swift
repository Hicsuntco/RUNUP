import XCTest
import UIKit
@testable import RunUp

/// CHAQUE SYMBOLE NOMMÉ PAR L'APP EXISTE-T-IL VRAIMENT ?
///
/// `Image(systemName: "mountain.2.fill")` sur un nom qui n'existe pas ne lève rien, ne journalise
/// rien, et ne dessine RIEN. Un `Image` vide de la bonne taille : la mise en page ne bouge pas, la
/// construction est verte, les tests passent. Le défaut ne se voit qu'en regardant l'écran
/// concerné — autant dire jamais pour un écran qu'on ne photographie pas.
///
/// `UIImage(systemName:)` rend `nil` sur un nom inconnu, et c'est la seule façon de poser la
/// question : le catalogue des symboles appartient au système, pas au dépôt. Un script ne peut
/// donc pas y répondre, et `ci_scripts/check_symboles.py` ne fait que garantir que la liste
/// ci-dessous est EXACTEMENT celle que le code emploie — sans quoi cette barrière resterait verte
/// en ignorant le symbole ajouté la veille.
///
/// # CE QUE CE TEST NE COUVRE PAS
///
/// Un symbole introduit dans une version d'iOS plus récente que la cible de déploiement passe ici
/// — le simulateur est à jour — et reste vide sur un téléphone plus ancien. La parade n'est pas
/// mécanique : elle est de préférer des noms anciens.
final class SymbolesTests: XCTestCase {

    /// Tenue à jour par `ci_scripts/check_symboles.py`, qui refuse la construction si elle
    /// s'écarte des `systemName:` du code — dans un sens comme dans l'autre.
    static let tous: [String] = [
        "apple.logo",
        "applewatch",
        "arrow.clockwise",
        "arrow.down.doc",
        "arrow.right.to.line",
        "arrow.triangle.2.circlepath",
        "arrow.triangle.swap",
        "arrow.up",
        "arrow.up.circle.fill",
        "arrow.up.left.and.arrow.down.right",
        "arrow.up.right",
        "arrow.uturn.backward",
        "bell",
        "bell.slash",
        "bicycle",
        "bolt.fill",
        "bookmark",
        "bookmark.fill",
        "bubble.right",
        "calendar",
        "calendar.badge.clock",
        "camera.fill",
        "chart.line.uptrend.xyaxis",
        "checkmark",
        "checkmark.circle.fill",
        "chevron.down",
        "chevron.left",
        "chevron.right",
        "chevron.up.chevron.down",
        "circle",
        "drop.fill",
        "dumbbell.fill",
        "ellipsis",
        "envelope",
        "exclamationmark.bubble",
        "exclamationmark.triangle",
        "exclamationmark.triangle.fill",
        "figure.hiking",
        "figure.pool.swim",
        "figure.run",
        "film",
        "flag.checkered",
        "flame.fill",
        "gearshape.fill",
        "hands.clap",
        "hands.clap.fill",
        "heart.fill",
        "infinity",
        "key.horizontal",
        "largecircle.fill.circle",
        "leaf.fill",
        "link",
        "list.bullet",
        "list.bullet.clipboard",
        "location.fill",
        "location.magnifyingglass",
        "location.slash",
        "location.slash.fill",
        "lock.fill",
        "lock.rectangle",
        "lock.shield",
        "lock.slash",
        "magnifyingglass",
        "map",
        "map.fill",
        "mappin",
        "mic.fill",
        "minus",
        "moon.zzz.fill",
        "mountain.2.fill",
        "pause.circle",
        "pause.fill",
        "pencil.circle.fill",
        "person.2.fill",
        "person.2.slash",
        "person.3.fill",
        "person.crop.circle",
        "person.crop.circle.badge.questionmark",
        "photo",
        "photo.on.rectangle",
        "play.fill",
        "play.rectangle.fill",
        "plus",
        "rectangle.portrait.and.arrow.right",
        "scalemass",
        "shoeprints.fill",
        "sparkles",
        "speaker.wave.2",
        "speaker.wave.2.fill",
        "speedometer",
        "square.and.arrow.up",
        "square.grid.3x1.below.line.grid.1x2",
        "square.stack.3d.up",
        "square.stack.3d.up.fill",
        "stop.fill",
        "target",
        "ticket",
        "trash",
        "trophy.fill",
        "waveform",
        "xmark",
        "xmark.circle.fill",
    ]

    func testTousLesSymbolesNommesExistent() {
        var inconnus: [String] = []
        for nom in Self.tous where UIImage(systemName: nom) == nil {
            inconnus.append(nom)
        }
        XCTAssertTrue(inconnus.isEmpty,
                      "symbole(s) inexistant(s), donc icône(s) invisible(s) : \(inconnus.joined(separator: ", "))")
    }

    /// Une liste vide passerait le test ci-dessus sans rien vérifier.
    func testLaListeNEstPasVide() {
        XCTAssertGreaterThan(Self.tous.count, 50, "la liste des symboles s'est vidée")
    }
}
