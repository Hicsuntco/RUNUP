import SwiftUI

/// Social/club screen — mock leaderboard + activity feed (no backend in v1). Mirrors
/// `ClubScreen` in screensB.jsx.
struct ClubView: View {
    @Environment(AppState.self) private var appState
    @State private var tab: Tab = .board
    @State private var kudos: Set<UUID> = []

    private enum Tab { case board, feed }

    private var profile: UserProfile { appState.profile }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HeaderView(eyebrow: "Le Club", title: "Runners du 11e") {
                    StatChip(text: "248 membres", color: .white.opacity(0.7), background: RUColor.card)
                }

                levelCard
                challengeCard
                segmentedControl

                if tab == .board {
                    boardContent
                } else {
                    feedContent
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
    }

    private var levelCard: some View {
        HStack(spacing: 14) {
            Text("12").displayStyle(22).foregroundColor(.white)
                .frame(width: 52, height: 52)
                .background(LinearGradient(colors: [RUColor.violet, RUColor.rose], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .lastTextBaseline) {
                    Text("Niveau 12 · Foulée d'or").font(RUFont.sans(16, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Text("\(2000 + profile.xp) / 2 800 XP").font(RUFont.mono(10)).foregroundColor(RUColor.text2)
                }
                LinearBar(fraction: min(1, Double(2000 + profile.xp) / 2800), color: RUColor.violet, gradient: LinearGradient(colors: [RUColor.violet, RUColor.rose], startPoint: .leading, endPoint: .trailing))
            }
        }
        .padding(16)
        .background(LinearGradient(colors: [Color(hex: 0x241046), Color(hex: 0x160B1F)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(RUColor.violet.opacity(0.3), lineWidth: RUSpacing.hairline))
    }

    private var challengeCard: some View {
        let km = 71 + max(0, profile.runValue - 7.2)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                EyebrowLabel(text: "Défi du mois", color: RUColor.rose2)
                Spacer()
                StatChip(text: "J-9", color: RUColor.rose2)
            }
            Text("100 km en juillet").displayStyle(19).foregroundColor(.white)
            LinearBar(fraction: min(1, km / 100), color: RUColor.rose)
            HStack {
                Text("\(Int(km)) km parcourus").font(RUFont.sans(11)).foregroundColor(RUColor.text2)
                Spacer()
                Text("ce mois-ci").font(RUFont.sans(11)).foregroundColor(RUColor.text2)
            }
        }
        .padding(16)
        .ruCard()
    }

    private var segmentedControl: some View {
        HStack(spacing: 4) {
            segment("Classement", .board)
            segment("Fil d'activité", .feed)
        }
        .padding(3)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
    }

    private func segment(_ label: String, _ value: Tab) -> some View {
        Button(action: { tab = value }) {
            Text(label)
                .font(RUFont.sans(12.5, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(tab == value ? RUColor.rose : .clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private var boardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 6) {
                ForEach(ClubMockData.leaderboard(myName: profile.name, myXp: profile.xp)) { entry in
                    HStack(spacing: 12) {
                        Text(entry.medal ?? "\(entry.rank)")
                            .displayStyle(15)
                            .foregroundColor(entry.isMe ? RUColor.rose2 : RUColor.text2)
                            .frame(width: 20)
                        Text(entry.name)
                            .font(RUFont.sans(13, weight: entry.isMe ? .semibold : .regular))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(entry.xp)").displayStyle(15).foregroundColor(entry.isMe ? RUColor.rose2 : .white)
                    }
                    .padding(.horizontal, 13).padding(.vertical, 11)
                    .background(entry.isMe ? RUColor.rose.opacity(0.1) : RUColor.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(entry.isMe ? RUColor.rose.opacity(0.28) : RUColor.line, lineWidth: RUSpacing.hairline))
                }
            }

            EyebrowLabel(text: "Derniers badges", color: RUColor.text3)
            HStack(spacing: 10) {
                ForEach(ClubMockData.badges(streak: profile.streak)) { badge in
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(badge.earned ? RUColor.card : Color.white.opacity(0.02))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(Text(badge.emoji).font(.system(size: 26)))
                            .opacity(badge.earned ? 1 : 0.35)
                        Text(badge.name).font(RUFont.sans(8, weight: .semibold)).foregroundColor(RUColor.text2)
                    }
                }
            }
        }
    }

    private var feedContent: some View {
        VStack(spacing: 8) {
            ForEach(ClubMockData.feed) { item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: item.colorHex)).frame(width: 34, height: 34)
                            .overlay(Text(item.initial).displayStyle(13).foregroundColor(.white))
                        VStack(alignment: .leading, spacing: 2) {
                            (Text(item.name).fontWeight(.semibold) + Text(" \(item.text)"))
                                .font(RUFont.sans(13))
                                .foregroundColor(.white)
                            Text(item.time).font(RUFont.sans(10)).foregroundColor(RUColor.text3)
                        }
                        Spacer(minLength: 0)
                    }
                    Button(action: { toggleKudos(item.id) }) {
                        HStack(spacing: 6) {
                            Text("👏")
                            Text("\(item.kudos + (kudos.contains(item.id) ? 1 : 0))")
                        }
                        .font(RUFont.sans(11.5, weight: .semibold))
                        .foregroundColor(kudos.contains(item.id) ? RUColor.rose2 : RUColor.text2)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(kudos.contains(item.id) ? RUColor.rose.opacity(0.16) : RUColor.card2, in: Capsule())
                        .overlay(Capsule().stroke(kudos.contains(item.id) ? RUColor.rose.opacity(0.35) : RUColor.line, lineWidth: RUSpacing.hairline))
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(13)
                .ruCard()
            }
        }
    }

    private func toggleKudos(_ id: UUID) {
        if kudos.contains(id) { kudos.remove(id) } else { kudos.insert(id) }
    }
}
