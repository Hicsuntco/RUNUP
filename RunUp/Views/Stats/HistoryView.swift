import SwiftUI
import SwiftData

/// Run history — mirrors `HistoryScreen` in screensC.jsx. Uses a real `@Query` over `RunRecord`
/// so newly completed runs appear automatically ahead of older ones (newest-first).
struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RunRecord.date, order: .reverse) private var runs: [RunRecord]
    @State private var showAddRun = false
    @State private var pendingDelete: RunRecord?
    @State private var selectedRun: RunRecord?

    var body: some View {
        // A plain ScrollView/VStack can't do real swipe-to-delete — .swipeActions only works on
        // List rows — so this is a List dressed up to look like the same card-based layout
        // (clear row backgrounds, hidden separators/insets) rather than a stock List.
        List {
            header
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            if appState.pendingActivityCount > 0 {
                pendingSyncBanner
                    .padding(.horizontal, RUSpacing.pagePadding)
                    .padding(.bottom, 6)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if runs.isEmpty {
                Text("Aucune course pour l'instant — termine une sortie ou ajoutes-en une manuellement.")
                    .font(RUFont.sans(12)).foregroundColor(RUColor.text2)
                    .padding(.horizontal, RUSpacing.pagePadding)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            ForEach(runs) { run in
                runCard(run)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedRun = run }
                    .listRowInsets(EdgeInsets(top: 4, leading: RUSpacing.pagePadding, bottom: 4, trailing: RUSpacing.pagePadding))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing) {
                        Button("Supprimer", role: .destructive) { pendingDelete = run }
                    }
                    .contextMenu {
                        if let url = GPXExporter.fileURL(for: run) {
                            ShareLink(item: url) {
                                Label("Exporter en GPX", systemImage: "square.and.arrow.up")
                            }
                        }
                        Button("Supprimer", role: .destructive) { pendingDelete = run }
                    }
            }

            Color.clear.frame(height: 130)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RUColor.pageBackground)
        .sheet(isPresented: $showAddRun) { AddRunSheet() }
        .sheet(item: $selectedRun) { run in RecapView(historicalRun: run) }
        .alert(
            "Supprimer cette course ?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
        ) {
            Button("Supprimer", role: .destructive) {
                if let run = pendingDelete {
                    // A deleted run that was today's "séance faite" shouldn't leave the daily
                    // goals gauge claiming it's done with nothing left backing it — but only when
                    // NO other run today remains (deleting a second short jog must not un-check a
                    // séance the morning's real run still backs).
                    let otherRunToday = runs.contains {
                        $0 !== run && Calendar.current.isDateInToday($0.date)
                    }
                    if Calendar.current.isDateInToday(run.date) && !otherRunToday {
                        AdaptivePlanEngine.undoTodaySessionCompletion(appState.profile)
                    }
                    // `runs` won't reflect the deletion until the next @Query update cycle, so
                    // the remaining set is computed by hand rather than read back immediately.
                    AdaptivePlanEngine.recomputeStreak(profile: appState.profile, currentRuns: runs.filter { $0 !== run })
                    modelContext.delete(run)
                    Haptics.warning()
                }
                pendingDelete = nil
            }
            Button("Annuler", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Cette action est définitive.")
        }
    }

    private var header: some View {
        BackTitleHeaderView(eyebrow: String(localized: "\(runs.count) sortie\(runs.count > 1 ? "s" : "")"), title: "Historique") {
            appState.go(.stats)
        } trailing: {
            Button(action: { showAddRun = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(RUColor.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(RUColor.card, in: Circle())
                    .overlay(Circle().stroke(RUColor.line, lineWidth: RUSpacing.hairline))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Ajouter une course")
        }
        .padding(.horizontal, RUSpacing.pagePadding)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    /// Surfaces `ClubActivityOutbox`'s real queue — before this, a run that failed to reach the
    /// server (spotty connection right when it finished) silently never got its XP/feed entry
    /// synced, with no visible sign anything was wrong; the outbox already retried opportunistically
    /// in the background, but nothing ever told her that, or let her force it. Doesn't call out
    /// which specific run is affected (the outbox tracks payloads, not a link back to a
    /// `RunRecord`) — a single "N en attente" banner is the honest scope of what's knowable here.
    private var pendingSyncBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15))
                .foregroundColor(RUColor.amberText)
                .frame(width: 30, height: 30)
                .background(RUColor.amber.opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(appState.pendingActivityCount == 1
                     ? String(localized: "1 course pas encore synchronisée")
                     : String(localized: "\(appState.pendingActivityCount) courses pas encore synchronisées"))
                    .font(RUFont.sans(12.5, weight: .semibold))
                    .foregroundColor(RUColor.textPrimary)
                Text("Elles restent sur ton téléphone, rien n'est perdu — nouvelle tentative automatique bientôt.")
                    .font(RUFont.sans(10.5))
                    .foregroundColor(RUColor.text2)
                Button(action: {
                    Haptics.selection()
                    appState.retryPendingClubActivities()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 10, weight: .semibold))
                        Text("Réessayer maintenant")
                    }
                    .font(RUFont.sans(11, weight: .semibold))
                    .foregroundColor(RUColor.rose)
                    .frame(minHeight: 30)
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RUColor.amber.opacity(0.1), in: RoundedRectangle(cornerRadius: RUSpacing.radiusStandard, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RUSpacing.radiusStandard, style: .continuous).stroke(RUColor.amber.opacity(0.35), lineWidth: RUSpacing.hairline))
    }

    /// La `.hist-row` de la maquette : vignette du parcours à GAUCHE, puis date / titre / trois
    /// chiffres en ligne, dans une carte nettement plus basse (12 pt de marge et rayon compact au
    /// lieu de 16 pt et rayon standard).
    ///
    /// L'ancienne composition empilait trois `MetricColumn` de 20 pt surmontées de leurs
    /// libellés en capitales (« KM », « TEMPS », « ALLURE MOY ») : trois fois plus haut, pour des
    /// libellés qui se répètent à l'identique sur chaque ligne d'une liste qui n'affiche que ça —
    /// « 6,4 km · 27:53 · 4:21/km » se lit sans eux. La vignette passe à gauche : sur une liste,
    /// c'est la colonne d'images qui donne le rythme de balayage, et à droite elle se retrouvait
    /// décalée d'une ligne à l'autre selon la longueur du titre.
    private func runCard(_ run: RunRecord) -> some View {
        HStack(spacing: 12) {
            runThumbnail(run)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(run.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale.current))
                        .font(RUFont.sans(10, weight: .semibold)).foregroundColor(RUColor.text3)
                    Spacer(minLength: 0)
                    // A manually-logged run has no real heart-rate reading — 0 would just be a
                    // fake number dressed up as data, so the line is dropped entirely instead.
                    if run.avgHeartRate > 0 {
                        Text("FC moy \(run.avgHeartRate)").font(RUFont.sans(10)).foregroundColor(RUColor.text3)
                    }
                }
                Text(run.title)
                    .font(RUFont.sans(14, weight: .semibold)).foregroundColor(RUColor.textPrimary)
                    .lineLimit(1).minimumScaleFactor(0.8)
                HStack(spacing: 12) {
                    Text(String(format: "%.1f km", locale: Locale.current, run.distanceKm))
                    Text(PaceModel.formatDuration(Double(run.durationSeconds)))
                    // Seule l'allure reste colorée : c'est le chiffre que la maquette met en
                    // accent sur cette ligne, et le seul des trois qui dise quelque chose de la
                    // performance plutôt que du volume.
                    Text(run.avgPace + "/km").foregroundColor(RUColor.rose2)
                    Spacer(minLength: 0)
                }
                .font(RUFont.sans(11.5, weight: .semibold))
                .foregroundColor(RUColor.text2)
                .lineLimit(1).minimumScaleFactor(0.8)
                .padding(.top, 1)
            }
        }
        .padding(12)
        .ruCard(radius: RUSpacing.radiusCompact)
        // The main screen for reviewing past training — without this, each run swiped through
        // with VoiceOver was 8-9 disconnected stops (date, optional HR, title, then three
        // separate value/label pairs) instead of one coherent "this run" element. Les libellés
        // « km / temps / allure » ayant disparu de l'écran, ils sont réinjectés ici : sans eux,
        // VoiceOver lisait « 6,4 km, 27:53, 4:21/km » sans dire ce que sont les deux derniers.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(runAccessibilityLabel(run))
    }

    /// Une course saisie à la main (ou marquée faite sans GPS) n'a pas de tracé — on montre une
    /// icône neutre sur fond de carte, jamais une courbe décorative qui ferait passer une absence
    /// de données pour un parcours. La tuile reste là dans les deux cas : c'est elle qui aligne
    /// toutes les lignes de la liste.
    @ViewBuilder
    private func runThumbnail(_ run: RunRecord) -> some View {
        Group {
            if run.route.count > 1 {
                RunRouteMapView(route: run.route, lineWidth: 2.5)
            } else {
                Image(systemName: "figure.run")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(RUColor.text3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RUColor.card2)
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
        // Purely decorative for VoiceOver — the distance/time/pace it traces are already read
        // from the row's own label, and an unlabeled thumbnail otherwise reads as a bare,
        // meaningless "Map" stop.
        .accessibilityHidden(true)
    }

    private func runAccessibilityLabel(_ run: RunRecord) -> String {
        var parts: [String] = [
            run.date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale.current)),
            run.title,
            String(localized: "\(String(format: "%.1f", locale: Locale.current, run.distanceKm)) kilomètres"),
            String(localized: "durée \(PaceModel.formatDuration(Double(run.durationSeconds)))"),
            String(localized: "allure moyenne \(run.avgPace) par kilomètre")
        ]
        if run.avgHeartRate > 0 { parts.append(String(localized: "fréquence cardiaque moyenne \(run.avgHeartRate)")) }
        return parts.joined(separator: ", ")
    }
}
