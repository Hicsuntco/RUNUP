import SwiftUI

/// Étape 3 pour l'objectif « duathlon » : format → chrono visé → date.
///
/// # TROIS QUESTIONS, LÀ OÙ LE TRIATHLON EN POSE QUATRE
///
/// Il n'y a rien à demander sur le vélo. La quatrième question du triathlon — ce qu'elle nage
/// aujourd'hui — existe parce que le plan ne pourra JAMAIS la corriger tout seul : l'app ne
/// voit rien sous l'eau. Le vélo, elle le mesure, donc une réponse approximative se rattrape à
/// la première sortie. Une question qui ne change pas une décision ne vaut pas une étape.
///
/// # CE QUE L'ÉCRAN DIT À LA PLACE
///
/// La phrase sous le format ne demande rien : elle nomme la seconde course. C'est la seule
/// chose qu'il faut avoir comprise avant de choisir, et c'est celle qu'on ne voit pas en
/// lisant « 10 km · 40 km · 5 km » — ces cinq derniers kilomètres ne ressemblent pas à cinq
/// kilomètres. Le plan existe pour eux.
struct DuathlonDetailsStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            ScrollView {
                ObTitle(eyebrow: GoalType.duathlon.etapeEyebrow,
                        title: GoalType.duathlon.etapeTitre,
                        subtitle: GoalType.duathlon.etapePromesse)

                EyebrowLabel(text: "Format", color: RUColor.text3)
                    .padding(.top, 20).padding(.bottom, 10)
                VStack(spacing: 8) {
                    ForEach(DuathlonFormat.allCases) { f in
                        // Les trois distances en sous-titre, dans l'ordre où elles se courent.
                        SelectableCard(selected: vm.duathlonFormat == f, emoji: nil, title: f.title, subtitle: f.resume) {
                            vm.selectDuathlonFormat(f)
                        }
                    }
                }

                if let laSecondeCourse {
                    Text(laSecondeCourse)
                        .font(RUFont.sans(.small)).foregroundColor(RUColor.text2).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(13)
                        .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                        .padding(.top, 10)
                }

                EyebrowLabel(text: "Ton objectif chrono", color: RUColor.text3)
                    .padding(.top, 22).padding(.bottom, 10)
                ChipFlowLayout {
                    ForEach(vm.duathlonFormat?.chronoPresets ?? [], id: \.self) { t in
                        SelectableChip(label: t, selected: vm.chrono == t && !vm.isCustomChrono) {
                            vm.chrono = t; vm.isCustomChrono = false
                        }
                    }
                    SelectableChip(label: "Juste finir 😅", selected: vm.chrono == "finir" && !vm.isCustomChrono) {
                        vm.chrono = "finir"; vm.isCustomChrono = false
                    }
                    SelectableChip(label: "Mon propre temps", selected: vm.isCustomChrono) {
                        vm.isCustomChrono = true; vm.chrono = ""
                    }
                }

                if vm.isCustomChrono {
                    ObTextField(placeholder: "Ex. 2:48:00", text: Binding(get: { vm.chrono ?? "" }, set: { vm.chrono = $0 }))
                        .padding(.top, 10)
                }

                EyebrowLabel(text: "Date de l'épreuve", color: RUColor.text3)
                    .padding(.top, 22).padding(.bottom, 10)
                DatePicker(
                    "",
                    selection: Binding(get: { vm.raceDate ?? Calendar.current.date(byAdding: .day, value: 90, to: .now)! }, set: { vm.raceDate = $0 }),
                    in: Calendar.current.date(byAdding: .day, value: 1, to: .now)!...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .colorScheme(RUColor.colorScheme)
                .padding(13)
                .background(RUColor.card, in: RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusCompact, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))

                if let days = vm.daysUntilRace {
                    Text("J-\(days)").font(RUFont.sans(.body, weight: .semibold)).foregroundColor(RUColor.rose2).padding(.top, 10)
                }
            }
            ObNext(disabled: !vm.canProceed(fromStep: 3), action: onNext)
        }
    }

    /// CE QUE LE FORMAT CHOISI VEUT VRAIMENT DIRE.
    ///
    /// Pas un avertissement, pas un « es-tu sûre » : deux nombres et ce que le plan en fera.
    /// Même esprit que la phrase d'écart du triathlon, et même contrainte d'écriture — deux
    /// interpolations, pas six, parce qu'au-delà le vérificateur de types de Swift abandonne
    /// (constaté sur `UltraRaceDaySheet`).
    ///
    /// Les kilomètres passent par `DuathlonFormat.km` et non par une seconde mise en forme
    /// écrite ici : « 2.5 km » sous une carte qui dit « 2,5 km » serait le même écran se
    /// contredisant.
    private var laSecondeCourse: LocalizedStringKey? {
        guard let format = vm.duathlonFormat else { return nil }
        return "Le jour J, tu reprendras à pied pour \(DuathlonFormat.km(format.secondeCourseKm)) après \(DuathlonFormat.km(format.veloKm)) de vélo. C'est cette seconde course que le plan prépare — c'est elle qui décide de la journée, et elle ne ressemble pas au même nombre de kilomètres à froid."
    }
}
