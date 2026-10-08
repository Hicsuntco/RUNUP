import AVFoundation
import CoreVideo
import SwiftUI

/// Fabrique le fichier vidéo d'une course.
///
/// # ON NE CAPTURE PAS L'ÉCRAN, ON FABRIQUE LES IMAGES
///
/// La méthode qui vient à l'esprit — enregistrer l'écran pendant que l'animation se joue — est un
/// nid à problèmes : la vidéo dépend alors de la vitesse à laquelle l'appareil rend chaque image,
/// donc un téléphone chargé rend une vidéo qui saccade, et l'enregistrement d'écran demande une
/// autorisation et fait apparaître un indicateur dans la barre d'état.
///
/// On fabrique donc les trois cent soixante images nous-mêmes et on les donne à l'encodeur. Rien
/// n'est enregistré « en direct » : une image lente est simplement une image lente, la vidéo
/// reste à trente images par seconde. C'est le même raisonnement que la vidéo de voyage de Hukaia,
/// et pour les mêmes raisons.
///
/// # POURQUOI ÇA TOURNE SUR L'ACTEUR PRINCIPAL, ET POURQUOI ÇA NE GÈLE PAS
///
/// `ImageRenderer` est isolé sur l'acteur principal : il rasterise une vue SwiftUI, donc il doit
/// vivre là où vivent les vues. Trois cent soixante rasterisations d'affilée gèleraient l'écran
/// une dizaine de secondes.
///
/// D'où le `await Task.yield()` entre deux images. Il ne rend pas le travail plus rapide — il rend
/// la main à SwiftUI assez souvent pour que l'anneau de progression tourne et que le bouton
/// « Annuler » réponde. Sans lui, la seule chose que l'utilisatrice verrait serait une app figée.
@MainActor
enum RunVideoRenderer {

    enum Echec: Error {
        /// Cette sortie ne donne pas de vidéo — pas de tracé, ou un tracé qui ne survit pas au
        /// rognage de confidentialité. Voir `RunVideoTimeline.pour`.
        case sortieSansVideo
        /// L'encodeur a refusé de démarrer, ou s'est arrêté en route.
        case encodeur(String)
        /// Annulée par l'appelante.
        case annulee
    }

    /// Le fichier produit, prêt à partager.
    ///
    /// `progression` est appelée sur l'acteur principal, de 0 à 1 — c'est elle qui alimente
    /// l'anneau. `url` est un fichier temporaire : l'appelante le passe à la feuille de partage,
    /// et le système le recopie où il faut.
    /// `progression` est appelée sur l'acteur principal — toute cette fonction y vit — donc elle
    /// peut toucher directement l'état d'une vue.
    static func fabrique(_ run: RunRecord,
                         progression: (Double) -> Void = { _ in }) async throws -> URL {
        guard let rendu = RunVideoTimeline.pour(run) else { throw Echec.sortieSansVideo }

        let largeur = Int(RunVideoFrameView.taille.width * RunVideoFrameView.echelle)
        let hauteur = Int(RunVideoFrameView.taille.height * RunVideoFrameView.echelle)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("runup-\(UUID().uuidString).mp4")

        let ecrivain = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let entree = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: largeur,
            AVVideoHeightKey: hauteur,
            AVVideoCompressionPropertiesKey: [
                // Huit mégabits par seconde : douze secondes font une douzaine de mégaoctets, ce
                // qui passe partout, et le dégradé du fond ne montre pas de bandes.
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ])
        // FAUX, et c'est important : « en temps réel » dit à l'encodeur de jeter les images qu'il
        // n'arrive pas à suivre, ce qui est juste pour une caméra et catastrophique ici — on
        // perdrait des images du milieu de l'animation. À faux, il fait attendre l'appelant.
        entree.expectsMediaDataInRealTime = false

