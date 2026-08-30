import SwiftUI

/// Déplacer une séance de la semaine en cours vers un autre jour.
///
/// Deux étapes plutôt qu'une poignée de glissement : on choisit la séance, puis le jour. Le
/// glisser-déposer sur sept lignes hautes de cinquante points serait plus élégant à décrire et
/// nettement plus difficile à réussir du pouce, dans un écran qui défile déjà verticalement.
///
/// L'écran d'arrivée montre ce qui occupe chaque jour, parce que « mercredi » ne veut rien dire
/// tant qu'on ne sait pas ce qu'il y a mercredi. Et il signale les jours qui colleraient deux
/// séances exigeantes dos à dos — sans les interdire : quelqu'un qui ne peut pas courir jeudi ne
/// peut pas courir jeudi, et lui refuser le déplacement le renverrait à « Refaire un programme »,
/// c'est-à-dire au problème qu'on est en train de résoudre.
struct MoveSessionSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var picked: Int?

    private var profile: UserProfile { appState.profile }

    private var title: LocalizedStringKey { picked == nil ? "Déplacer une séance" : "Vers quel jour ?" }
    private var backLabel: LocalizedStringKey { picked == nil ? "Fermer" : "Retour" }

    private static let dayNames: [String] = [
        String(localized: "Lundi"), String(localized: "Mardi"), String(localized: "Mercredi"),
        String(localized: "Jeudi"), String(localized: "Vendredi"), String(localized: "Samedi"),
        String(localized: "Dimanche"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let picked {
                        destinationStep(for: picked)
                    } else {
                        sourceStep
                    }
                }
                .padding(RUSpacing.pagePadding)
            }
            .background(RUColor.bg)
            // Types explicites : un ternaire de deux littéraux se résout en `String`, et les
            // surcharges `String` de `navigationTitle` et de `Button` ne passent PAS par le
            // catalogue de traduction. Le titre serait resté français sur un téléphone anglais,
            // sans qu'aucun avertissement ne le signale.
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(backLabel) {
                        if picked == nil { dismiss() } else { picked = nil }
                    }
                }
            }
        }
    }

    // MARK: Étape 1 — quelle séance

    private var sourceStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(movableDays) { day in
                Button {
                    Haptics.selection()
                    picked = day.weekday
                } label: {
                    dayCard(weekday: day.weekday, session: day.session, warns: false, chevron: true)
                }
                .buttonStyle(PressableStyle())
            }

            if movableDays.isEmpty {
                Text("Aucune séance à déplacer cette semaine.")
                    .font(RUFont.sans(.body)).foregroundColor(RUColor.text2)
            }

            // Une séance faite ne bouge pas : elle a eu lieu ce jour-là. Le dire ici évite de
            // chercher pourquoi la séance de mardi n'apparaît pas dans la liste.
            if profile.weekSessions.contains(where: { $0.completed }) {
                Text("Les séances déjà faites ne se déplacent pas.")
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                    .padding(.top, 2)
            }
        }
    }

    private var movableDays: [PlannedDay] {
        profile.weekSessions.filter { ($0.session?.durationMinutes ?? 0) > 0 && !$0.completed }
    }

    // MARK: Étape 2 — vers quel jour

    private func destinationStep(for from: Int) -> some View {
        let destinations = SessionMove.destinations(in: profile.weekSessions, from: from)
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(destinations) { destination in
                Button {
                    if appState.moveSession(from: from, to: destination.weekday) { dismiss() }
                } label: {
                    dayCard(weekday: destination.weekday, session: destination.occupant,
                            warns: destination.warns, chevron: false)
                }
                .buttonStyle(PressableStyle())
            }

            if destinations.contains(where: \.warns) {
                Text("⚠ marque les jours qui placeraient deux séances exigeantes l'une après l'autre. C'est permis, mais c'est ainsi qu'on se blesse.")
                    .font(RUFont.sans(.small)).foregroundColor(RUColor.text3)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: La ligne d'un jour

    private func dayCard(weekday: Int, session: WorkoutSession?, warns: Bool, chevron: Bool) -> some View {
        let family = session?.family ?? .rest
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: RUSpacing.radiusBar, style: .continuous)
                .fill(session == nil ? Color.clear : family.tint)
                .frame(width: 3, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.dayNames[weekday])
                    .font(RUFont.sans(.label, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                Text(session?.displayTitle ?? String(localized: "Libre"))
                    .font(RUFont.sans(.small))
                    .foregroundColor(session == nil ? RUColor.text3 : RUColor.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if warns {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(RUColor.amber)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(RUColor.text3)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .ruCard(radius: RUSpacing.radiusCompact)
    }
}
