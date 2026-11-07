import MapKit
import SwiftUI

private let routeMapHeight: CGFloat = 260
private let routeLineWidth: CGFloat = 5
private let lookAroundHeight: CGFloat = 200

/// A cinema: the way there on a map, the address, the links and photos of the street.
/// The route loads again each time the user switches between Walk and Drive.
struct CinemaDetailView: View {
    @State private var viewModel: CinemaDetailViewModel
    /// Frames the cinema, the user and the route as they appear on the map.
    @State private var cameraPosition = MapCameraPosition.automatic
    /// nil until it loads, and when Apple has no photos of the street.
    @State private var lookAroundScene: MKLookAroundScene?

    init(viewModel: CinemaDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section { routeMap }
            Section { addressAndDistance }
            Section("Way There") { wayThere }
            Section { links }
            lookAroundSection
        }
        .navigationTitle(cinema.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: viewModel.travelMode) { await viewModel.loadRoute() }
        .task { lookAroundScene = await findLookAroundScene(cinema) }
    }

    private var cinema: Cinema {
        viewModel.cinema
    }

    private var routeMap: some View {
        Map(position: $cameraPosition) {
            Marker(cinema.name, systemImage: symbolNameCinema, coordinate: cinemaCoordinate(cinema))
            UserAnnotation()
            if viewModel.routeState == .loaded {
                MapPolyline(viewModel.route.line).stroke(.blue, lineWidth: routeLineWidth)
            }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .frame(height: routeMapHeight)
        .listRowInsets(EdgeInsets())
    }

    @ViewBuilder
    private var addressAndDistance: some View {
        VStack(alignment: .leading, spacing: spacingTiny) {
            Text(cinema.name)
                .font(.headline)
            Text(cinema.address)
                .foregroundStyle(.secondary)
        }
        if cinema.distanceInMeters != unknownDistance {
            LabeledContent("In a straight line", value: formattedDistance(cinema.distanceInMeters))
        }
    }

    @ViewBuilder
    private var wayThere: some View {
        Picker("Travel mode", selection: $viewModel.travelMode) {
            Text("Walk").tag(TravelMode.walking)
            Text("Drive").tag(TravelMode.driving)
        }
        .pickerStyle(.segmented)
        routeStatus
    }

    @ViewBuilder
    private var routeStatus: some View {
        if !viewModel.canFindRoute {
            Label("Turn on location to see the way there.", systemImage: symbolNameLocationOff)
                .foregroundStyle(.secondary)
        } else {
            loadedRouteStatus
        }
    }

    @ViewBuilder
    private var loadedRouteStatus: some View {
        switch viewModel.routeState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
        case .loaded:
            Label(routeSummary(viewModel.route), systemImage: travelModeSymbolName)
        case .failed:
            Text(viewModel.errorMessage)
                .foregroundStyle(.secondary)
        }
    }

    private var travelModeSymbolName: String {
        switch viewModel.travelMode {
        case .walking:
            return symbolNameWalking
        case .driving:
            return symbolNameDriving
        }
    }

    @ViewBuilder
    private var links: some View {
        Button("Directions in Maps", systemImage: symbolNameDirections) {
            openCinemaInMaps(cinema, travelMode: viewModel.travelMode)
        }
        if let phoneAddress = phoneURL(cinema) {
            Link(destination: phoneAddress) {
                Label(cinema.phoneNumber, systemImage: symbolNamePhone)
            }
        }
        if let websiteAddress = websiteURL(cinema) {
            Link(destination: websiteAddress) {
                Label("Website", systemImage: symbolNameWebsite)
            }
        }
    }

    /// Only when Apple has photos of the street.
    @ViewBuilder
    private var lookAroundSection: some View {
        if let lookAroundScene {
            Section("Look Around") { lookAroundPreview(lookAroundScene) }
        }
    }

    private func lookAroundPreview(_ scene: MKLookAroundScene) -> some View {
        LookAroundPreview(initialScene: scene)
            .frame(height: lookAroundHeight)
            .listRowInsets(EdgeInsets())
    }
}

#Preview {
    NavigationStack {
        CinemaDetailView(
            viewModel: CinemaDetailViewModel(
                cinema: wroclawCinemas[0],
                userLocation: UserLocation(latitude: 51.0983, longitude: 17.0368, isKnown: true),
                findRoute: findMapKitRoute
            )
        )
    }
}