        let adaptateur = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: entree,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: largeur,
                kCVPixelBufferHeightKey as String: hauteur
            ])

        guard ecrivain.canAdd(entree) else { throw Echec.encodeur("entrée vidéo refusée") }
        ecrivain.add(entree)
        guard ecrivain.startWriting() else {
            throw Echec.encodeur(ecrivain.error?.localizedDescription ?? "démarrage refusé")
        }
        ecrivain.startSession(atSourceTime: .zero)

        let cadence = CMTimeScale(RunVideoTimeline.imagesParSeconde)
        do {
            for (index, instant) in rendu.instants.enumerated() {
                try Task.checkCancellation()
                guard let image = rasterise(run: run, route: rendu.route, instant: instant) else {
                    throw Echec.encodeur("image \(index) non rasterisée")
                }
                try await attendQueLEntreeSoitPrete(entree, ecrivain: ecrivain)
                guard let tampon = tampon(pour: image, adaptateur: adaptateur,
                                          largeur: largeur, hauteur: hauteur) else {
                    throw Echec.encodeur("tampon de pixels indisponible")
                }
                let instantVideo = CMTime(value: CMTimeValue(index), timescale: cadence)
                guard adaptateur.append(tampon, withPresentationTime: instantVideo) else {
                    throw Echec.encodeur(ecrivain.error?.localizedDescription ?? "image refusée")
                }
                progression(Double(index + 1) / Double(rendu.instants.count))
                // Voir l'en-tête : c'est ce qui laisse l'écran respirer.
                await Task.yield()
            }
        } catch is CancellationError {
            entree.markAsFinished()
            ecrivain.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            throw Echec.annulee
        } catch {
            entree.markAsFinished()
            ecrivain.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            throw error
        }

        entree.markAsFinished()
        await termine(ecrivain)
        guard ecrivain.status == .completed else {
            try? FileManager.default.removeItem(at: url)
            throw Echec.encodeur(ecrivain.error?.localizedDescription ?? "écriture incomplète")
        }
        return url
    }

    // MARK: Les trois pièces mécaniques

    private static func rasterise(run: RunRecord, route: [RunRecord.RoutePoint],
                                  instant: RunVideoTimeline.Instant) -> CGImage? {
        let rendeur = ImageRenderer(content: RunVideoFrameView(run: run, route: route, instant: instant))
        rendeur.scale = RunVideoFrameView.echelle
        // Opaque : une vidéo n'a pas de couche alpha utilisable, et un fond transparent sort noir.
        rendeur.isOpaque = true
        return rendeur.cgImage
    }

    /// Un tampon de pixels, peint avec l'image.
    ///
    /// L'ordre des octets n'est pas décoratif : l'adaptateur a demandé du `32BGRA`, donc le
    /// contexte doit écrire du BGRA — `byteOrder32Little` avec l'alpha en tête. Avec le réglage
    /// par défaut, les rouges et les bleus s'échangent, et le rose de marque sort turquoise.
    private static func tampon(pour image: CGImage,
                               adaptateur: AVAssetWriterInputPixelBufferAdaptor,
                               largeur: Int, hauteur: Int) -> CVPixelBuffer? {
        guard let reserve = adaptateur.pixelBufferPool else { return nil }
        var tampon: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, reserve, &tampon) == kCVReturnSuccess,
              let tampon else { return nil }

        CVPixelBufferLockBaseAddress(tampon, [])
        defer { CVPixelBufferUnlockBaseAddress(tampon, []) }
        guard let base = CVPixelBufferGetBaseAddress(tampon),
              let contexte = CGContext(
                data: base,
                width: largeur,
                height: hauteur,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(tampon),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }

        contexte.draw(image, in: CGRect(x: 0, y: 0, width: largeur, height: hauteur))
        return tampon
    }

    /// Attend que l'encodeur veuille bien d'une image de plus.
    ///
    /// Avec `expectsMediaDataInRealTime = false` il suit presque toujours, mais « presque » n'est
    /// pas « toujours » : une image poussée quand l'entrée n'est pas prête est refusée, et la
    /// vidéo perd une image au milieu de l'animation.
    private static func attendQueLEntreeSoitPrete(_ entree: AVAssetWriterInput,
                                                  ecrivain: AVAssetWriter) async throws {
        while !entree.isReadyForMoreMediaData {
            try Task.checkCancellation()
            guard ecrivain.status == .writing else {
                throw Echec.encodeur(ecrivain.error?.localizedDescription ?? "écrivain arrêté")
            }
            try? await Task.sleep(for: .milliseconds(4))
        }
    }

    /// `finishWriting` ne rend la main qu'à la fin de l'écriture, et seulement par rappel sur les
    /// versions d'iOS que cette app accepte. Une continuation plutôt qu'une attente active.
    private static func termine(_ ecrivain: AVAssetWriter) async {
        await withCheckedContinuation { suite in
            ecrivain.finishWriting { suite.resume() }
        }
    }
}
