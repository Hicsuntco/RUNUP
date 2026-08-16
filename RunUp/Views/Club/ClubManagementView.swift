import SwiftUI
import UIKit

/// "Gestion du club" — reached by tapping the club name in `ClubView`'s header. Groups what
/// isn't part of the day-to-day leaderboard/feed: the invite code (used to sit as its own card on
/// the main page, which read as clutter), the full member list, and a drill-down mini-profile per
/// member. Report/block stay owned by `ClubView` (its confirmationDialog/alert are already wired
/// there) — this only calls back into it.
struct ClubManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    var club: ClubInfo
    var members: [LeaderboardRow]
    var challenge: ClubChallenge?
    var onCreateChallenge: (String, Double, Date) async throws -> Void
    var onReport: (LeaderboardRow) -> Void
    var onBlock: (LeaderboardRow) -> Void
    var onUpdateBio: (String) async throws -> Void

    @State private var showCreateChallenge = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    inviteCodeCard

                    challengeSection

                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowLabel(text: members.count > 1
                            ? String(localized: "\(members.count) membres")
                            : String(localized: "\(members.count) membre"), color: RUColor.text3)
                        VStack(spacing: 6) {
                            ForEach(members) { member in
                                NavigationLink(value: member) {
                                    memberRow(member)
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(RUColor.bg)
            .navigationTitle(club.name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: LeaderboardRow.self) { member in
                ClubMemberProfileView(
                    member: member,
                    onReport: { onReport(member) },
                    onBlock: { onBlock(member) },
                    onUpdateBio: member.isMe ? onUpdateBio : nil
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
            .sheet(isPresented: $showCreateChallenge) {
                CreateChallengeSheet(onCreate: onCreateChallenge)
            }
        }
        .preferredColorScheme(RUColor.colorScheme)
    }

    private var challengeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                EyebrowLabel(text: "Défi du club", color: RUColor.text3)
                Spacer()
                Button(challenge == nil ? "Créer" : "Changer") { showCreateChallenge = true }
                    .font(RUFont.sans(11.5, weight: .semibold))
                    .foregroundColor(RUColor.rose2)
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            if let challenge {
                VStack(alignment: .leading, spacing: 6) {
                    Text(challenge.title).font(RUFont.sans(14, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                    Text("\(Int(challenge.progressKm)) / \(Int(challenge.targetKm)) km parcourus ensemble")
                        .font(RUFont.sans(11.5)).foregroundColor(RUColor.text2)
                }
                .padding(13)
                .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
            } else {
                Text("Aucun défi en cours pour l'instant.")
                    .font(RUFont.sans(11.5)).foregroundColor(RUColor.text3)
            }
        }
    }

    /// Used to be its own bold card up top — too loud for something you touch once in a while.
    /// A slim row reads as secondary info, not a headline.
    private var inviteCodeCard: some View {
        HStack(spacing: 8) {
            Text("Code").font(RUFont.sans(11.5)).foregroundColor(RUColor.text3)
            Button(action: {
                UIPasteboard.general.string = club.inviteCode
                Haptics.impact(.light)
                appState.toast(String(localized: "Code copié"))
            }) {
                Text(club.inviteCode).font(RUFont.mono(12.5, weight: .semibold)).foregroundColor(RUColor.text2).tracking(1.5)
            }
            .buttonStyle(PressableStyle())
            Spacer()
            ShareLink(item: String(localized: "Rejoins mon club sur RunUp avec le code \(club.inviteCode) !")) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 12, weight: .medium)).foregroundColor(RUColor.text3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Partager le code d'invitation")
        }
        .padding(.horizontal, 4)
    }

    private func memberRow(_ member: LeaderboardRow) -> some View {
        HStack(spacing: 12) {
            AvatarView(urlString: member.avatarUrl, base64DataURI: member.avatarBase64, initial: String(member.name.prefix(1)), size: 36, seed: member.isMe ? nil : member.id)
            Text(member.isMe ? String(localized: "\(member.name) · toi") : member.name)
                .font(RUFont.sans(13, weight: member.isMe ? .semibold : .regular))
                .foregroundColor(RUColor.textPrimary)
            Spacer()
            Text("\(member.xp) XP").font(RUFont.mono(11)).foregroundColor(RUColor.text2)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(RUColor.text3)
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }
}

/// A member's mini-profile — real membership date, real per-club activity count, real permanent
/// badges (synced server-side, see `ClubBadgeCatalog`), and an editable status for your own
/// profile. Used to only ever show id/name/xp/rank (`LeaderboardRow`'s original shape).
struct ClubMemberProfileView: View {
    var member: LeaderboardRow
    var onReport: () -> Void
    var onBlock: () -> Void
    /// Only non-nil for your own profile — `ClubManagementView` passes `nil` for anyone else.
    var onUpdateBio: ((String) async throws -> Void)?

    @State private var savedBio: String?
    @State private var bioText = ""
    @State private var isEditingBio = false
    @State private var isSavingBio = false
    @State private var bioError: String?
    @State private var selectedBadge: ClubBadge?

    // `String(localized:)` et non des littéraux nus : ces titres sont composés dans `Text("Niveau
    // \(level) · \(levelTitle)")` en tant qu'argument, ils n'atteignent donc jamais un
    // `LocalizedStringKey` par eux-mêmes.
    private static let levelTitles = [
        String(localized: "Premiers pas"),
        String(localized: "Foulée légère"),
        String(localized: "Rythme trouvé"),
        String(localized: "Foulée d'or"),
        String(localized: "Vitesse de croisière"),
        String(localized: "Endurance de fer"),
        String(localized: "Élite locale")
    ]
    private var level: Int { member.xp / 250 + 1 }
    // Clamped like ClubView.levelInfo — the old `%` wrapped a level-8 member back to "Premiers pas".
    private var levelTitle: String { Self.levelTitles[min(max(level - 1, 0), Self.levelTitles.count - 1)] }

    private static let joinedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    /// Real earned/locked state from the server's `badgeKeys` — never a live progress number
    /// here, unlike `ClubView.badges`: this device has no access to another member's run history.
    private var badges: [ClubBadge] {
        ClubBadgeCatalog.all.map { def in
            ClubBadge(key: def.key, emoji: def.emoji, name: def.name, detail: def.detail, progressText: nil, earned: member.badgeKeys.contains(def.key))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                AvatarView(urlString: member.avatarUrl, base64DataURI: member.avatarBase64, initial: String(member.name.prefix(1)), size: 72, seed: member.isMe ? nil : member.id)
                    .padding(.top, 20)
                Text(member.name).font(RUFont.sans(18, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                Text("Niveau \(level) · \(levelTitle)").font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                Text("Membre depuis \(Self.joinedFormatter.string(from: member.joinedAt))")
                    .font(RUFont.sans(11)).foregroundColor(RUColor.text3)

                bioSection

                HStack(spacing: 20) {
                    MetricColumn(value: "\(member.xp)", label: "XP")
                    MetricColumn(value: "#\(member.rank)", label: "Rang club", valueColor: RUColor.rose2)
                    MetricColumn(value: "\(member.activitiesCount)", label: "Activités")
                }
                .padding(.top, 6)

                badgesSection

                if !member.isMe {
                    HStack(spacing: 10) {
                        Button("Signaler") { onReport() }.buttonStyle(SecondaryButtonStyle())
                        Button("Bloquer") { onBlock() }.buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(.top, 12)
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(RUColor.bg)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            savedBio = member.bio
            bioText = member.bio ?? ""
        }
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(badge: badge).runUpSheetStyle(detents: [.height(300)])
        }
    }

    @ViewBuilder
    private var bioSection: some View {
        if let onUpdateBio {
            VStack(spacing: 8) {
                if isEditingBio {
                    TextField("Un petit statut…", text: $bioText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(RUFont.sans(13))
                        .foregroundColor(RUColor.textPrimary)
                        .lineLimit(1...3)
                        .padding(11)
                        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    if let bioError {
                        Text(bioError).font(RUFont.sans(10.5)).foregroundColor(RUColor.rose)
                    }
                    HStack(spacing: 14) {
                        Button("Annuler") {
                            isEditingBio = false
                            bioText = savedBio ?? ""
                            bioError = nil
                        }
                        .font(RUFont.sans(12, weight: .semibold)).foregroundColor(RUColor.text3)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        Spacer()
                        Button(isSavingBio ? "…" : "Enregistrer") { Task { await saveBio(onUpdateBio) } }
                            .font(RUFont.sans(12, weight: .semibold)).foregroundColor(RUColor.rose2)
                            .disabled(isSavingBio)
                            .padding(.vertical, 12)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                } else {
                    Button(action: { isEditingBio = true }) {
                        Text(savedBio?.isEmpty == false ? savedBio! : "Ajouter un statut")
                            .font(RUFont.sans(12.5)).foregroundColor(savedBio?.isEmpty == false ? RUColor.text2 : RUColor.text3)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 10)
        } else if let bio = member.bio, !bio.isEmpty {
            Text(bio).font(RUFont.sans(12.5)).foregroundColor(RUColor.text2).multilineTextAlignment(.center).padding(.horizontal, 20)
        }
    }

    /// Horizontally scrollable, not a plain `HStack` — same fix as `ClubView.badgeStrip`: the
    /// badge catalog grew to 15+ entries and a bare `HStack` crushes each tile down to just a
    /// few points wide. A fixed tile width lets a scroll view give each one its real size.
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Badges", color: RUColor.text3)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(badges) { badge in
                        let color = ClubBadgeCatalog.color(for: badge.key)
                        Button(action: { selectedBadge = badge }) {
                            VStack(spacing: 5) {
                                HexagonBadgeShape()
                                    .fill(badge.earned ? color.opacity(0.22) : RUColor.card2)
                                    .overlay(HexagonBadgeShape().stroke(badge.earned ? color.opacity(0.7) : RUColor.line, lineWidth: RUSpacing.hairline))
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(Text(badge.emoji).font(.system(size: 22)))
                                    .opacity(badge.earned ? 1 : 0.35)
                                Text(badge.name)
                                    .font(RUFont.sans(8, weight: .semibold))
                                    .foregroundColor(badge.earned ? RUColor.textPrimary : RUColor.text2)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(width: 64)
                            // See matching comment in ClubView.badgeStrip — a filled hexagon Shape
                            // hit-tests against its own path, so the cut corners are dead zones
                            // without this.
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(badge.earned
                                            ? String(localized: "\(badge.name), débloqué")
                                            : String(localized: "\(badge.name), verrouillé"))
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 10)
    }

    private func saveBio(_ onUpdateBio: (String) async throws -> Void) async {
        isSavingBio = true
        bioError = nil
        do {
            try await onUpdateBio(bioText)
            savedBio = bioText.trimmingCharacters(in: .whitespacesAndNewlines)
            isEditingBio = false
            Haptics.success()
        } catch ClubServiceError.badResponse(422, _) {
            bioError = String(localized: "Ce texte n'est pas autorisé — reformule-le.")
        } catch {
            bioError = String(localized: "Impossible d'enregistrer, réessaie.")
        }
        isSavingBio = false
    }
}

/// Any member can set the club's challenge (a distance target by a deadline) — replaces whichever
/// one was active before it, since a club has at most one at a time.
struct CreateChallengeSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (String, Double, Date) async throws -> Void

    @State private var title = ""
    @State private var targetKmText = ""
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var targetKm: Double? { Double(targetKmText.replacingOccurrences(of: ",", with: ".")) }
    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && (targetKm ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "Nom du défi", color: RUColor.text3)
                        ObTextField(placeholder: String(localized: "Ex. 200 km avant l'été"), text: $title)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "Distance cible", color: RUColor.text3)
                        HStack {
                            TextField("", text: $targetKmText, prompt: Text("200").foregroundColor(RUColor.text3))
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
                            Text("km").font(RUFont.sans(12, weight: .semibold)).foregroundColor(RUColor.text2)
                        }
                        .padding(13)
                        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "Jusqu'au", color: RUColor.text3)
                        DatePicker("", selection: $endDate, in: Calendar.current.date(byAdding: .day, value: 1, to: .now)!..., displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(RUColor.colorScheme)
                    }

                    if let errorMessage {
                        Text(errorMessage).font(RUFont.sans(11.5)).foregroundColor(RUColor.rose)
                    }
                }
                .padding(18)
            }
            .background(RUColor.bg)
            .navigationTitle("Nouveau défi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { Task { await save() } }
                        .disabled(!isValid || isSaving)
                }
            }
        }
        .preferredColorScheme(RUColor.colorScheme)
    }

    private func save() async {
        guard let targetKm else { return }
        isSaving = true
        errorMessage = nil
        do {
            try await onCreate(title.trimmingCharacters(in: .whitespaces), targetKm, endDate)
            Haptics.success()
            dismiss()
        } catch ClubServiceError.badResponse(422, _) {
            errorMessage = String(localized: "Ce nom n'est pas autorisé — choisis-en un autre.")
        } catch {
            errorMessage = String(localized: "Impossible de créer le défi, réessaie.")
        }
        isSaving = false
    }
}

/// Bottom sheet to propose a sortie de groupe — mirrors `CreateChallengeSheet`'s structure
/// (same visual language, same error handling), for a title + optional meeting point + date/time.
struct CreateEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (String, String?, Date) async throws -> Void

    @State private var title = ""
    @State private var location = ""
    @State private var startsAt = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "Quelle sortie ?", color: RUColor.text3)
                        ObTextField(placeholder: String(localized: "Ex. Sortie longue tranquille 10 km"), text: $title)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "Point de rendez-vous (facultatif)", color: RUColor.text3)
                        ObTextField(placeholder: String(localized: "Ex. Entrée du parc de la Tête d'Or"), text: $location)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "Quand ?", color: RUColor.text3)
                        DatePicker("", selection: $startsAt, in: .now..., displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .colorScheme(RUColor.colorScheme)
                    }

                    if let errorMessage {
                        Text(errorMessage).font(RUFont.sans(11.5)).foregroundColor(RUColor.rose)
                    }
                }
                .padding(18)
            }
            .background(RUColor.bg)
            .navigationTitle("Sortie de groupe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Proposer") { Task { await save() } }
                        .disabled(!isValid || isSaving)
                }
            }
        }
        .preferredColorScheme(RUColor.colorScheme)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
            try await onCreate(title.trimmingCharacters(in: .whitespaces), trimmedLocation.isEmpty ? nil : trimmedLocation, startsAt)
            Haptics.success()
            dismiss()
        } catch ClubServiceError.badResponse(422, _) {
            errorMessage = String(localized: "Ce texte n'est pas autorisé — reformule.")
        } catch {
            errorMessage = String(localized: "Impossible de proposer la sortie, réessaie.")
        }
        isSaving = false
    }
}
