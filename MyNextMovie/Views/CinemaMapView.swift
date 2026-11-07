import MapKit
import SwiftUI

/// The map takes this part of the screen height, the list the rest.
private let mapHeightFraction: CGFloat = 0.45

/// Background of the selected row.
private let selectedRowOpacity = 0.15

/// Where the Cinemas screen is shown. Only the sheet has a Done button.
enum CinemaMapPlacement {
    case tab
    case sheet
}

/// The cinemas of Wrocław on a map and in a list under it, the closest first.
/// A pin selects its row and scrolls the list to it. A row moves the map to its cinema.
/// The selection lives in the view model, so it stays when the list is sorted again.
struct CinemaMapView: View {
    @State private var viewModel: CinemaMapViewModel
    private let findRoute: CinemaRouteFinder
    private let placement: CinemaMapPlacement

    @State private var cameraPosition = MapCameraPosition.region(wroclawMapRegion)
    /// Cinemas opened with the info button.
    @State private var openedCinemas: [Cinema] = []
    @Environment(\.dismiss) private var dismiss

    init(
        viewModel: CinemaMapViewModel,
        findRoute: @escaping CinemaRouteFinder,
        placement: CinemaMapPlacement
    ) {
        _viewModel = State(initialValue: viewModel)
        self.findRoute = findRoute
        self.placement = placement
    }

    var body: some View {
        NavigationStack(path: $openedCinemas) {
            ScrollViewReader { listScroller in
                content(scrolling: listScroller)
            }
            .navigationTitle("Cinemas")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Cinema.self) { cinema in cinemaDetail(cinema) }
            .toolbar { doneButton }
        }
        .task { await viewModel.locateUserIfNeeded() }
    }

    /// Without an anchor `scrollTo` scrolls only when the row is off screen, so a tapped pin
    /// brings its row into view and a tapped row stays where it is.
    private func content(scrolling listScroller: ScrollViewProxy) -> some View {
        mapAndList
            .onChange(of: viewModel.selectedCinemaId) { _, cinemaId in
                scrollList(listScroller, to: cinemaId)
            }
    }

    private var mapAndList: some View {
        VStack(spacing: 0) {
            CinemaMap(
                cinemas: viewModel.cinemas,
                cameraPosition: $cameraPosition,
                selectedCinemaId: $viewModel.selectedCinemaIdOrNil,
                cameraChanged: { region in viewModel.visibleRegion = region }
            )
            .containerRelativeFrame(.vertical) { height, _ in height * mapHeightFraction }
            if viewModel.isLocationUnavailable {
                LocationOffLine()
            }
            cinemaList
        }
    }

    private var cinemaList: some View {
        List(viewModel.cinemas) { cinema in
            CinemaRow(
                cinema: cinema,
                isSelected: cinema.id == viewModel.selectedCinemaId,
                select: { selectRow(cinema) },
                showDetails: { openedCinemas.append(cinema) }
            )
            .id(cinema.id)
        }
        .listStyle(.plain)
    }

    private func cinemaDetail(_ cinema: Cinema) -> some View {
        let detailViewModel = CinemaDetailViewModel(
            cinema: cinema, userLocation: viewModel.userLocation, findRoute: findRoute)
        return CinemaDetailView(viewModel: detailViewModel)
    }

    @ToolbarContentBuilder
    private var doneButton: some ToolbarContent {
        if placement == .sheet {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func scrollList(_ listScroller: ScrollViewProxy, to cinemaId: String) {
        if cinemaId != noCinemaSelected {
            withAnimation { listScroller.scrollTo(cinemaId) }
        }
    }

    /// A tapped row selects its cinema and moves the map to it, at the same zoom.
    /// A tap on the selected row clears the selection.
    private func selectRow(_ cinema: Cinema) {
        viewModel.toggleCinema(cinema.id)
        if viewModel.selectedCinemaId != cinema.id {
            return
        }
        let region = regionMoved(viewModel.visibleRegion, to: cinemaCoordinate(cinema))
        withAnimation { cameraPosition = .region(region) }
    }
}

/// The cinemas as pins, and the user's location as a blue dot.
private struct CinemaMap: View {
    let cinemas: [Cinema]
    @Binding var cameraPosition: MapCameraPosition
    @Binding var selectedCinemaId: String?
    let cameraChanged: (MKCoordinateRegion) -> Void

    var body: some View {
        Map(position: $cameraPosition, selection: $selectedCinemaId) {
            UserAnnotation()
            ForEach(cinemas) { cinema in cinemaMarker(cinema) }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange { context in cameraChanged(context.region) }
    }

    private func cinemaMarker(_ cinema: Cinema) -> some MapContent {
        Marker(cinema.name, systemImage: symbolNameCinema, coordinate: cinemaCoordinate(cinema))
            .tag(cinema.id)
    }
}

/// A gray line under the map when the app has no location.
private struct LocationOffLine: View {
    var body: some View {
        Label("Turn on location to see distances and routes.", systemImage: symbolNameLocationOff)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, spacingSmall)
            .background(.quaternary)
    }
}

/// Name, address and distance. Tapping the row selects the cinema,
/// the info button opens the cinema's screen.
private struct CinemaRow: View {
    let cinema: Cinema
    let isSelected: Bool
    let select: () -> Void
    let showDetails: () -> Void

    var body: some View {
        HStack(spacing: spacingMedium) {
            Button(action: select) {
                description
            }
            .buttonStyle(.plain)
            Button("Details", systemImage: symbolNameDetails, action: showDetails)
                .labelStyle(.iconOnly)
                .font(.title3)
                .buttonStyle(.borderless)
        }
        .listRowBackground(isSelected ? Color.accentColor.opacity(selectedRowOpacity) : nil)
    }

    private var description: some View {
        HStack(spacing: spacingSmall) {
            nameAndAddress
            Spacer()
            Text(formattedDistance(cinema.distanceInMeters))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
    }

    private var nameAndAddress: some View {
        VStack(alignment: .leading, spacing: spacingTiny) {
            Text(cinema.name)
                .font(.headline)
            Text(cinema.address)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    CinemaMapView(
        viewModel: CinemaMapViewModel(
            cinemas: wroclawCinemas,
            findUserLocation: findUserLocation,
            lastKnownLocation: lastKnownUserLocation
        ),
        findRoute: findMapKitRoute,
        placement: .sheet
    )
}
