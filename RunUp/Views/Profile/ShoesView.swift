import SwiftUI
import SwiftData

/// "Mes chaussures" — gear/wear tracking, mirroring Strava's shoe mileage feature. Kilometers per
/// pair are always derived from `RunRecord.shoeID` (see `Shoe.totalKm`), never stored/incremented,
/// so deleting or reassigning a run can't leave a pair's total stale.
struct ShoesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Shoe.createdAt, order: .reverse) private var shoes: [Shoe]
    @Query private var runs: [RunRecord]
    @State private var showAddShoe = false
    @State private var pendingRetire: Shoe?
    @State private var pendingDelete: Shoe?

    private var profile: UserProfile { appState.profile }
    private var activeShoes: [Shoe] { shoes.filter { $0.retiredAt == nil } }
    private var retiredShoes: [Shoe] { shoes.filter { $0.retiredAt != nil } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                BackTitleHeaderView(eyebrow: "Matériel", title: "Mes chaussures") {
                    appState.go(.profile)
                } trailing: {
                    Button(action: { showAddShoe = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(RUColor.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(RUColor.card, in: Circle())
                            .overlay(Circle().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Ajouter une paire")
                }

                if shoes.isEmpty {
                    Text("Ajoute une paire pour suivre son usure — chaque course lui est attribuée automatiquement une fois que c'est ta paire par défaut.")
                        .font(RUFont.sans(12)).foregroundColor(RUColor.text2).lineSpacing(3)
                        .padding(.top, 4)
                } else {
                    ForEach(activeShoes) { shoe in shoeRow(shoe) }

                    if !retiredShoes.isEmpty {
                        EyebrowLabel(text: "Retirées", color: RUColor.text3).padding(.top, 10)
                        ForEach(retiredShoes) { shoe in shoeRow(shoe) }
                    }
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .background(RUColor.pageBackground)
        .sheet(isPresented: $showAddShoe) { AddShoeSheet() }
        .alert(
            "Retirer cette paire ?",
            isPresented: Binding(get: { pendingRetire != nil }, set: { if !$0 { pendingRetire = nil } })
        ) {
            Button("Retirer") {
                if let shoe = pendingRetire {
                    shoe.retiredAt = .now
                    if profile.defaultShoeID == shoe.id {
                        // The nearest still-active pair becomes the new default so runs keep
                        // getting attributed instead of silently going unassigned again.
                        profile.defaultShoeID = activeShoes.first(where: { $0.id != shoe.id })?.id
                    }
                }
                pendingRetire = nil
            }
            Button("Annuler", role: .cancel) { pendingRetire = nil }
        } message: {
            Text("Elle reste dans ton historique, mais ne sera plus proposée par défaut sur tes prochaines courses.")
        }
        .alert(
            "Supprimer cette paire ?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
        ) {
            Button("Supprimer", role: .destructive) {
                if let shoe = pendingDelete {
                    if profile.defaultShoeID == shoe.id { profile.defaultShoeID = nil }
                    modelContext.delete(shoe)
                }
                pendingDelete = nil
            }
            Button("Annuler", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Les courses déjà enregistrées avec cette paire garderont leurs autres données, juste sans chaussure associée.")
        }
    }

    private func shoeRow(_ shoe: Shoe) -> some View {
        let km = shoe.totalKm(runs: runs)
        let fraction = shoe.alertThresholdKm > 0 ? km / shoe.alertThresholdKm : 0
        let isDefault = profile.defaultShoeID == shoe.id
        let isRetired = shoe.retiredAt != nil
        let barColor: Color = fraction >= 1 ? RUColor.rose : (fraction >= 0.8 ? RUColor.amber : RUColor.cyan)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(shoe.name).font(RUFont.sans(14.5, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                    // A ternary of string literals defaults to `String`, not `LocalizedStringKey`
                    // — same gotcha `EyebrowLabel` works around — so this needs the explicit
                    // wrap too, or it'd silently never translate into EN/ES.
                    Text(LocalizedStringKey(isRetired ? "Retirée" : (isDefault ? "Paire par défaut" : "Appuie pour la définir par défaut")))
                        .font(RUFont.sans(10.5)).foregroundColor(isDefault && !isRetired ? RUColor.cyan : RUColor.text3)
                }
                Spacer()
                Menu {
                    if !isRetired {
                        if !isDefault {
                            Button("Définir par défaut") { profile.defaultShoeID = shoe.id }
                        }
                        Button("Retirer cette paire") { pendingRetire = shoe }
                    }
                    Button("Supprimer", role: .destructive) { pendingDelete = shoe }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(RUColor.text2)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
            }

            LinearBar(fraction: fraction, color: barColor, height: 6)

            HStack {
                Text("\(String(format: "%.0f", km)) km").font(RUFont.mono(12, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                Text("/ \(String(format: "%.0f", shoe.alertThresholdKm)) km").font(RUFont.mono(11)).foregroundColor(RUColor.text3)
                Spacer()
                if fraction >= 1 {
                    Text("À remplacer").font(RUFont.sans(10.5, weight: .medium)).foregroundColor(RUColor.rose)
                } else if fraction >= 0.8 {
                    Text("Bientôt en fin de vie").font(RUFont.sans(10.5, weight: .medium)).foregroundColor(RUColor.amber)
                }
            }
        }
        .padding(14)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isRetired, !isDefault else { return }
            profile.defaultShoeID = shoe.id
            Haptics.selection()
        }
        .ruCard()
        .opacity(isRetired ? 0.55 : 1)
    }
}

/// Add-a-pair sheet — name + optional already-worn km (for a pair bought before she started
/// tracking), same shape as `AddRunSheet`'s standalone `NavigationStack` sheet.
private struct AddShoeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var shoes: [Shoe]

    @State private var name = ""
    @State private var startKmText = ""

    private var profile: UserProfile { appState.profile }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "Nom de la paire", color: RUColor.text3)
                        ObTextField(placeholder: String(localized: "Ex. Pegasus 41"), text: $name)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "Déjà parcourus (facultatif)", color: RUColor.text3)
                        ObTextField(placeholder: "0", text: $startKmText, keyboard: .decimalPad)
                        Text("Si cette paire n'est pas neuve, indique les km déjà dessus.")
                            .font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                    }
                }
                .padding(18)
            }
            .background(RUColor.pageBackground)
            .navigationTitle("Nouvelle paire")
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
        // `shoes` won't reflect the insert below until the next @Query update cycle, so whether
        // this is the first pair ever is captured before it, not after (same reasoning as
        // HistoryView's delete-time streak recompute).
        let isFirstShoe = shoes.isEmpty
        let startKm = Double(startKmText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let shoe = Shoe(name: name.trimmingCharacters(in: .whitespaces), startDistanceKm: max(0, startKm))
        modelContext.insert(shoe)
        // The first pair ever added becomes the default automatically — without this, every run
        // would go unattributed until she opens this screen a second time just to set it.
        if isFirstShoe { profile.defaultShoeID = shoe.id }
        Haptics.success()
        dismiss()
    }
}
