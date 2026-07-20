import SwiftUI

/// Condensed 3-step new-goal wizard (goal → race details → days → building). Mirrors
/// `NewGoalFlow` in screensD.jsx.
struct NewGoalWizardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var goal: GoalType?
    @State private var distance: RaceDistance = .k10
    @State private var chrono: String = RaceDistance.k10.chronoPresets[1]
    @State private var raceDate = Calendar.current.date(byAdding: .day, value: 60, to: .now)!
    @State private var days: Set<Int> = [1, 2, 4, 6]
    @State private var building = false
    @State private var buildPct: Double = 0

    private let goals: [GoalType] = GoalType.allCases.filter { $0 != .restart }

    var body: some View {
        ZStack {
            RUColor.bg.ignoresSafeArea()
            if building {
                buildingView
            } else {
                content
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    BackChevronButton {
                        if step == 0 { dismiss() } else { step -= 1 }
                    }
                    Text("Nouvel objectif").displayStyle(20).foregroundColor(RUColor.textPrimary)
                }
                .padding(.top, 8)

                switch step {
                case 0: goalStep
                case 1 where goal == .race: raceStep
                default: daysStep
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.bottom, 40)
        }
    }

    private var goalStep: some View {
        VStack(spacing: 8) {
            ForEach(goals) { g in
                SelectableCard(selected: goal == g, emoji: g.emoji, title: g.title, subtitle: nil) { goal = g }
            }
            Button("CONTINUER") { step = goal == .race ? 1 : 2 }
                .buttonStyle(PrimaryButtonStyle(isDisabled: goal == nil))
                .disabled(goal == nil)
                .padding(.top, 8)
        }
    }

    private var raceStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: "Distance", color: RUColor.text3).padding(.bottom, 10)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach([RaceDistance.k5, .k10, .semi, .marathon], id: \.self) { d in
                    Button(action: { distance = d; chrono = d.chronoPresets[1] }) {
                        Text(d.label).displayStyle(20).foregroundColor(distance == d ? RUColor.rose2 : RUColor.textPrimary)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(distance == d ? RUColor.rose.opacity(0.12) : RUColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(distance == d ? RUColor.rose.opacity(0.4) : RUColor.line, lineWidth: RUSpacing.hairline))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            EyebrowLabel(text: "Chrono visé", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            ChipFlowLayout {
                ForEach(distance.chronoPresets, id: \.self) { t in
                    SelectableChip(label: t, selected: chrono == t) { chrono = t }
                }
            }
            EyebrowLabel(text: "Date de la course", color: RUColor.text3).padding(.top, 20).padding(.bottom, 10)
            DatePicker(
                "",
                selection: $raceDate,
                in: Calendar.current.date(byAdding: .day, value: 1, to: .now)!...,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .colorScheme(RUColor.colorScheme)
            .padding(13)
            .background(RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(RUColor.line, lineWidth: RUSpacing.hairline))
            Button("CONTINUER") { step = 2 }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 20)
        }
    }

    private var daysStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            EyebrowLabel(text: "Tes jours de course", color: RUColor.text3).padding(.bottom, 10)
            HStack(spacing: 7) {
                ForEach(0..<7) { i in
                    let on = days.contains(i)
                    Button(action: { if on { days.remove(i) } else { days.insert(i) } }) {
                        Text(DayStatus.letters[i]).displayStyle(15).foregroundColor(on ? .white : RUColor.text2)
                            .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                            .background(on ? RUColor.rose : RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            Button("CONSTRUIRE MON PROGRAMME") { building = true; scheduleFinish() }
                .buttonStyle(PrimaryButtonStyle(isDisabled: days.count < 2))
                .disabled(days.count < 2)
                .padding(.top, 20)
        }
    }

    private var buildingView: some View {
        VStack(spacing: 20) {
            // Was a fixed pct: 70 — a gauge that never actually moved or finished reads as fake
            // progress; this now genuinely animates to 100% over the same wait `scheduleFinish`
            // uses before the new program is actually ready.
            RingView(pct: buildPct, color: RUColor.rose, size: 100, strokeWidth: 7) {
                Text(buildPct >= 100 ? "✓" : "🎯")
                    .font(.system(size: 26))
                    .foregroundColor(buildPct >= 100 ? RUColor.lime : RUColor.textPrimary)
            }
            Text("Ton nouveau\nprogramme arrive").displayStyle(22).multilineTextAlignment(.center).foregroundColor(RUColor.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scheduleFinish() {
        withAnimation(.easeInOut(duration: 2.2)) { buildPct = 100 }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            await MainActor.run {
                let result = AdaptivePlanEngine.NewGoalResult(goal: goal ?? .health, distance: goal == .race ? distance : nil, chrono: goal == .race ? chrono : nil, raceDate: goal == .race ? raceDate : nil, runningDays: Array(days))
                AdaptivePlanEngine.startNewProgram(result, profile: appState.profile)
                NotificationService.shared.rescheduleDailyReminder(for: appState.profile)
                appState.toast("Ton nouveau programme est prêt")
                dismiss()
                appState.go(.home)
            }
        }
    }
}
