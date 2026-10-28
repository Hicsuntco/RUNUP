import SwiftUI

/// REPRENDRE CE QU'ON A ÉCRIT.
///
/// # POURQUOI UNE SEULE FEUILLE POUR DEUX MURS
///
/// Un message du mur d'un club et une annonce sur une page de course sont, du point de vue de
/// qui les corrige, exactement la même chose : un bloc de texte qu'on a publié et dans lequel il
/// y a une faute, un horaire qui a changé, une phrase qu'on regrette. Deux feuilles auraient été
/// la copie l'une de l'autre — donc l'endroit où une amélioration ne serait faite qu'une fois.
///
/// Ce qui diffère entre les deux appels — le titre, la borne de longueur, l'appel réseau — passe
/// en paramètres. Le reste est identique parce qu'il DOIT l'être.
///
/// # CE QU'ELLE NE FAIT PAS
///
/// Elle ne supprime pas. Effacer et réécrire sont deux gestes dont l'un est irréversible ; les
/// mettre dans la même feuille, c'est poser un bouton rouge sous les doigts de quelqu'un qui
/// voulait corriger une virgule. La suppression reste dans le menu, avec sa confirmation.
struct EditTextPostSheet: View {
    @Environment(\.dismiss) private var dismiss

    var titreDeLaFeuille: String
    var texteInitial: String
    /// 500 côté serveur pour les deux murs. Recopié ici pour que la limite se voie AVANT l'envoi
    /// plutôt que sous la forme d'un texte tronqué après coup.
    var longueurMax: Int = 500
    var onSave: (String) async throws -> Void

    @State private var texte = ""
    @State private var prerempli = false
    @State private var enCours = false
    @State private var errorMessage: String?

    private var propre: String { texte.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// Rien à enregistrer si le texte est vide — ou s'il n'a pas changé : un bouton actif qui
    /// déclenche un aller-retour réseau pour réécrire la même chose est un bouton qui ment.
    private var peutEnregistrer: Bool {
        !propre.isEmpty && propre != texteInitial.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("", text: $texte, axis: .vertical)
                        .lineLimit(4...12)
                        .font(RUFont.sans(.emphasis))
                        .foregroundColor(RUColor.textPrimary)
                        .padding(12)
                        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous)
                            .stroke(RUColor.line, lineWidth: RUSpacing.hairline))

                    // Le compteur n'apparaît qu'à l'approche de la borne. Affiché en permanence,
                    // il transforme un champ libre en exercice de concision pour des messages
                    // qui font trois lignes.
                    if propre.count > longueurMax - 80 {
                        Text(verbatim: "\(propre.count) / \(longueurMax)")
                            .font(RUFont.mono(10))
                            .foregroundColor(propre.count > longueurMax ? RUColor.rose : RUColor.text3)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    if let errorMessage {
                        Text(errorMessage).font(RUFont.sans(.body)).foregroundColor(RUColor.rose)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(RUSpacing.pagePadding)
            }
            .background(RUColor.pageBackground)
            .navigationTitle(titreDeLaFeuille)
            .navigationBarTitleDisplayMode(.inline)
            // Une seule fois : `onAppear` repart à chaque retour de premier plan, et prendre un
            // appel au milieu d'une correction effacerait ce qui vient d'être tapé.
            .onAppear {
                guard !prerempli else { return }
                prerempli = true
                texte = texteInitial
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { Task { await enregistrer() } }
                        .disabled(!peutEnregistrer || propre.count > longueurMax || enCours)
                }
            }
        }
        .preferredColorScheme(RUColor.colorScheme)
    }

    private func enregistrer() async {
        enCours = true
        errorMessage = nil
        do {
            try await onSave(propre)
            Haptics.success()
            dismiss()
        } catch ClubServiceError.badResponse(422, _) {
            errorMessage = String(localized: "Ce texte n'est pas autorisé — reformule.")
        } catch {
            errorMessage = String(localized: "Impossible d'enregistrer, réessaie.")
        }
        enCours = false
    }
}
