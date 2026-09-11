import SwiftUI

/// Renommer sa sortie, lui ajouter une note, ou lui retirer son tracé — après coup.
///
/// # Pourquoi l'édition existe
///
/// La phrase que le fil affiche est FABRIQUÉE : « a couru 8,2 km · Sortie longue ». Elle dit ce
/// qui s'est passé, et c'est très bien. Elle ne dit pas que c'était le premier 10 km, qu'il
/// pleuvait, ou que le genou a tenu. Un fil où personne ne peut rien ajouter est un journal, pas
/// une conversation — et c'est exactement ce qu'on lui reprochait.
///
/// # Ce qui ne s'édite pas, et pourquoi
///
/// Ni la distance, ni la durée, ni l'allure, ni le dénivelé, ni le record. Ces mesures alimentent
/// la progression des défis de club, qui est une SOMME : les rendre modifiables offrirait à
/// n'importe qui un défi terminé en une requête. Ce qui s'édite ici est ce qui n'est compté nulle
/// part — du texte, et un tracé qu'on retire.
struct EditActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    /// Construit à la demande, exactement comme `ClubView` : `ClubService` est une structure sans
    /// état, dont la seule dépendance est le jeton de session porté par `AuthService`.
    private var clubService: ClubService { ClubService(auth: appState.auth) }

    let item: FeedItem
    /// Rappelée après un enregistrement réussi, pour que le fil se recharge sans attendre.
    var onSaved: () -> Void

    @State private var title: String
    @State private var note: String
    @State private var removeRoute = false
    @State private var saving = false
    @State private var errorMessage: String?

    init(item: FeedItem, onSaved: @escaping () -> Void) {
        self.item = item
        self.onSaved = onSaved
        _title = State(initialValue: item.title ?? "")
        _note = State(initialValue: item.note ?? "")
    }

    private static let maxTitle = 80
    private static let maxNote = 500

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Ce qui NE bouge PAS, montré en premier et grisé. Une feuille d'édition qui
                    // n'affiche que les champs modifiables laisse croire qu'elle a tout effacé.
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ta sortie")
                            .font(RUFont.sans(.micro, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(RUColor.text3)
                        Text(item.localizedText)
                            .font(RUFont.sans(.label))
                            .foregroundColor(RUColor.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(RUSpacing.cardPadding)
                    .ruCard()

                    field(label: "Titre", placeholder: "Mon premier 10 km") {
                        TextField("", text: $title, prompt: Text("Mon premier 10 km").foregroundColor(RUColor.text3))
                            .font(RUFont.sans(.label))
                            .foregroundColor(RUColor.textPrimary)
                            .onChange(of: title) { _, new in
                                if new.count > Self.maxTitle { title = String(new.prefix(Self.maxTitle)) }
                            }
                    }

                    field(label: "Note", placeholder: "Comment c'était ?") {
                        TextField("", text: $note, prompt: Text("Comment c'était ?").foregroundColor(RUColor.text3), axis: .vertical)
                            .font(RUFont.sans(.label))
                            .foregroundColor(RUColor.textPrimary)
                            .lineLimit(3...8)
                            .onChange(of: note) { _, new in
                                if new.count > Self.maxNote { note = String(new.prefix(Self.maxNote)) }
                            }
                    }

                    if item.routePreview != nil { routeSection }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(RUFont.sans(.small, weight: .semibold))
                            .foregroundColor(RUColor.rose)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(RUSpacing.pagePadding)
            }
            .background(RUColor.pageBackground)
            .navigationTitle("Modifier ma sortie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(saving)
                }
            }
        }
    }

    /// Le retrait du tracé est le seul champ qu'on peut supprimer sans supprimer la sortie, et il
    /// doit l'être : quelqu'un qui réalise après coup que le dessin de sa boucle en dit trop ne
    /// doit pas avoir à choisir entre garder ça et effacer sa course.
    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $removeRoute) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Retirer le tracé")
                        .font(RUFont.sans(.emphasis, weight: .semibold))
                        .foregroundColor(RUColor.textPrimary)
                    Text("Le dessin du parcours disparaît du fil. Le début et la fin de ta course n'y ont jamais été envoyés.")
                        .font(RUFont.sans(.small))
                        .foregroundColor(RUColor.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(RUColor.rose)
            if removeRoute {
                Text("C'est définitif : le tracé ne pourra pas être remis.")
                    .font(RUFont.sans(.small, weight: .semibold))
                    .foregroundColor(RUColor.amberText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(RUSpacing.cardPadding)
        .ruCard()
    }

    private func field<Content: View>(label: LocalizedStringKey, placeholder: LocalizedStringKey,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(RUFont.sans(.micro, weight: .bold))
                .tracking(1.2)
                .foregroundColor(RUColor.text3)
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous)
                    .stroke(RUColor.line, lineWidth: RUSpacing.hairline))
        }
    }

    private func save() {
        saving = true
        errorMessage = nil
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                try await clubService.updateActivity(
                    activityId: item.id,
                    title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                    note: trimmedNote.isEmpty ? nil : trimmedNote,
                    removeRoute: removeRoute
                )
                onSaved()
                dismiss()
            } catch {
                // Le message de modération mérite d'être distingué d'une panne réseau : dans un
                // cas il faut réécrire, dans l'autre réessayer. Les confondre en « une erreur est
                // survenue » laisse la personne relancer indéfiniment un texte qui ne passera pas.
                errorMessage = (error as? ClubServiceError)?.isObjectionableContent == true
                    ? String(localized: "Ce texte a été refusé par le filtre de contenu. Reformule-le.")
                    : String(localized: "Impossible d'enregistrer pour l'instant. Réessaie dans un moment.")
                saving = false
            }
        }
    }
}
