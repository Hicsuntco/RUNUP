import SwiftUI

/// L'annuaire des clubs publics — la porte d'entrée qui manquait au social de l'app.
///
/// Jusqu'ici un club ne se rejoignait QUE par code d'invitation : il fallait déjà connaître
/// quelqu'un dedans pour y entrer. C'est cohérent pour un club d'amis, et c'est une impasse pour
/// un compte neuf — or le club porte toute la mécanique de rétention de l'app (classement, défis,
/// fil, sorties de groupe), qui ne servait donc à personne n'ayant pas déjà un contact.
///
/// Ce que cet écran NE fait pas, volontairement : il ne liste que les clubs dont le créateur a
/// explicitement demandé la publication (`clubs.is_public`, à false par défaut). Aucun club
/// existant n'y est apparu du fait de la migration, et le code d'invitation continue de
/// fonctionner à l'identique — publier n'est qu'une porte de plus, jamais une porte forcée.
struct ClubDirectorySheet: View {
    var clubService: ClubService
    /// Appelé après une adhésion réussie — `ClubView` recharge son tableau et referme la feuille.
    var onJoined: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var clubs: [DiscoverableClub] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var joiningId: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    searchField

                    if isLoading && clubs.isEmpty {
                        ProgressView().tint(RUColor.rose)
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                    } else if clubs.isEmpty {
                        emptyState
                    } else {
                        ForEach(clubs) { club in
                            row(club)
                        }
                    }

                    if let errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11))
                            Text(errorMessage).font(RUFont.sans(11))
                        }
                        .foregroundColor(RUColor.rose)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, RUSpacing.pagePadding)
                .padding(.vertical, 12)
            }
            .background(RUColor.bg)
            .navigationTitle("Découvrir un club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundColor(RUColor.text2)
                }
            }
        }
        .task { await load() }
        .onChange(of: query) { _, newValue in scheduleSearch(newValue) }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundColor(RUColor.text3)
            TextField("", text: $query, prompt: Text("Nom du club ou ville…").foregroundColor(RUColor.text3))
                .textInputAutocapitalization(.never)
                .foregroundColor(RUColor.textPrimary)
                .font(RUFont.sans(13))
            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14)).foregroundColor(RUColor.text3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, query.isEmpty ? 14 : 0)
        .padding(.vertical, query.isEmpty ? 11 : 0)
        .frame(minHeight: 44)
        .ruCard(radius: RUSpacing.radiusCompact)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(query.isEmpty ? "L'annuaire est encore vide" : "Aucun club ne correspond")
                .font(RUFont.sans(13.5, weight: .bold))
                .foregroundColor(RUColor.textPrimary)
            // Dire la vérité plutôt que « réessayez plus tard » : au lancement, l'annuaire EST
            // vide, et la seule façon qu'il se remplisse est que quelqu'un publie le sien.
            Text(query.isEmpty
                 ? "Aucun club ne s'y est encore publié. Crée le tien et publie-le : c'est comme ça qu'il se remplit."
                 : "Essaie un autre nom, ou une ville.")
                .font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .ruCard()
    }

    private func row(_ club: DiscoverableClub) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(RUColor.accentGradient())
                Image(systemName: "trophy.fill").font(.system(size: 14)).foregroundColor(.white)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(club.name)
                    .font(RUFont.sans(14, weight: .bold))
                    .foregroundColor(RUColor.textPrimary)
                    .lineLimit(1)
                Text(memberLabel(club))
                    .font(RUFont.sans(10.5))
                    .foregroundColor(RUColor.text3)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)

            if joiningId == club.id {
                ProgressView().tint(RUColor.rose)
            } else {
                Button("Rejoindre") { Task { await join(club) } }
                    .buttonStyle(PrimaryButtonStyle(isDisabled: joiningId != nil))
                    .disabled(joiningId != nil)
                    .fixedSize()
            }
        }
        .padding(13)
        .ruCard()
    }

    private func memberLabel(_ club: DiscoverableClub) -> String {
        let members = club.memberCount > 1
            ? String(localized: "\(club.memberCount) membres")
            : String(localized: "\(club.memberCount) membre")
        guard let city = club.city, !city.isEmpty else { return members }
        return "\(city) · \(members)"
    }

    // MARK: - Réseau

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        searchTask = Task {
            // Même temporisation que la recherche de personnes : on ne part pas au serveur à
            // chaque frappe.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            clubs = try await clubService.discoverClubs(query: query)
        } catch {
            errorMessage = String(localized: "Impossible de charger l'annuaire — vérifie ta connexion.")
        }
        isLoading = false
    }

    private func join(_ club: DiscoverableClub) async {
        joiningId = club.id
        defer { joiningId = nil }
        do {
            let joined = try await clubService.joinPublicClub(id: club.id)
            onJoined(joined.name)
            dismiss()
        } catch let ClubServiceError.badResponse(status, _) where status == 409 {
            // On ne peut appartenir qu'à un club à la fois (`uniq_club_members_user`) — le dire
            // plutôt que de laisser une erreur générique.
            errorMessage = String(localized: "Tu es déjà dans un club — quitte-le d'abord.")
        } catch {
            errorMessage = String(localized: "Impossible de rejoindre ce club — réessaie.")
        }
    }
}
