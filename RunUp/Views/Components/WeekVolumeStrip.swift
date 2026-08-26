import SwiftUI
import SwiftData

/// Douze semaines de volume, en une bande de barres.
///
/// C'est le seul endroit de l'app où la RÉGULARITÉ se voit d'un coup d'œil : le total cumulé et
/// le compteur de semaines d'affilée disent tous les deux un chiffre, aucun des deux ne dit la
/// forme de la courbe — trois grosses semaines suivies d'un mois à zéro produisent exactement le
/// même « 403 km » qu'un entraînement régulier. La bande, elle, montre la différence.
///
/// Les semaines sont ancrées au lundi via `AdaptivePlanEngine.currentWeekRange(from:)`, la même
/// borne que le graphe de Stats et que le récap hebdo : « cette semaine » doit désigner la même
/// période partout, sans quoi deux écrans de la même app se contredisent à la lecture.
struct WeekVolumeStrip: View {
    var runs: [RunRecord]
    var weekCount: Int = 12
    /// Hauteur de la barre la plus haute — les autres sont proportionnelles au pic de la période,
    /// pas à un maximum absolu : c'est la forme relative qui porte l'information.
    var barHeight: CGFloat = 34

    /// Volume par semaine, de la plus ancienne à la semaine en cours.
    private var weekly: [Double] {
        let cal = Calendar.current
        var totals: [Date: Double] = [:]
        for run in runs {
            totals[AdaptivePlanEngine.currentWeekRange(from: run.date).lowerBound, default: 0] += run.distanceKm
        }
        let thisWeekStart = AdaptivePlanEngine.currentWeekRange().lowerBound
        return (0..<weekCount).reversed().compactMap { offset in
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -offset, to: thisWeekStart) else { return nil }
            return totals[weekStart] ?? 0
        }
    }

    var body: some View {
        let weeks = weekly
        let peak = weeks.max() ?? 0
        let total = weeks.reduce(0, +)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                EyebrowLabel(text: "Volume hebdomadaire")
                Spacer(minLength: 8)
                Text(String(format: "%.0f km", total))
                    .font(RUFont.mono(10, weight: .medium))
                    .foregroundColor(RUColor.text2)
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, km in
                    bar(km: km, peak: peak)
                }
            }
            .frame(height: barHeight, alignment: .bottom)

            HStack {
                Text("il y a \(weekCount) sem.")
                    .font(RUFont.sans(8, weight: .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(RUColor.text3)
                Spacer(minLength: 8)
                Text("cette sem.")
                    .font(RUFont.sans(8, weight: .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(RUColor.text3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 11)
        .padding(.bottom, 9)
        .ruCard(radius: RUSpacing.radiusCompact)
        // Douze barres décoratives lues une par une n'apprennent rien à VoiceOver ; le total et
        // le pic, si.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            localized: "\(String(format: "%.0f", total)) kilomètres sur les \(weekCount) dernières semaines, avec un pic à \(String(format: "%.0f", peak)) kilomètres."
        ))
    }

    private func bar(km: Double, peak: Double) -> some View {
        // Une semaine à zéro garde un trait de 2 pt plutôt que de disparaître : un trou dans la
        // bande est une information (« je n'ai pas couru »), une barre absente est un bug de
        // rendu. Et les semaines courues démarrent à 4 pt même quand le pic les écrase, sans quoi
        // une semaine de récup à 6 km à côté d'un pic à 60 devient indistincte d'un zéro.
        let ratio = peak > 0 ? km / peak : 0
        let height: CGFloat = km <= 0 ? 2 : max(4, barHeight * CGFloat(ratio))
        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(km <= 0
                  ? AnyShapeStyle(RUColor.text4)
                  : AnyShapeStyle(RUColor.accentGradient(from: .top, to: .bottom)))
            .frame(height: height)
            .frame(maxWidth: .infinity)
    }
}
