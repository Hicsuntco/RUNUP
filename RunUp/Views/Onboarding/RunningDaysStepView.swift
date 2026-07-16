import SwiftUI

struct RunningDaysStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            ObTitle(eyebrow: "Étape 4 · ton rythme", title: "TES JOURS DE COURSE", subtitle: "Le programme se cale dessus — tu pourras toujours bouger une séance.")
            HStack(spacing: 7) {
                ForEach(0..<7) { i in
                    let on = vm.runningDays.contains(i)
                    Button(action: {
                        if on { vm.runningDays.remove(i) } else { vm.runningDays.insert(i) }
                    }) {
                        Text(DayStatus.letters[i])
                            .displayStyle(15)
                            .foregroundColor(on ? .white : RUColor.text2)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(on ? RUColor.rose : RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.top, 22)

            Text(vm.runningDays.count < 2 ? "Choisis au moins 2 jours pour progresser" : "\(vm.runningDays.count) jours / semaine — bon rythme")
                .font(RUFont.sans(12))
                .foregroundColor(vm.runningDays.count < 2 ? RUColor.amber : RUColor.text2)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)

            if vm.runningDays.count >= 2 {
                EyebrowLabel(text: "Jour de ta sortie longue", color: RUColor.text3).padding(.top, 20)
                Text("Le plan y calera toujours ta séance la plus longue de la semaine.")
                    .font(RUFont.sans(11)).foregroundColor(RUColor.text3).padding(.top, 2)
                HStack(spacing: 7) {
                    ForEach(vm.runningDays.sorted(), id: \.self) { i in
                        let on = vm.effectiveLongRunDay == i
                        Button(action: { vm.preferredLongRunDay = i }) {
                            Text(DayStatus.letters[i])
                                .displayStyle(15)
                                .foregroundColor(on ? .white : RUColor.text2)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background(on ? RUColor.rose : RUColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.top, 10)
            }

            Spacer()
            ObNext(disabled: !vm.canProceed(fromStep: 4), action: onNext)
        }
    }
}
