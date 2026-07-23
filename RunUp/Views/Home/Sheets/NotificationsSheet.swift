import SwiftUI
import SwiftData

/// Bell-icon notifications sheet — marks all as read on open. Mirrors `NotifsSheet` in screensC.jsx.
struct NotificationsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppNotification.timestamp, order: .reverse) private var notifications: [AppNotification]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Notifications").displayStyle(22).foregroundColor(RUColor.textPrimary).padding(.top, 8)

                if notifications.isEmpty {
                    // Was a blank scroll area under the title with no empty-state copy at all —
                    // every other list screen in the app at least says something here.
                    VStack(spacing: 10) {
                        Image(systemName: "bell.slash").font(.system(size: 28)).foregroundColor(RUColor.text3)
                        Text("Rien pour l'instant").font(RUFont.sans(14, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                        Text("Tes séances, tes séries et l'activité du club apparaîtront ici.")
                            .font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }

                VStack(spacing: 8) {
                    ForEach(notifications) { n in
                        HStack(alignment: .top, spacing: 12) {
                            if n.icon == "mark" {
                                AppMarkView(size: 36)
                            } else {
                                Circle().fill(Color(hex: UInt32(n.colorHex))).frame(width: 36, height: 36)
                                    .overlay(Text(n.icon).font(.system(size: 15)))
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(n.title).font(RUFont.sans(13, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                                Text(n.text).font(RUFont.sans(12)).foregroundColor(RUColor.text2).lineSpacing(2)
                                Text(n.timestamp, style: .relative).font(RUFont.sans(10)).foregroundColor(RUColor.text3)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(13)
                        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .onAppear {
            for n in notifications where !n.read { n.read = true }
        }
    }
}
