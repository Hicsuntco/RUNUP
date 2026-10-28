import SwiftUI
import UIKit

/// Ajouter une course que l'app ne connaît pas encore.
///
/// CE QUI N'EST PAS DEMANDÉ. Le minimum est un nom et une date, rien de plus — c'est la limite du
/// serveur, et c'est voulu. Quelqu'un qui vient d'échouer à trouver sa course est à un formulaire
/// de distance de renoncer : la distance, le dénivelé, la ville et le site sont tous facultatifs,
/// et n'importe qui pourra les compléter plus tard sur la même page.
///
/// LE DOUBLON NE REMONTE PAS COMME UNE ERREUR. Si la course existe déjà — même nom replié, même
/// date — le serveur rend l'existante au lieu de refuser, et cet écran ouvre sa page comme si elle
/// venait d'être créée. C'est exactement ce qu'on veut qu'il vive : deux personnes qui préparent la
/// même course doivent atterrir sur la MÊME page, et celle qui tape un nom déjà pris n'a aucune
/// raison d'apprendre qu'elle a failli créer un doublon.
struct CreateRaceSheet: View {
    /// Pré-rempli avec ce qui vient d'être cherché en vain : ne pas le retaper est la moitié de
    /// l'intérêt d'arriver ici depuis une recherche vide.
    var nomPropose: String
    var onCreated: (RaceEvent) -> Void

    @Environment(AppState.self) private var appState

    @State private var nom = ""
    @State private var ville = ""
    @State private var date = Date().addingTimeInterval(60 * 60 * 24 * 60)
    @State private var distance = ""
    @State private var denivele = ""
    @State private var discipline = "run"
    @State private var site = ""
    @State private var enCours = false
    @State private var erreur: String?

    private static let disciplines = ["run", "trail", "hyrox", "triathlon"]

    private var nomPropre: String { nom.trimmingCharacters(in: .whitespaces) }

    /// Le format du serveur, et le JOUR CHOISI : le fuseau courant est volontaire ici — on veut le
    /// jour tel qu'il a été tapé sur le sélecteur, pas sa traduction en UTC, qui en reculerait
    /// d'un pour tout l'hémisphère est.
    private static let jourServeur: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Ajouter une course")
                    .font(RUFont.display(.title))
                    .foregroundColor(RUColor.textPrimary)

                champ(titre: String(localized: "Nom de la course"), texte: $nom,
                      exemple: String(localized: "Marathon de Paris"))

                VStack(alignment: .leading, spacing: 6) {
                    etiquette(String(localized: "Date"))
                    DatePicker("", selection: $date, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(RUColor.rose)
                }

                VStack(alignment: .leading, spacing: 6) {
                    etiquette(String(localized: "Type d'épreuve"))
                    Picker("", selection: $discipline) {
                        ForEach(Self.disciplines, id: \.self) { clef in
                            Text(Self.libelle(clef)).tag(clef)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                champ(titre: String(localized: "Ville"), texte: $ville,
                      exemple: String(localized: "Paris"), facultatif: true)

                HStack(spacing: 10) {
                    champ(titre: String(localized: "Distance (km)"), texte: $distance,
                          exemple: "42,2", facultatif: true, clavier: .decimalPad)
                    champ(titre: String(localized: "D+ (m)"), texte: $denivele,
                          exemple: "1200", facultatif: true, clavier: .numberPad)
                }

                champ(titre: String(localized: "Site officiel"), texte: $site,
                      exemple: "https://…", facultatif: true, clavier: .URL)

                if let erreur {
                    Text(erreur)
                        .font(RUFont.sans(.body))
                        .foregroundColor(RUColor.ember)
                }

                Text("Tout le monde pourra la trouver et la suivre. Les champs laissés vides se complètent plus tard.")
                    .font(RUFont.sans(.small))
                    .foregroundColor(RUColor.text3)
            }
            .padding(RUSpacing.pagePadding)
        }
        .background(RUColor.pageBackground)
        // Le geste pour lequel cette feuille est ouverte, épinglé — voir `ruBarreDuBas`.
        .ruBarreDuBas {
            Button(action: { Task { await creer() } }) {
                Text(enCours ? String(localized: "Création…") : String(localized: "CRÉER LA PAGE"))
            }
            .buttonStyle(PrimaryButtonStyle(isDisabled: nomPropre.isEmpty || enCours))
            .disabled(nomPropre.isEmpty || enCours)
        }
        .onAppear { if nom.isEmpty { nom = nomPropose } }
    }

    private static func libelle(_ clef: String) -> String {
        switch clef {
        case "trail": return String(localized: "Trail")
        case "hyrox": return String(localized: "Hyrox")
        case "triathlon": return String(localized: "Triathlon")
        default: return String(localized: "Route")
        }
    }

    private func etiquette(_ texte: String) -> some View {
        Text(texte)
            .font(RUFont.sans(.small, weight: .semibold))
            .foregroundColor(RUColor.text3)
    }

    private func champ(titre: String, texte: Binding<String>, exemple: String,
                       facultatif: Bool = false, clavier: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            etiquette(facultatif ? String(localized: "\(titre) · facultatif") : titre)
            TextField(exemple, text: texte)
                .textFieldStyle(.plain)
                .font(RUFont.sans(.emphasis))
                .foregroundColor(RUColor.textPrimary)
                .keyboardType(clavier)
                .autocorrectionDisabled()
                .textInputAutocapitalization(clavier == .URL ? .never : .sentences)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func creer() async {
        guard !nomPropre.isEmpty else { return }
        enCours = true
        erreur = nil
        // La virgule décimale est ce que donne le clavier français. `Double("42,2")` rend nil.
        let km = Double(distance.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
        let dplus = Int(denivele.trimmingCharacters(in: .whitespaces))
        do {
            let course = try await ClubService(auth: appState.auth).createRace(
                name: nomPropre,
                city: ville.trimmingCharacters(in: .whitespaces),
                raceDate: Self.jourServeur.string(from: date),
                distanceKm: km,
                elevationGainM: dplus,
                discipline: discipline,
                website: site.trimmingCharacters(in: .whitespaces)
            )
            Haptics.impact(.light)
            // Pas de `dismiss()` ici : c'est l'écran appelant qui referme cette feuille, puis
            // ouvre la page de la course. Les deux à la fois feraient refermer deux fois.
            onCreated(course)
        } catch ClubServiceError.badResponse(422, _) {
            erreur = String(localized: "Ce nom ne passe pas. Mets le nom officiel de la course.")
        } catch ClubServiceError.badResponse(429, _) {
            erreur = String(localized: "Trop de courses créées aujourd'hui. Réessaie demain.")
        } catch {
            erreur = String(localized: "Impossible de créer la course — \(PanneReseau.motif(pour: error)).")
        }
        enCours = false
    }
}
