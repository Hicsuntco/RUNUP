import SwiftUI

/// Une image de la vidéo d'une course.
///
/// # UNE VUE SWIFTUI, PAS UN DESSIN CORE GRAPHICS
///
/// Fabriquer les images à la main dans un `CGContext` aurait voulu dire réécrire la typographie,
/// le dégradé de marque et surtout le tracé — alors que `DrawnRoute` dessine déjà exactement ça,
/// avec sa tête lumineuse et sa trace fantôme, et qu'il est la seule chose à l'écran qui raconte
/// quelque chose que la personne a vraiment fait. Un second dessin aurait donné deux parcours
/// légèrement différents pour la même course.
///
/// `ImageRenderer` rasterise donc cette vue, image par image — c'est déjà ainsi que `RecapView`
/// exporte la carte de partage.
///
/// # DESSINÉE EN 360 × 640, RENDUE EN 1080 × 1920
///
/// Et c'est la même raison que la carte de partage, qui tient elle aussi dans 360 × 640 : les
/// tailles du système typographique de l'app sont en POINTS, pensées pour un écran de téléphone.
/// Composer directement en 1080 de large donnerait un titre de 18 points dans une image trois
/// fois plus large — illisible, et il faudrait un second barème de tailles qui dériverait du
/// premier. On compose donc à l'échelle de l'app et `ImageRenderer` multiplie par trois.
///
/// # LES COULEURS SONT ÉPINGLÉES, PAS PRISES DU THÈME
///
/// Même choix que `RunShareCardView`, et pour la même raison : une vidéo qu'on poste porte la
/// MARQUE, pas la préférence d'accent de qui la poste. Si elle a choisi le nuancier citron vert
/// pour son app, sa vidéo ne doit pas devenir verte — les gens qui la regardent n'ont pas l'app,
/// et c'est d'elle qu'on leur parle.
struct RunVideoFrameView: View {
    var run: RunRecord
    /// Le tracé ROGNÉ, tel que `RunVideoTimeline` le rend. Cette vue ne rogne rien elle-même :
    /// elle dessine ce qu'on lui donne, et ce qu'on lui donne est déjà passé par la porte du
    /// partage.
    var route: [RunRecord.RoutePoint]
    var instant: RunVideoTimeline.Instant

    /// La taille LOGIQUE, en points. Multipliée par `echelle` à la rasterisation.
    static let taille = CGSize(width: 360, height: 640)
    /// Trois : 1080 × 1920, le neuf-seizièmes que tous les réseaux acceptent sans recadrer.
    static let echelle: CGFloat = 3

    static let rose = Color(hex: 0xFF3D9A)
    static let violet = Color(hex: 0x8A5CFF)
    static let encre = Color(hex: 0x0B0B12)

    var body: some View {
        ZStack {
            fond
            VStack(spacing: 0) {
                entete.padding(.top, 52)
                DrawnRoute(route: route,
                           lineWidth: 3.6,
                           colors: [Self.rose, Self.rose, Self.violet],
                           targetPoints: 320,
                           showsStart: true,
                           progress: instant.fractionDuTrace)
                    .frame(width: 300, height: 300)
                    .padding(.vertical, 14)
                compteurs
                Spacer(minLength: 0)
                signature.padding(.bottom, 44)
            }
        }
        .frame(width: Self.taille.width, height: Self.taille.height)
        // Le fond doit être OPAQUE, contrairement à la carte de partage : une vidéo n'a pas de
        // couche alpha utilisable, et un fond transparent sort noir — ou pire, non défini.
        .background(Self.encre)
    }

    // MARK: Les morceaux

    private var fond: some View {
        ZStack {
            Self.encre
            // Deux halos plutôt qu'un dégradé plein : le tracé est le sujet, et un aplat de
            // marque sur toute la hauteur lui disputerait l'œil.
            RadialGradient(colors: [Self.rose.opacity(0.38), .clear],
                           center: .init(x: 0.12, y: 0.10), startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Self.violet.opacity(0.32), .clear],
                           center: .init(x: 0.92, y: 0.88), startRadius: 0, endRadius: 390)
        }
    }

    private var entete: some View {
        VStack(spacing: 5) {
            Text(verbatim: run.titreAffiche)
                .font(RUFont.display(26))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 30)
            Text(verbatim: Self.dateFormatee(run.date))
                .font(RUFont.sans(.small, weight: .bold))
                .tracking(2.5)
                .foregroundColor(.white.opacity(0.62))
        }
    }

    /// Les compteurs. Le dénivelé n'apparaît QUE lorsqu'il a une valeur : afficher « 0 m D+ » sur
    /// une sortie dont on ne connaît pas le dénivelé serait un chiffre faux, et c'est précisément
    /// ce que `RunVideoTimeline` refuse de produire.
    private var compteurs: some View {
        HStack(alignment: .top, spacing: 0) {
            compteur(Text("KM"), TimeFormat.distance(km: instant.metres / 1000))
            compteur(Text("TEMPS"), TimeFormat.horloge(instant.secondes))
            if let denivele = instant.denivelePositifM {
                compteur(Text("M D+"), "\(Int(denivele.rounded()))")
            }
        }
        .padding(.horizontal, 18)
    }

    /// L'étiquette arrive en `Text` et non en `String` : c'est ce qui laisse le littéral visible
    /// dans un `Text("…")`, donc attrapable par `ci_scripts/check_strings.py`. Passé en chaîne, il
    /// aurait traversé le contrôle du catalogue sans être vu, et « TEMPS » serait sorti en
    /// français en anglais et en espagnol.
    private func compteur(_ label: Text, _ valeur: String) -> some View {
        VStack(spacing: 1) {
            label
                .font(RUFont.sans(.small, weight: .bold))
                .tracking(2.5)
                .foregroundColor(.white.opacity(0.6))
            Text(verbatim: valeur)
                .font(RUFont.display(34))
                .foregroundStyle(LinearGradient(colors: [Self.rose, Self.violet],
                                                startPoint: .leading, endPoint: .trailing))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .shadow(color: Self.rose.opacity(0.35), radius: 10)
        }
        .frame(maxWidth: .infinity)
    }

    private var signature: some View {
        HStack(spacing: 7) {
            AppMarkView(size: 24)
            Text(verbatim: "RUNUP")
                .font(RUFont.display(19))
                .tracking(3)
                .foregroundColor(.white)
        }
    }

    /// « 8 OCTOBRE 2026 », dans la langue du téléphone. Un `DateFormatter` statique : en
    /// construire un par image en fabriquerait trois cent soixante pour rien, et c'est l'objet le
    /// plus coûteux à créer de tout ce fichier.
    private static let formatteur: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        return f
    }()

    private static func dateFormatee(_ date: Date) -> String {
        formatteur.string(from: date).uppercased(with: .current)
    }
}
