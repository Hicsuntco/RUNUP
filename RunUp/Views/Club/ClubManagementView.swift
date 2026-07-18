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
    var onReport: (LeaderboardRow) -> Void
    var onBlock: (LeaderboardRow) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    inviteCodeCard

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
        }
        .preferredColorScheme(.dark)
    }

    private var inviteCodeCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowLabel(text: "Code d'invitation", color: RUColor.rose2)
            HStack(spacing: 12) {
                Button(action: {
                    UIPasteboard.general.string = club.inviteCode
                    appState.toast("Code copié")
                }) {
                    Text(club.inviteCode).font(RUFont.mono(22, weight: .bold)).foregroundColor(.white).tracking(3)
                }
                .buttonStyle(PressableStyle())
                Spacer()
                ShareLink(item: "Rejoins mon club sur RunUp avec le code \(club.inviteCode) !") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(RUColor.rose, in: Circle())
                }
                .buttonStyle(PressableStyle())
            }
            Text("Touche le code pour le copier.").font(RUFont.sans(10.5)).foregroundColor(RUColor.text3)
        }
        .padding(16)
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
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
