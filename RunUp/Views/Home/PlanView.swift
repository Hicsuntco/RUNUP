import SwiftUI

/// Full 9-week plan — mirrors `PlanScreen` in screensA.jsx. Week/session data here is
/// illustrative (the design is a fixed 9-week template); only the current week reflects live
/// profile state (today's session, adjustment chip).
struct PlanView: View {
    @Environment(AppState.self) private var appState
    private var profile: UserProfile { appState.profile }

    private struct DaySlot { var letter: String; var name: String; var meta: String; var color: Color; var status: String }
    private struct WeekRow { var number: Int; var phase: String; var km: String; var status: String }

    private var currentWeekDays: [DaySlot] {
        let s = profile.todaySession
        return [
            DaySlot(letter: "Lun", name: "Récup active", meta: "30′ · Z2", color: RUColor.cyan, status: "done"),
            DaySlot(letter: "Mar", name: "Fractionné 6×800", meta: "48′ · Z4", color: RUColor.rose, status: "done"),
            DaySlot(letter: "Mer", name: "Repos", meta: "—", color: .white.opacity(0.2), status: "rest"),
            DaySlot(letter: "Jeu", name: s.title, meta: "\(s.durationMinutes)′ · \(s.zone)", color: RUColor.rose, status: "today"),
            DaySlot(letter: "Ven", name: "Récup active", meta: "30′ · Z2", color: RUColor.cyan, status: ""),
            DaySlot(letter: "Sam", name: "Sortie longue", meta: "1h05 · Z2-3", color: RUColor.rose2, status: ""),
            DaySlot(letter: "Dim", name: "Repos", meta: "—", color: .white.opacity(0.2), status: "rest")
        ]
    }

    private let weeks: [WeekRow] = [
        WeekRow(number: 1, phase: "Base", km: "32 km", status: "done"),
        WeekRow(number: 2, phase: "Base", km: "35 km", status: "done"),
        WeekRow(number: 3, phase: "Base", km: "34 km", status: "done"),
        WeekRow(number: 4, phase: "VMA · en cours", km: "33 km", status: "current"),
        WeekRow(number: 5, phase: "Spécifique", km: "38 km", status: ""),
        WeekRow(number: 6, phase: "Spécifique", km: "40 km", status: ""),
        WeekRow(number: 7, phase: "Spécifique", km: "36 km", status: ""),
        WeekRow(number: 8, phase: "Affûtage", km: "28 km", status: "taper"),
        WeekRow(number: 9, phase: "Course", km: "10 km", status: "race")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    BackChevronButton { appState.go(.home) }
                    VStack(alignment: .leading, spacing: 1) {
                        EyebrowLabel(text: "Ton programme · \(profile.goalDisplay)", color: RUColor.rose)
                        Text("Le plan complet").displayStyle(22).foregroundColor(.white)
                    }
                }

                Text("9 semaines · 3 phases. Il évolue à chaque séance selon ta forme.")
                    .font(RUFont.sans(12)).foregroundColor(RUColor.text2).lineSpacing(3)

                PhaseProgressBar(phases: [
                    PhaseSegment(name: "Base", done: 3, total: 3, color: RUColor.rose),
                    PhaseSegment(name: "Spécifique", done: 1, total: 4, color: RUColor.rose2),
                    PhaseSegment(name: "Affûtage", done: 0, total: 2, color: RUColor.violet)
                ])

                VStack(spacing: 6) {
                    ForEach(weeks, id: \.number) { week in
                        if week.status == "current" {
                            currentWeekCard(week)
                        } else {
                            weekRow(week)
                        }
                    }
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 130)
        }
    }

    private func currentWeekCard(_ week: WeekRow) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("\(week.number)").displayStyle(14).foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(RUColor.rose, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Semaine \(week.number) · \(week.phase)").font(RUFont.sans(13, weight: .semibold)).foregroundColor(.white)
                    Text("\(week.km) · 2/4 séances faites").font(RUFont.sans(10)).foregroundColor(RUColor.text2)
                }
                Spacer()
                Text("▾").foregroundColor(RUColor.rose2)
            }
            .padding(13)
            .background(RUColor.rose.opacity(0.08))

            VStack(spacing: 0) {
                ForEach(currentWeekDays.indices, id: \.self) { i in
                    let d = currentWeekDays[i]
                    HStack(spacing: 11) {
                        Text(d.letter).displayStyle(10).foregroundColor(RUColor.text2).frame(width: 26, alignment: .leading)
                        Circle().fill(d.color).opacity(d.status == "done" ? 1 : 0.5).frame(width: 6, height: 6)
                        Text(d.name)
                            .font(RUFont.sans(12.5, weight: d.status == "today" ? .semibold : .regular))
                            .foregroundColor(d.status == "rest" ? RUColor.text3 : .white)
                        if d.status == "today" {
                            StatChip(text: "aujourd'hui", color: RUColor.rose2)
                        }
                        Spacer()
                        Text(d.meta).font(RUFont.mono(10)).foregroundColor(RUColor.text2)
                        if d.status == "done" {
                            Text("✓").foregroundColor(RUColor.rose).font(.system(size: 11))
                        }
                    }
                    .padding(.vertical, 9).padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 12).padding(.bottom, 12).padding(.top, 6)
        }
        .background(RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(RUColor.rose.opacity(0.3), lineWidth: RUSpacing.hairline))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func weekRow(_ week: WeekRow) -> some View {
        let done = week.status == "done"
        let badge = week.status == "race" ? "🏁" : week.status == "taper" ? "▽" : done ? "✓" : "›"
        let color: Color = week.status == "race" ? RUColor.rose : week.status == "taper" ? RUColor.violet : done ? RUColor.text3 : RUColor.text2
        return HStack(spacing: 12) {
            Text("\(week.number)").displayStyle(13).foregroundColor(color)
                .frame(width: 30, height: 30)
                .background(done ? Color.white.opacity(0.06) : (week.status == "race" ? RUColor.rose.opacity(0.15) : Color.white.opacity(0.05)), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
            VStack(alignment: .leading, spacing: 1) {
                Text("Semaine \(week.number) · \(week.phase)").font(RUFont.sans(13, weight: .medium)).foregroundColor(.white)
                Text(week.km).font(RUFont.sans(10)).foregroundColor(RUColor.text2)
            }
            Spacer()
            Text(badge).foregroundColor(color).font(.system(size: 13))
        }
        .padding(13)
        .opacity(done ? 0.6 : 1)
        .background(RUColor.card2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(week.status == "race" ? RUColor.rose.opacity(0.25) : RUColor.line, lineWidth: RUSpacing.hairline))
    }
}
