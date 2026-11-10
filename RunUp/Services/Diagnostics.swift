import Foundation
import MetricKit
import UIKit

/// Un rapport de panne prêt à partir, exactement comme `api/crashes.js` l'attend.
///
/// Tout est optionnel sauf le genre et l'instant, et c'est voulu : les métadonnées viennent de
/// `MXMetaData`, qui peut rendre une chaîne vide, et une ligne qui dit seulement « l'app a
/// planté le 8 novembre » vaut infiniment mieux qu'aucune ligne.
private struct RapportDePanne: Codable, Sendable {
    var kind: String
    var appVersion: String?
    var appBuild: String?
    var osVersion: String?
    var deviceType: String?
    var isTestflight: Bool?
    /// Une ligne lisible à l'œil nu — le signal, le type d'exception, la durée d'un gel. Elle
    /// existe pour qu'une ligne de la table se lise sans ouvrir `payload`, qui fait des dizaines
    /// de kilo-octets de piles d'appels non symbolisées.
    var note: String?
    /// Le JSON que MetricKit rend lui-même (`MXDiagnostic.jsonRepresentation()`), en texte. C'est
    /// lui qui porte la pile d'appels, et c'est la seule chose qui permette de symboliser la
    /// panne plus tard avec le dSYM de la version concernée. Envoyé comme CHAÎNE, pas comme objet
    /// imbriqué : le serveur le reparse et le pose en `jsonb`, ce qui lui donne un endroit où
    /// refuser proprement un JSON abîmé au lieu de faire tomber tout le lot.
    var payload: String?
    var occurredAt: Date
}

private struct LotDePannes: Encodable, Sendable {
    var anonymousId: String
    var reports: [RapportDePanne]
}

