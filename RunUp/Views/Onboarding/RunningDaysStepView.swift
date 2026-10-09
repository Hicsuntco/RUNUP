import SwiftUI

struct RunningDaysStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            ScrollView {
                ObTitle(eyebrow: "Étape 5 · ton rythme", title: "TES JOURS DE COURSE", subtitle: "Le programme se cale dessus — tu pourras toujours bouger une séance.")
                // spacing 5, not 7 — on the smallest currently-supported iPhone (375pt), 7 gaps
                // of 7pt each pushed every square under the 44pt tap-target minimum; 5pt gaps
                // clear it while still reading as a tight 7-day row.
                HStack(spacing: 5) {
                    ForEach(0..<7) { i in
                        let on = vm.runningDays.contains(i)
                        Button(action: {
                            vm.runningDaysTouched = true
                            if on { vm.runningDays.remove(i) } else { vm.runningDays.insert(i) }
                        }) {
                            Text(DayStatus.letters[i])
                                .displayStyle(15)
                                .foregroundColor(on ? .white : RUColor.text2)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .background(on ? RUColor.rose : RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(on ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel(DayStatus.fullNames[i])
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.top, 22)

                Text(phraseDesJours)
                    .font(RUFont.sans(.body))
                    .foregroundColor(vm.runningDays.count < vm.joursMinimum ? RUColor.amber : RUColor.text2)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)

                if vm.runningDays.count >= vm.joursMinimum {
                    EyebrowLabel(text: "Jour de ta sortie longue", color: RUColor.text3).padding(.top, 20)
                    Text("Le plan y calera toujours ta séance la plus longue de la semaine.")
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text3).padding(.top, 2)
                    HStack(spacing: 5) {
                        ForEach(vm.runningDays.sorted(), id: \.self) { i in
                            let on = vm.effectiveLongRunDay == i
                            Button(action: { vm.preferredLongRunDay = i }) {
                                Text(DayStatus.letters[i])
                                    .displayStyle(15)
                                    .foregroundColor(on ? .white : RUColor.text2)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                                    .background(on ? RUColor.rose : RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(on ? RUColor.rose : RUColor.line, lineWidth: RUSpacing.hairline))
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel(DayStatus.fullNames[i])
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(.top, 10)
                }
            }
            ObNext(disabled: !vm.canProceed(fromStep: 5), action: onNext)
        }
    }

    /// LE MINIMUM DÉPEND DE L'OBJECTIF, et la phrase le dit avec son nombre.
    ///
    /// Elle annonçait « au moins 2 jours » à tout le monde, le nombre écrit en dur dans la
    /// chaîne. Un triathlon en exige trois — une semaine à deux jours ne peut pas contenir trois
    /// disciplines, et il manquerait la natation. La phrase aurait donc réclamé deux jours
    /// pendant que le bouton restait gris.
    ///
    /// Trois clés distinctes plutôt qu'une phrase à trou : « au moins 2 jours » et « au moins
    /// 3 jours » ne se traduisent pas en glissant un chiffre dans la même structure selon la
    /// langue, et la seconde a sa propre raison à donner.
    ///
    /// ÉCRITE DANS UN MEMBRE ET PAS DANS LE `Text`, pour une raison de barrière et non de style :
    /// `check_strings.py` ne voit pas un littéral posé dans un `Text(…)` qui s'étale sur
    /// plusieurs lignes, et il a laissé passer la première version de cette phrase sans un mot.
    /// Un membre typé `LocalizedStringKey`, lui, est lu. Voir le commentaire de ce contrôle sur
    /// sa cinquième zone aveugle.
    private var phraseDesJours: LocalizedStringKey {
        guard vm.runningDays.count < vm.joursMinimum else {
            return "\(vm.runningDays.count) jours / semaine — bon rythme"
        }
        if vm.joursMinimum >= 3 {
            return "Choisis au moins 3 jours — un triathlon a trois disciplines"
        }
        return "Choisis au moins 2 jours pour progresser"
    }
}
