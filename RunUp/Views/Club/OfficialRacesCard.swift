import SwiftUI

/// "Courses officielles" — deep-links to RunningMap.org's real, always-current race calendar for
/// whichever département she picks, rather than storing or fabricating a race list ourselves (see
/// `FrenchDepartement` for why: no public API exists for this in France). Shown in Club regardless
/// of sign-in/membership status — finding a race to run has nothing to do with club membership.
struct OfficialRacesCard: View {
    @Environment(AppState.self) private var appState
    @State private var showPicker = false

    private var profile: UserProfile { appState.profile }
    private var selected: FrenchDepartement? {
        guard let slug = profile.homeDepartementSlug else { return nil }
        return FrenchDepartement.all.first { $0.slug == slug }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                EyebrowLabel(text: "Courses officielles", color: RUColor.violet)
                Spacer()
                Image(systemName: "flag.checkered").font(.system(size: 14)).foregroundColor(RUColor.violet)
            }

            Button(action: { showPicker = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse").font(.system(size: 12)).foregroundColor(RUColor.text2)
                    // Split rather than `selected?.name ?? "Choisir un département"` — a real
                    // département name is a French proper noun and shouldn't run through
                    // localization, but the placeholder text genuinely should translate for EN/ES.
                    if let selected {
                        Text(selected.name).font(RUFont.sans(13, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                    } else {
                        Text("Choisir un département").font(RUFont.sans(13, weight: .semibold)).foregroundColor(RUColor.text2)
                    }
                    Spacer(minLength: 0)
                    Text("›").foregroundColor(RUColor.text3)
                }
                .padding(.horizontal, 13).padding(.vertical, 11)
                .frame(minHeight: 44)
                .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
            }
            .buttonStyle(PressableStyle())

            if let selected {
                // `Link` doesn't reliably pick up `.buttonStyle` the way `Button`/`ShareLink` do,
                // so the PrimaryButtonStyle look is applied to its label directly instead of risking
                // an untested modifier combination.
                Link(destination: selected.calendarURL) {
                    HStack {
                        Text("VOIR LE CALENDRIER").font(RUFont.bebas(16)).tracking(1)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RUColor.rose, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: RUColor.rose.opacity(0.3), radius: 16, x: 0, y: 4)
                }
                .buttonStyle(PressableStyle())
                Text("Ouvre RunningMap.org, à jour en continu — courses hors-stade et trail labellisées en \(selected.name).")
                    .font(RUFont.sans(10.5)).foregroundColor(RUColor.text3).lineSpacing(2)
            } else {
                Text("Choisis un département pour voir les courses officielles à venir près de chez toi.")
                    .font(RUFont.sans(10.5)).foregroundColor(RUColor.text3).lineSpacing(2)
            }
        }
        .padding(16)
        .ruCard()
        .sheet(isPresented: $showPicker) {
            DepartementPickerSheet(selectedSlug: profile.homeDepartementSlug) { picked in
                profile.homeDepartementSlug = picked.slug
            }
        }
    }
}

private struct DepartementPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var selectedSlug: String?
    var onPick: (FrenchDepartement) -> Void

    @State private var query = ""

    private var filtered: [FrenchDepartement] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return FrenchDepartement.all }
        return FrenchDepartement.all.filter {
            $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current))
            || $0.code == query
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { dept in
                Button(action: {
                    onPick(dept)
                    dismiss()
                }) {
                    HStack {
                        Text(dept.code).font(RUFont.mono(11)).foregroundColor(RUColor.text3).frame(width: 30, alignment: .leading)
                        Text(dept.name).font(RUFont.sans(14)).foregroundColor(RUColor.textPrimary)
                        Spacer()
                        if dept.slug == selectedSlug {
                            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(RUColor.rose)
                        }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .listRowBackground(RUColor.bg)
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: "Département ou numéro")
            .background(RUColor.bg)
            .navigationTitle("Ton département")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .preferredColorScheme(RUColor.colorScheme)
    }
}
