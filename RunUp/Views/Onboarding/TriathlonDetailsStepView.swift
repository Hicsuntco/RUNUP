import SwiftUI

/// Étape 3 pour l'objectif « triathlon » : format → ce qu'elle nage aujourd'hui → chrono visé →
/// date. Même forme que `HyroxDetailsStepView`, avec une question de plus — et c'est la plus
/// importante de l'écran.
///
/// # POURQUOI LA NATATION EST DEMANDÉE ICI, ET PAS DÉDUITE
///
/// Les trois autres questions dimensionnent un plan ; celle-là protège. Prescrire « 1500 m en
/// continu » à quelqu'un qui n'a jamais enchaîné deux longueurs n'est pas un plan trop dur,
/// c'est quelqu'un seule au milieu d'un bassin. Et c'est la seule discipline que l'app ne voit
/// pas : pas de GPS sous l'eau, aucune façon de s'apercevoir après coup que la séance s'est mal
/// passée. Il n'y a qu'une occasion de poser la question. Voir `NiveauDeNage`.
///
/// L'écart entre le format choisi et ce qu'elle nage est DIT, et jamais opposé : c'est son
/// objectif et c'est sa décision. On lui donne le nombre, pas un avis.
struct TriathlonDetailsStepView: View {
    @Bindable var vm: OnboardingViewModel
    var onNext: () -> Void

    var body: some View {
        ObScreen {
            ScrollView {
                ObTitle(eyebrow: "Étape 3 · ton triathlon", title: "QUEL TRIATHLON ?", subtitle: "Nager, rouler, courir — dans cet ordre, et fatiguée de la précédente à chaque fois.")

                EyebrowLabel(text: "Format", color: RUColor.text3)
                    .padding(.top, 20).padding(.bottom, 10)
                VStack(spacing: 8) {
                    ForEach(TriathlonFormat.allCases) { f in
                        // Les trois distances en sous-titre : c'est ce qui identifie un format
                        // sans employer de marque déposée. Voir `TriathlonFormat`.
                        SelectableCard(selected: vm.triathlonFormat == f, emoji: nil, title: f.title, subtitle: f.resume) {
                            vm.selectTriathlonFormat(f)
                        }
                    }
                }

                EyebrowLabel(text: "Aujourd'hui, tu nages combien sans t'arrêter ?", color: RUColor.text3)
                    .padding(.top, 22).padding(.bottom, 10)
                VStack(spacing: 8) {
                    ForEach(NiveauDeNage.allCases) { n in
                        SelectableCard(selected: vm.nageNiveau == n, emoji: nil, title: n.title, subtitle: n.subtitle) {
                            vm.nageNiveau = n
                        }
                    }
                }

                if let avertissement {
                    Text(avertissement)
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
                    ForEach(vm.triathlonFormat?.chronoPresets ?? [], id: \.self) { t in
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

    /// La phrase qui dit l'écart, quand il y en a un.
    ///
    /// Elle nomme les deux nombres et ce que le plan va faire — pas un jugement, pas un
    /// « es-tu sûre ». Deux phrases plutôt qu'une longue : six interpolations dans un seul
    /// `Text` font abandonner le vérificateur de types de Swift (constaté sur
    /// `UltraRaceDaySheet`), et une phrase de cinquante mots ne se lit pas sur un téléphone.
    private var avertissement: LocalizedStringKey? {
        guard let format = vm.triathlonFormat, let niveau = vm.nageNiveau,
              niveau.ecartNotable(pour: format) else { return nil }
        guard let metres = niveau.metresEnContinu else {
            return "La natation partira de zéro, et c'est très bien — mais apprendre à durer dans l'eau demande un bassin et quelqu'un sur le bord, pas une case de plus dans un plan. Le programme construira le vélo et la course, et montera la natation prudemment."
        }
        return "\(format.nageMetres) m le jour J, contre \(metres) m aujourd'hui. Le plan montera progressivement, et la natation sera la discipline qui prend le plus de place dans ta semaine."
    }
}
