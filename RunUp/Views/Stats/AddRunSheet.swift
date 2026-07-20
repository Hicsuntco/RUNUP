import SwiftUI
import UIKit

/// Manual run entry — History used to be strictly read-only (whatever the Live Run flow
/// produced), with no way to log a run that wasn't GPS-tracked or to fix a mistake. This writes a
/// real `RunRecord` via the same model everything else (`HistoryView`, `StatsView`) already
/// `@Query`s, so a manually-added run shows up everywhere automatically.
struct AddRunSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date = Date.now
    @State private var title = Self.titles[0]
    @State private var distanceText = ""
    @State private var durationMinutesText = ""

    private static let titles = ["Footing", "Sortie longue", "Fractionné", "Tempo run", "Autre"]

    private var distance: Double? {
        Double(distanceText.replacingOccurrences(of: ",", with: "."))
    }
    private var durationMinutes: Double? {
        Double(durationMinutesText.replacingOccurrences(of: ",", with: "."))
    }
    private var isValid: Bool { (distance ?? 0) > 0 && (durationMinutes ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "Date", color: RUColor.text3)
                        DatePicker("", selection: $date, in: ...Date.now, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(RUColor.colorScheme)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "Type de séance", color: RUColor.text3)
                        ChipFlowLayout {
                            ForEach(Self.titles, id: \.self) { t in
                                SelectableChip(label: t, selected: title == t) { title = t }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        numField(label: "Distance", value: $distanceText, unit: "km", placeholder: "8.2")
                        numField(label: "Durée", value: $durationMinutesText, unit: "min", placeholder: "45")
                    }
                }
                .padding(18)
            }
            .background(RUColor.bg)
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
    }

    private func save() {
        guard let distance, let durationMinutes else { return }
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
        modelContext.insert(run)
        dismiss()
    }

    private func numField(label: String, value: Binding<String>, unit: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(text: label, color: RUColor.text3)
            HStack {
                TextField("", text: value, prompt: Text(placeholder).foregroundColor(RUColor.text3))
                    .keyboardType(.decimalPad)
                    .foregroundColor(RUColor.textPrimary)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Terminé") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        }
                    }
                Text(unit).font(RUFont.sans(12, weight: .semibold)).foregroundColor(RUColor.text2)
            }
            .padding(13)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
        }
        .frame(maxWidth: .infinity)
    }
}
