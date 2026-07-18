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
                    onBlock: { onBlock(member) }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
            .sheet(isPresented: $showCreateChallenge) {
                CreateChallengeSheet(onCreate: onCreateChallenge)
            }
        }
        .preferredColorScheme(.dark)
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
                    Text(challenge.title).font(RUFont.sans(14, weight: .semibold)).foregroundColor(.white)
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
                .overlay(Text(String(member.name.prefix(1))).displayStyle(13).foregroundColor(.white))
            Text(member.isMe ? "\(member.name) · toi" : member.name)
                .font(RUFont.sans(13, weight: member.isMe ? .semibold : .regular))
                .foregroundColor(.white)
            Spacer()
            Text("\(member.xp) XP").font(RUFont.mono(11)).foregroundColor(RUColor.text2)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(RUColor.text3)
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }
}

/// A member's mini-profile — deliberately minimal since the backend only ever hands back
/// id/name/xp/rank for the leaderboard (see `LeaderboardRow`), not a richer public profile.
struct ClubMemberProfileView: View {
    var member: LeaderboardRow
    var onReport: () -> Void
    var onBlock: () -> Void

    private static let levelTitles = ["Premiers pas", "Foulée légère", "Rythme trouvé", "Foulée d'or", "Vitesse de croisière", "Endurance de fer", "Élite locale"]
    private var level: Int { member.xp / 250 + 1 }
    private var levelTitle: String { Self.levelTitles[(level - 1) % Self.levelTitles.count] }

    var body: some View {
        VStack(spacing: 14) {
            Circle().fill(RUColor.rose).frame(width: 72, height: 72)
                .overlay(Text(String(member.name.prefix(1))).displayStyle(28).foregroundColor(.white))
                .padding(.top, 20)
            Text(member.name).font(RUFont.sans(18, weight: .semibold)).foregroundColor(.white)
            Text("Niveau \(level) · \(levelTitle)").font(RUFont.sans(12)).foregroundColor(RUColor.text2)

            HStack(spacing: 24) {
                MetricColumn(value: "\(member.xp)", label: "XP")
                MetricColumn(value: "#\(member.rank)", label: "Rang club", valueColor: RUColor.rose2)
            }
            .padding(.top, 6)

            if !member.isMe {
                HStack(spacing: 10) {
                    Button("Signaler") { onReport() }.buttonStyle(SecondaryButtonStyle())
                    Button("Bloquer") { onBlock() }.buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 12)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(RUColor.bg)
        .navigationBarTitleDisplayMode(.inline)
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
                                .foregroundColor(.white)
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
        .preferredColorScheme(.dark)
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
