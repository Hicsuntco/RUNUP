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
                        EyebrowLabel(text: "\(members.count) membre\(members.count > 1 ? "s" : "")", color: RUColor.text3)
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
                appState.toast("Code copié")
            }) {
                Text(club.inviteCode).font(RUFont.mono(12.5, weight: .semibold)).foregroundColor(RUColor.text2).tracking(1.5)
            }
            .buttonStyle(PressableStyle())
            Spacer()
            ShareLink(item: "Rejoins mon club sur RunUp avec le code \(club.inviteCode) !") {
                Image(systemName: "square.and.arrow.up").font(.system(size: 12, weight: .medium)).foregroundColor(RUColor.text3)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 4)
    }

    private func memberRow(_ member: LeaderboardRow) -> some View {
        HStack(spacing: 12) {
            Circle().fill(member.isMe ? RUColor.rose : RUColor.card2).frame(width: 36, height: 36)
                // Fill is only the opaque rose accent for `isMe` — otherwise it's the faint
                // RUColor.card2, so the initial needs to invert with the theme in that case too.
                .overlay(Text(String(member.name.prefix(1))).displayStyle(13).foregroundColor(member.isMe ? .white : RUColor.textPrimary))
            Text(member.isMe ? "\(member.name) · toi" : member.name)
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

    private static let levelTitles = ["Premiers pas", "Foulée légère", "Rythme trouvé", "Foulée d'or", "Vitesse de croisière", "Endurance de fer", "Élite locale"]
    private var level: Int { member.xp / 250 + 1 }
    private var levelTitle: String { Self.levelTitles[(level - 1) % Self.levelTitles.count] }

    private static let joinedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
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
                Circle().fill(RUColor.rose).frame(width: 72, height: 72)
                    .overlay(Text(String(member.name.prefix(1))).displayStyle(28).foregroundColor(.white))
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
            .padding(.horizontal, 24)
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
                        Spacer()
                        Button(isSavingBio ? "…" : "Enregistrer") { Task { await saveBio(onUpdateBio) } }
                            .font(RUFont.sans(12, weight: .semibold)).foregroundColor(RUColor.rose2)
                            .disabled(isSavingBio)
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

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowLabel(text: "Badges", color: RUColor.text3)
            HStack(spacing: 10) {
                ForEach(badges) { badge in
                    Button(action: { selectedBadge = badge }) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(badge.earned ? RUColor.card : RUColor.card2)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(Text(badge.emoji).font(.system(size: 22)))
                            .opacity(badge.earned ? 1 : 0.35)
                    }
                    .buttonStyle(PressableStyle())
                }
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
        } catch ClubServiceError.badResponse(422, _) {
            bioError = "Ce texte n'est pas autorisé — reformule-le."
        } catch {
            bioError = "Impossible d'enregistrer, réessaie."
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
                        ObTextField(placeholder: "Ex. 200 km avant l'été", text: $title)
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
                            .colorScheme(.dark)
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
            dismiss()
        } catch ClubServiceError.badResponse(422, _) {
            errorMessage = "Ce nom n'est pas autorisé — choisis-en un autre."
        } catch {
            errorMessage = "Impossible de créer le défi, réessaie."
        }
        isSaving = false
    }
}
