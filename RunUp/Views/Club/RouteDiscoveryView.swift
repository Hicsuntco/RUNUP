import SwiftUI
import MapKit

/// « Je suis à Lisbonne trois jours, où je cours ? »
///
/// La carte montre les itinéraires que d'autres ont publiés autour de l'endroit affiché, et la
/// liste en dessous les rend lisibles : un nom, une ville, une distance, et combien de personnes
/// les ont gardés. Le tri par défaut est le nombre d'enregistrements plutôt que la nouveauté —
/// enregistrer un itinéraire veut dire « j'ai l'intention de le courir », là où un « j'aime » ne
/// coûte rien.
///
/// Rien ne se recharge pendant qu'on déplace la carte : un bouton « chercher ici » apparaît quand
/// la zone a changé. Recharger à chaque geste ferait dix requêtes pour un panoramique et ferait
/// sauter la liste sous le doigt.
struct RouteDiscoveryView: View {
    @Environment(AppState.self) private var appState

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var searchedRegion: MKCoordinateRegion?
    @State private var routes: [SharedRoute] = []
    @State private var isLoading = false
    @State private var loadFailed = false
    @State private var selected: SharedRoute?
    @State private var filter: DistanceFilter = .all

    /// Les distances que les gens cherchent vraiment quand ils arrivent quelque part.
    private enum DistanceFilter: String, CaseIterable, Identifiable {
        case all, short, ten, long
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return String(localized: "Toutes")
            case .short: return String(localized: "≤ 6 km")
            case .ten: return String(localized: "6–15 km")
            case .long: return String(localized: "15 km +")
            }
        }
        var bounds: (min: Double?, max: Double?) {
            switch self {
            case .all: return (nil, nil)
            case .short: return (nil, 6)
            case .ten: return (6, 15)
            case .long: return (15, nil)
            }
        }
    }

    /// Vrai quand la carte a bougé assez loin de la dernière recherche pour qu'elle vaille la peine
    /// d'être refaite — comparer les centres évite de proposer « chercher ici » après un
    /// tremblement de doigt.
    private var regionMovedSinceSearch: Bool {
        guard let visible = visibleRegion else { return false }
        guard let searched = searchedRegion else { return true }
        let dLat = abs(visible.center.latitude - searched.center.latitude)
        let dLng = abs(visible.center.longitude - searched.center.longitude)
        return dLat > searched.span.latitudeDelta / 3 || dLng > searched.span.longitudeDelta / 3
    }

    var body: some View {
        VStack(spacing: 0) {
            mapSection
            filterBar
            listSection
        }
        .background(RUColor.pageBackground)
        .sheet(item: $selected) { route in
            RouteDetailSheet(route: route) { updated in
                if let index = routes.firstIndex(where: { $0.id == updated.id }) { routes[index] = updated }
            }
            .runUpSheetStyle()
        }
        .task { if routes.isEmpty { await search() } }
    }

    // MARK: - Carte

    private var mapSection: some View {
        ZStack(alignment: .top) {
            Map(position: $camera) {
                UserAnnotation()
                ForEach(routes) { route in
                    let coordinates = route.drawableCoordinates
                    if coordinates.count > 1 {
                        MapPolyline(coordinates: coordinates)
                            .stroke(route.id == selected?.id ? RUColor.rose : RUColor.rose.opacity(0.75),
                                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    }
                    // L'épingle porte la distance : c'est l'information qui décide, et elle évite
                    // d'ouvrir cinq itinéraires pour trouver celui qui fait la bonne longueur.
                    Annotation(route.name, coordinate: route.startCoordinate) {
                        Button { selected = route } label: {
                            Text(route.distanceKm.map { String(format: "%.0f", $0) } ?? "?")
                                .font(RUFont.sans(11, weight: .bold))
                                .foregroundColor(RUColor.onRose)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(RUColor.rose))
                                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1.5))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .mapControls { MapUserLocationButton() }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
            }

            if regionMovedSinceSearch && !isLoading {
                Button {
                    Haptics.selection()
                    Task { await search() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Chercher dans cette zone")
                    }
                    .font(RUFont.sans(12.5, weight: .semibold))
                    .foregroundColor(RUColor.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(RUColor.card))
                    .overlay(Capsule().stroke(RUColor.cardBorder, lineWidth: RUSpacing.hairline))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 12)
            }
        }
        .frame(height: 300)
    }

    // MARK: - Filtre

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DistanceFilter.allCases) { option in
                    let isOn = filter == option
                    Button {
                        filter = option
                        Haptics.selection()
                        Task { await search() }
                    } label: {
                        Text(option.label)
                            .font(RUFont.sans(12.5, weight: .semibold))
                            .foregroundColor(isOn ? RUColor.onRose : RUColor.text2)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(isOn ? RUColor.rose : RUColor.card2))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, RUSpacing.pagePadding)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Liste

    @ViewBuilder
    private var listSection: some View {
        if isLoading && routes.isEmpty {
            centeredMessage(String(localized: "Recherche des itinéraires…"))
        } else if loadFailed {
            centeredMessage(String(localized: "Impossible de charger les itinéraires — vérifie ta connexion."))
        } else if routes.isEmpty {
            // Un vide honnête : sur une carte vierge, la bonne action est de publier, pas de
            // réessayer.
            centeredMessage(String(localized: "Personne n'a encore partagé d'itinéraire par ici. Publie le tien après ta prochaine sortie et tu seras la première."))
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(routes) { route in
                        Button { selected = route } label: { RouteRow(route: route) }
                            .buttonStyle(PressableStyle())
                    }
                }
                .padding(.horizontal, RUSpacing.pagePadding)
                .padding(.bottom, RUSpacing.tabBarBottomInset + RUSpacing.tabBarHeight + 20)
            }
        }
    }

    private func centeredMessage(_ text: String) -> some View {
        Text(text)
            .font(RUFont.sans(13.5))
            .foregroundColor(RUColor.text3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Chargement

    private func search() async {
        guard let region = visibleRegion ?? camera.region else { return }
        isLoading = true
        loadFailed = false
        // Une marge de 20 % au-delà de ce qui est dessiné : un itinéraire dont le départ tombe
        // juste hors cadre reste pertinent, et ça évite qu'un micro-déplacement fasse apparaître
        // et disparaître des tracés.
        let latPad = region.span.latitudeDelta * 0.6
        let lngPad = region.span.longitudeDelta * 0.6
        let bounds = filter.bounds
        do {
            let found = try await ClubService(auth: appState.auth).fetchRoutesNearby(
                minLat: region.center.latitude - latPad,
                maxLat: region.center.latitude + latPad,
                minLng: region.center.longitude - lngPad,
                maxLng: region.center.longitude + lngPad,
                distMin: bounds.min,
                distMax: bounds.max
            )
            routes = found
            searchedRegion = region
        } catch {
            loadFailed = true
        }
        isLoading = false
    }
}

/// Une ligne de la liste : la forme du parcours, son nom, où il est, sa longueur.
private struct RouteRow: View {
    var route: SharedRoute

    var body: some View {
        HStack(spacing: 12) {
            // La photo prime sur le tracé : c'est elle qui fait ouvrir une ligne. La forme du
            // parcours reste consultable en grand dans le détail, où elle sert vraiment à décider.
            Group {
                if let photoUrl = route.photoUrl, let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        RUColor.card2
                    }
                } else {
                    RouteThumbnail(route: route.drawableCoordinates.map {
                        RunRecord.RoutePoint(lat: $0.latitude, lng: $0.longitude, altitude: nil)
                    })
                    .background(RUColor.card2)
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(route.name)
                    .font(RUFont.sans(14.5, weight: .semibold))
                    .foregroundColor(RUColor.textPrimary)
                    .lineLimit(1)
                Text(route.subtitleLine)
                    .font(RUFont.sans(11.5))
                    .foregroundColor(RUColor.text3)
                if let elevation = route.elevationGainM, elevation > 0 {
                    Text("\(elevation) m D+")
                        .font(RUFont.mono(10.5))
                        .foregroundColor(RUColor.text3)
                }
            }
            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Image(systemName: route.saved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 13))
                    .foregroundColor(route.saved ? RUColor.rose : RUColor.text3)
                Text("\(route.savesCount)")
                    .font(RUFont.mono(10.5))
                    .foregroundColor(RUColor.text3)
            }
        }
        .padding(12)
        .ruCard()
    }
}
