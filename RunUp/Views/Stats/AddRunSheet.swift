import SwiftUI
import SwiftData
import UIKit

/// Manual run entry — History used to be strictly read-only (whatever the Live Run flow
/// produced), with no way to log a run that wasn't GPS-tracked or to fix a mistake. This writes a
/// real `RunRecord` via the same model everything else (`HistoryView`, `StatsView`) already
/// `@Query`s, so a manually-added run shows up everywhere automatically.
///
/// Laid out as one grouped list of icon + label + trailing-value rows (same shape
/// `MoreSettingsView` uses) rather than a stack of separate labelled cards — a single native-
/// feeling form instead of several small ones.
struct AddRunSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(sort: \RunRecord.date) private var runs: [RunRecord]
    @Query(filter: #Predicate<Shoe> { $0.retiredAt == nil }) private var activeShoes: [Shoe]

    @State private var date = Date.now
    @State private var title = Self.titles[0]
    @State private var distanceText = ""
    @State private var durationMinutesText = ""
    @State private var selectedShoeID: UUID?

    private static let titles = ["Footing", "Sortie longue", "Fractionné", "Tempo run", "Autre"]

    /// Plafonds volontairement larges — le record du monde du 24 h est à ~320 km, et une sortie
    /// ne dure pas plus d'une journée. Ils n'existent pas pour juger la performance mais pour
    /// borner ce qui descend ensuite dans les records, la charge d'entraînement et le graphe
    /// d'allure : une seule saisie à 5000 km les fausse durablement, sans moyen de comprendre
    /// pourquoi.
    private static let maxDistanceKm: Double = 500
    private static let maxDurationMinutes: Double = 1440

    /// `Double(_:)` accepte « 1e30 », « inf » et « nan » — pas seulement ce qu'un clavier
    /// numérique produit, mais exactement ce qu'un collage produit. Sans le test de finitude,
    /// `Int(seconds)` plus bas est un piège FATAL en Swift : convertir un flottant hors bornes en
    /// entier ne renvoie pas une valeur écrêtée, ça termine le processus.
    private var distance: Double? {
        guard let value = Double(distanceText.replacingOccurrences(of: ",", with: ".")),
              value.isFinite else { return nil }
        return value
    }
    private var durationMinutes: Double? {
        guard let value = Double(durationMinutesText.replacingOccurrences(of: ",", with: ".")),
              value.isFinite else { return nil }
        return value
    }
    private var isValid: Bool {
        guard let distance, let durationMinutes else { return false }
        return distance > 0 && distance <= Self.maxDistanceKm
            && durationMinutes > 0 && durationMinutes <= Self.maxDurationMinutes
    }
    private var selectedShoeName: String {
        activeShoes.first { $0.id == selectedShoeID }?.name ?? String(localized: "Aucune")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    EyebrowLabel(text: "Informations générales", color: RUColor.text3)
                    VStack(spacing: 0) {
                        dateRow
                        Divider().background(RUColor.line)
                        typeRow
                        Divider().background(RUColor.line)
                        numRow(icon: "ruler", label: "Distance", value: $distanceText, unit: "km", placeholder: "8,2")
                        Divider().background(RUColor.line)
                        numRow(icon: "clock", label: "Durée", value: $durationMinutesText, unit: "min", placeholder: "45")
                    }
                    .ruCard()

                    // Only shown once she's actually added a pair — no point cluttering this form
                    // with a picker for a feature she isn't using.
                    if !activeShoes.isEmpty {
                        EyebrowLabel(text: "Chaussures", color: RUColor.text3)
                        VStack(spacing: 0) {
                            shoeRow
                        }
                        .ruCard()
                    }
                }
                .padding(18)
            }
            .background(RUColor.pageBackground)
            .navigationTitle("Ajouter une course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { save() }.disabled(!isValid)
                }
            }
        }
        .preferredColorScheme(RUColor.colorScheme)
        .onAppear { selectedShoeID = appState.profile.defaultShoeID }
    }

    private func save() {
        // `isValid` garde déjà le bouton, mais on revérifie ici : c'est la seule barrière entre
        // une valeur saisie et une conversion en entier qui termine le processus si elle déborde.
        // Une garde en double sur ce chemin coûte une ligne.
        guard isValid, let distance, let durationMinutes else { return }
        let seconds = durationMinutes * 60
        let secPerKm = seconds / distance
        let run = RunRecord(
            date: date,
            title: title,
            distanceKm: distance,
            durationSeconds: Int(seconds),
            avgPace: AdaptivePlanEngine.fmt(secPerKm),
            // 0 = "no real reading" — HistoryView hides the FC line rather than show a fake 0bpm.
            avgHeartRate: 0,
            // A flat, deliberately rough estimate (no real heart rate to base it on) — better
            // than showing 0 kcal for a real run.
            kcal: Int((distance * 62).rounded())
        )
        run.shoeID = selectedShoeID
        modelContext.insert(run)
        // `runs` won't reflect the insert until the next @Query update cycle, so the current
        // set is computed by hand rather than read back immediately — same pattern as HistoryView's delete.
        AdaptivePlanEngine.recomputeStreak(profile: appState.profile, currentRuns: runs + [run])
        Haptics.success()
        dismiss()
    }

    /// Small leading glyph on every row — same treatment `MoreSettingsView` uses so a manual
    /// entry form and a settings form read as the same design language.
    private func rowIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(RUColor.rose2)
            .frame(width: 22)
    }

    private var dateRow: some View {
        HStack {
            rowIcon("calendar")
            Text("Date").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
            Spacer()
            DatePicker("", selection: $date, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .colorScheme(RUColor.colorScheme)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
    }

    private var typeRow: some View {
        HStack {
            rowIcon("list.bullet")
            Text("Type de séance").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
            Spacer()
            Menu {
                ForEach(Self.titles, id: \.self) { t in
                    // `Button(t)` avec un `String` ne passe jamais par le catalogue (seul
                    // l'initialiseur `LocalizedStringKey` le fait) : le menu restait en français
                    // alors que la ligne repliée juste en dessous, elle, se traduisait.
                    Button(LocalizedStringKey(t)) { title = t }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(LocalizedStringKey(title))
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold))
                }
                .font(RUFont.sans(13.5, weight: .medium))
                .foregroundColor(RUColor.text2)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
    }

    private var shoeRow: some View {
        HStack {
            rowIcon("shoeprints.fill")
            Text("Chaussures").font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
            Spacer()
            Menu {
                Button("Aucune") { selectedShoeID = nil }
                ForEach(activeShoes) { shoe in
                    Button(shoe.name) { selectedShoeID = shoe.id }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedShoeName)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold))
                }
                .font(RUFont.sans(13.5, weight: .medium))
                .foregroundColor(RUColor.text2)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
    }

    private func numRow(icon: String, label: String, value: Binding<String>, unit: String, placeholder: String) -> some View {
        HStack {
            rowIcon(icon)
            Text(LocalizedStringKey(label)).font(RUFont.sans(14, weight: .medium)).foregroundColor(RUColor.textPrimary)
            Spacer()
            TextField("", text: value, prompt: Text(placeholder).foregroundColor(RUColor.text3))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(RUColor.textPrimary)
                .frame(width: 60)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Terminé") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                }
            Text(unit).font(RUFont.sans(12, weight: .medium)).foregroundColor(RUColor.text2)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
    }
}
