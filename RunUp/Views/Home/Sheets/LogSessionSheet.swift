import SwiftUI

/// Enregistrer une séance faite hors de l'app — renfo, tapis, ou simple oubli d'appuyer sur
/// « démarrer ».
///
/// Elle demande la distance et la durée au lieu de les déduire. L'ancienne version validait la
/// séance d'un seul geste et calculait une distance depuis la durée prévue et l'allure cible : ça
/// donnait un « 5,2 km à 5:30/km » d'apparence précise pour une sortie qui avait pu se courir à
/// n'importe quelle allure, et ce chiffre inventé remontait ensuite dans les stats, dans le fil du
/// club et dans l'adaptation du programme. Corrigé une première fois en mettant zéro — honnête,
/// mais une séance qui ne compte aucun kilomètre n'est pas plus juste. Deux champs règlent les
/// deux.
///
/// La durée arrive pré-remplie avec celle du plan : c'est presque toujours la bonne, et la corriger
/// coûte deux frappes. La distance reste vide, parce qu'aucune valeur par défaut n'y serait vraie.
struct LogSessionSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var distanceText = ""
    @State private var durationText = ""
    @FocusState private var focus: Field?

    private enum Field { case distance, duration }

    private var session: WorkoutSession { appState.profile.todaySession }

    private var durationMinutes: Int? {
        let value = Int(durationText.trimmingCharacters(in: .whitespaces))
        guard let value, value > 0, value <= 600 else { return nil }
        return value
    }

    /// Virgule ET point acceptés : le clavier décimal français propose une virgule, et refuser
    /// « 5,2 » sur un clavier qui vient de la proposer serait absurde.
    private var distanceKm: Double {
        let normalised = distanceText.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(normalised), value > 0, value <= 300 else { return 0 }
        return value
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.displayTitle)
                            .displayStyle(22).foregroundColor(RUColor.textPrimary)
                        Text("Enregistre-la comme si tu venais de la faire.")
                            .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                    }

                    field(title: "Durée", unit: "min", text: $durationText, focused: .duration,
                          placeholder: "\(session.durationMinutes)")
                    field(title: "Distance", unit: "km", text: $distanceText, focused: .distance,
                          placeholder: "—")

                    // Dit avant de valider : une séance de renfo n'a pas de distance, et laisser
                    // le champ vide doit être un choix visiblement permis plutôt qu'un oubli.
                    Text("La distance est facultative — laisse-la vide pour une séance de renforcement ou un tapis sans compteur.")
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text3).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: validate) {
                        Text("Enregistrer la séance")
                    }
                    .buttonStyle(PrimaryButtonStyle(isDisabled: durationMinutes == nil))
                    .disabled(durationMinutes == nil)
                    .padding(.top, 2)
                }
                .padding(RUSpacing.pagePadding)
            }
            .background(RUColor.bg)
            .navigationTitle(Text("Séance déjà faite"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .onAppear {
            durationText = "\(session.durationMinutes)"
            focus = .distance
        }
    }

    private func field(title: LocalizedStringKey, unit: String, text: Binding<String>,
                       focused: Field, placeholder: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                .frame(width: 84, alignment: .leading)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(RUColor.text3))
                .keyboardType(.decimalPad)
                .focused($focus, equals: focused)
                .font(RUFont.mono(20))
                .foregroundColor(RUColor.textPrimary)
                .multilineTextAlignment(.trailing)
            Text(unit)
                .font(RUFont.sans(.small, weight: .semibold)).foregroundColor(RUColor.text3)
                .frame(width: 30, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(minHeight: 44)
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusInner, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
    }

    private func validate() {
        guard let minutes = durationMinutes else { return }
        appState.markTodaySessionDone(distanceKm: distanceKm, durationMinutes: minutes)
        dismiss()
    }
}