/// LE RAPPORT DE PANNE DE RUNUP, SANS AUCUN SDK TIERS — ET SANS GESTIONNAIRE DE SIGNAL.
///
/// # CE QUI A ÉTÉ ÉCARTÉ, ET POURQUOI C'EST LA DÉCISION CENTRALE DE CE FICHIER
///
/// La façon dont presque tous les rapporteurs de panne fonctionnent — poser un
/// `NSSetUncaughtExceptionHandler` et des `sigaction` sur SIGSEGV, SIGABRT, SIGBUS, SIGILL,
/// écrire un fichier depuis le gestionnaire, l'envoyer au lancement suivant — a été étudiée puis
/// REJETÉE. Pas par paresse : parce qu'Apple explique en détail qu'elle ne peut pas marcher.
///
/// Quinn « The Eskimo! », de l'assistance aux développeurs d'Apple, dans
/// « Implementing Your Own Crash Reporter » (developer.apple.com/forums/thread/113742) :
///
///   « I strongly advise against implementing your own crash reporter. […] It's impossible to
///     implement a *good* crash reporter, one that's reliable, binary compatible, and sufficient
///     to debug complex problems. »
///
///   « On iOS […] your crash reporter must run inside the crashed process. That means it can
///     never be 100% reliable. »
///
///   « your signal handler can only use *async signal safe* functions. [Cette liste] does not
///     include `malloc`. This means that a crash reporter's signal handler cannot use Objective-C
///     or Swift. »
///
///   « `backtrace` is not an async signal safe function. »
///
/// Cette dernière phrase à elle seule termine le débat : sans `backtrace`, un gestionnaire de
/// signal ne peut pas relever la pile d'appels, et un rapport de panne sans pile d'appels ne sert
/// à rien. Le reste — pas de `malloc`, donc ni Swift ni Objective-C dans le gestionnaire — veut
/// dire que tout le code serait du C contraint, impossible à relire, impossible à tester ici, et
/// capable de casser le rapporteur d'Apple lui-même :
///
///   « You must ensure that your crash reporter doesn't disrupt the Apple crash reporter. »
///
/// Et la sortie recommandée est nommée dans le même texte :
///
///   « I recommend that you lean in to Apple's crash reporter. […] iOS 14 and macOS 12 report
///     crashes in MetricKit. This is a *very* cool feature, and I'm surprised by how few people
///     use it effectively. »
///
/// # CE QUE FAIT CE FICHIER, DONC
///
/// Il s'abonne à MetricKit. iOS collecte la panne HORS du processus mort — c'est le même
/// mécanisme que les rapports de l'organiseur Xcode — et nous la rend au lancement suivant sous
/// forme de `MXDiagnosticPayload`. On n'écrit rien dans un gestionnaire de signal, on ne touche
/// pas au rapporteur du système, et la pile d'appels est celle d'Apple.
///
/// Cinq genres arrivent par ce canal, pas seulement les plantages : les gels (`hang`), les
/// dépassements de processeur, les écritures disque excessives, et les lancements trop lents.
/// Les quatre derniers sont exactement les défauts qu'un rapporteur de panne classique ne voit
/// JAMAIS, parce que l'app ne meurt pas : elle devient mauvaise. On les prend tous.
///
/// # CE QU'IL NE FAIT PAS
///
/// · Il ne voit pas les pannes qu'on rattrape soi-même. Les 160 `try?` et 132 `catch` de l'app
///   avalent des erreurs qu'aucun MetricKit ne rapportera jamais, parce que de son point de vue
///   rien n'a mal tourné. C'est un chantier séparé, et il commence par un audit de ces sites —
///   pas par du code ici.
/// · Il ne regroupe pas. Pas de colonne « signature », pas de compteur d'occurrences : ça
///   demanderait de symboliser côté serveur, et à l'échelle actuelle on lit les lignes. Le seuil
///   à partir duquel ça devient faux est simple à énoncer : le jour où une requête sur
///   `crash_reports` rend plus de lignes qu'on n'en lit à l'œil.
/// · Il ne voit rien sur le simulateur : MetricKit ne collecte que sur un appareil réel.
/// · Il n'est pas instantané. Une panne arrive au lancement SUIVANT — Apple écrit « Diagnostic
///   reports arrive immediately in iOS 15 and later », ce qui veut dire « dès que disponible »,
///   et pour un plantage c'est forcément après la relance.
///
/// # L'API UTILISÉE EST DÉPRÉCIÉE À PARTIR D'iOS 27, ET C'EST LE BON CHOIX QUAND MÊME
///
/// `MXMetricManager` et les classes `MX*` sont remplacées en iOS 27 par `MetricManager` et sa
/// suite asynchrone `diagnosticReports`. On vise iOS 17 (voir `project.yml`), donc la nouvelle
/// API n'existe pas pour la quasi-totalité du parc. Les classes `MX*` restent disponibles depuis
/// iOS 14. Le jour où le plancher passe à 27, la migration est ici et nulle part ailleurs.
///
/// # LES TROIS MÊMES RÈGLES QUE `Analytics`
///
/// Jumeau volontaire d'`Analytics` : même file privée, même tampon sur disque, même endpoint
/// discipliné. Ce n'est pas de la copie, c'est la même forme pour le même problème — un écrivain
/// réseau qui ne doit jamais bloquer, jamais planter, et jamais perdre son tampon.
final class Diagnostics: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = Diagnostics()

    /// Le vocabulaire complet. Chaque valeur doit aussi figurer dans `KNOWN_KINDS` de
    /// `api/crashes.js`, qui jette tout le reste — et `ci_scripts/check_pannes.py` compare les
    /// deux listes dans les deux sens, parce que la même duplication a déjà coûté onze
    /// événements d'analytique jetés en silence pendant des mois.
    enum Genre: String {
        case plantage = "crash"
        case gel = "hang"
        case processeur = "cpu_exception"
        case disque = "disk_write_exception"
        case lancement = "app_launch"
    }

    private static let baseURL = URL(string: "https://runup-nu.vercel.app")!
    private static let bufferKey = "diagnostics.buffer.v1"

    /// Doit rester sous `MAX_REPORTS_PER_BATCH` de `api/crashes.js`, qui refuse un lot plus gros.
    private static let maxReportsPerBatch = 5
    /// Au-delà, les PLUS ANCIENS partent. Un appareil hors ligne qui plante en boucle ne doit pas
    /// faire grossir `UserDefaults` sans fin, et les derniers plantages sont les plus utiles.
    private static let maxBufferedReports = 20
    /// Doit rester sous `MAX_PAYLOAD_CHARS` de `api/crashes.js`. Au-dessus, la ligne part SANS sa
    /// pile d'appels plutôt que de ne pas partir : le compte des plantages par version est déjà
    /// une information, et une pile tronquée ne serait plus du JSON.
    private static let maxPayloadChars = 120_000

    private let queue = DispatchQueue(label: "com.hicsuntco.runup.diagnostics")
    private let defaults = UserDefaults.standard
    /// Jamais touché ailleurs que sur `queue` — c'est cette sérialisation qui rend le
    /// `@unchecked Sendable` ci-dessus exact plutôt que commode.
    private var buffer: [RapportDePanne]
    private var isFlushing = false

    private override init() {
        buffer = Self.loadBuffer(from: UserDefaults.standard)
        super.init()
    }

    /// À appeler une fois au lancement. Deux choses : s'abonner à MetricKit, et vider ce qu'un
    /// lancement précédent n'a pas réussi à envoyer (le cas NORMAL pour un plantage — l'app est
    /// morte avant d'avoir pu poster).
    func demarrer() {
        // Les captures d'écran ne plantent pas, et surtout ne doivent rien écrire dans la table.
        // Même garde qu'`Analytics.enqueue`, même raison. Voir `Demonstration`.
        guard !Demonstration.enCours else { return }
        MXMetricManager.shared.add(self)
        // Un retour au premier plan est la SECONDE chance d'envoyer, et elle compte : au
        // lancement à froid, le réseau n'est pas toujours debout, et un rapport qui n'est pas
        // parti reste sur disque jusqu'à ce que quelqu'un le repousse. Même paire d'observateurs
        // et même raison que dans `Analytics`.
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                               object: nil, queue: nil) { [weak self] _ in
            self?.flush()
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                               object: nil, queue: nil) { [weak self] _ in
            self?.flush()
        }
        flush()
    }

    // MARK: - MXMetricManagerSubscriber

    /// Le canal des diagnostics : un plantage, un gel, un dépassement de processeur, une écriture
    /// disque excessive, un lancement trop lent.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let lignes = payloads.flatMap(Self.rapports(dans:))
        guard !lignes.isEmpty else { return }
        queue.async { [self] in
            for ligne in lignes { enqueue(ligne) }
            sendNextBatch()
        }
    }

    /// Le canal des MESURES quotidiennes — temps de lancement, énergie, réseau, mémoire. Rien
    /// ici ne les consomme : ce fichier est le rapport de PANNE, et une moyenne quotidienne de
    /// consommation n'en est pas une.
    ///
    /// Implémentée quand même, vide, pour une raison qui n'a rien d'élégant : `MXMetricManager`
    /// ne se compile pas dans ce conteneur (aucune chaîne Swift ici), et rien ne permet donc de
    /// vérifier laquelle des deux méthodes du protocole est optionnelle. Trois lignes mortes
    /// coûtent moins qu'un cycle de douze minutes d'intégration continue pour l'apprendre.
    func didReceive(_ payloads: [MXMetricPayload]) {}

    // MARK: - La traduction d'un lot MetricKit en lignes de table

    /// Un `MXDiagnosticPayload` porte CINQ listes de diagnostics, chacune éventuellement vide.
    /// On en fait une ligne par diagnostic : c'est le grain auquel on veut compter, et le genre
    /// doit valoir une seule chose par ligne pour qu'une requête par genre ait un sens.
    private static func rapports(dans payload: MXDiagnosticPayload) -> [RapportDePanne] {
        // `timeStampEnd` est la fin de la fenêtre couverte par le lot : la seule date que
        // MetricKit donne. Un diagnostic n'en porte pas lui-même, donc tous ceux d'un même lot
        // partagent celle-là. C'est honnête à la fenêtre près, et il n'y a rien de mieux.
        let instant = payload.timeStampEnd
        var tout: [RapportDePanne] = []
        for diagnostic in payload.crashDiagnostics ?? [] {
            tout.append(rapport(diagnostic, .plantage, note: note(dUnPlantage: diagnostic), instant))
        }
        for diagnostic in payload.hangDiagnostics ?? [] {
            tout.append(rapport(diagnostic, .gel, note: "gel \(millisecondes(diagnostic.hangDuration))ms", instant))
        }
        for diagnostic in payload.cpuExceptionDiagnostics ?? [] {
            tout.append(rapport(diagnostic, .processeur, note: nil, instant))
        }
        for diagnostic in payload.diskWriteExceptionDiagnostics ?? [] {
            tout.append(rapport(diagnostic, .disque, note: nil, instant))
        }
        for diagnostic in payload.appLaunchDiagnostics ?? [] {
            tout.append(rapport(diagnostic, .lancement, note: "lancement \(millisecondes(diagnostic.launchDuration))ms", instant))
        }
        return tout
    }

    private static func rapport(_ diagnostic: MXDiagnostic, _ genre: Genre,
                                note: String?, _ instant: Date) -> RapportDePanne {
        let meta = diagnostic.metaData
        return RapportDePanne(
            kind: genre.rawValue,
            appVersion: vide(diagnostic.applicationVersion),
            appBuild: vide(meta.applicationBuildVersion),
            osVersion: vide(meta.osVersion),
            deviceType: vide(meta.deviceType),
            isTestflight: meta.isTestFlightApp,
            note: note,
            payload: charge(diagnostic),
            occurredAt: instant
        )
    }

    /// Le JSON d'Apple, ou rien du tout. Jamais une version tronquée : du JSON coupé au milieu
    /// n'est plus du JSON, et le serveur le refuserait — en emportant la ligne avec lui.
    private static func charge(_ diagnostic: MXDiagnostic) -> String? {
        guard let texte = String(data: diagnostic.jsonRepresentation(), encoding: .utf8) else { return nil }
        guard texte.count <= maxPayloadChars else { return nil }
        return texte
    }

    /// Les trois champs qui disent de quoi un plantage est mort. `signal` et `exceptionType` sont
    /// des `NSNumber?` chez Apple — un plantage peut n'avoir ni l'un ni l'autre (une terminaison
    /// par le gardien de mémoire, par exemple), d'où les optionnels jusqu'au bout.
    private static func note(dUnPlantage diagnostic: MXCrashDiagnostic) -> String? {
        var morceaux: [String] = []
        if let signal = diagnostic.signal { morceaux.append("signal \(signal.intValue)") }
        if let type = diagnostic.exceptionType { morceaux.append("exception \(type.intValue)") }
        if let code = diagnostic.exceptionCode { morceaux.append("code \(code.intValue)") }
        if let raison = vide(diagnostic.terminationReason) { morceaux.append(raison) }
        return morceaux.isEmpty ? nil : morceaux.joined(separator: " / ")
    }

    /// Une durée en millisecondes entières. Pas de virgule, donc pas de séparateur décimal qui
    /// changerait avec la langue de l'appareil : cette chaîne part vers une table où l'on compte,
    /// pas vers un écran.
    private static func millisecondes(_ duree: Measurement<UnitDuration>) -> Int {
        Int(duree.converted(to: .milliseconds).value.rounded())
    }

    /// `MXMetaData` rend des `String` non optionnelles, qui peuvent être vides. Une colonne vide
    /// et une colonne nulle ne se filtrent pas pareil ; `NULL` est la vérité.
    private static func vide(_ texte: String?) -> String? {
        guard let texte, !texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return texte
    }

    // MARK: - L'envoi

    /// Envoie ce qui est en attente. Appelée par `demarrer()` et à chaque arrivée de MetricKit ;
    /// sans danger avec un tampon vide.
    func flush() {
        queue.async { [self] in sendNextBatch() }
    }

    // MARK: - Tout ce qui suit tourne sur `queue`

    private func enqueue(_ rapport: RapportDePanne) {
        buffer.append(rapport)
        if buffer.count > Self.maxBufferedReports {
            buffer.removeFirst(buffer.count - Self.maxBufferedReports)
        }
        persistBuffer()
    }

    private func persistBuffer() {
        guard let data = try? Self.encoder.encode(buffer) else { return }
        defaults.set(data, forKey: Self.bufferKey)
    }

    private func sendNextBatch() {
        guard !isFlushing, !buffer.isEmpty else { return }
        let lot = Array(buffer.prefix(Self.maxReportsPerBatch))
        guard let body = try? Self.encoder.encode(
            LotDePannes(anonymousId: Analytics.shared.anonymousID, reports: lot)
        ) else {
            // Un corps qui ne s'encode pas ne s'encodera pas mieux plus tard : le garder
            // coincerait le tampon derrière une ligne qui ne peut plus en sortir.
            buffer.removeFirst(min(lot.count, buffer.count))
            persistBuffer()
            return
        }

        var request = URLRequest(url: Self.baseURL.appending(path: "api/crashes"))
        request.timeoutInterval = Delais.arrierePlan
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        // Facultatif des deux côtés, comme pour l'analytique : la plupart des gens n'ont pas de
        // compte, et une panne chez quelqu'un qui n'est pas connecté compte autant. Quand le
        // jeton est là, la ligne porte le compte — c'est ce qui permet de répondre à « mon app
        // plante » par autre chose qu'une question.
        if let token = KeychainService.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        isFlushing = true
        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            guard let self else { return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            self.queue.async {
                self.isFlushing = false
                // Livré, ou refusé d'une façon que réessayer ne corrigera pas — dans les deux cas
                // ça doit quitter le tampon, sinon le client renverrait le même lot refusé à
                // chaque lancement et bloquerait tout ce qui est derrière. 429 est la seule
                // exception : celle-là est vraiment temporaire.
                let livre = (200..<300).contains(status)
                let refuseDefinitivement = (400..<500).contains(status) && status != 429
                guard livre || refuseDefinitivement else { return }
                self.buffer.removeFirst(min(lot.count, self.buffer.count))
                self.persistBuffer()
                self.sendNextBatch()
            }
        }.resume()
    }

    // MARK: -

    private static func loadBuffer(from defaults: UserDefaults) -> [RapportDePanne] {
        guard let data = defaults.data(forKey: bufferKey),
              let items = try? decoder.decode([RapportDePanne].self, from: data) else { return [] }
        return items
    }

    /// `.iso8601` des deux côtés — le même format que `api/crashes.js` analyse dans `occurredAt`.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
