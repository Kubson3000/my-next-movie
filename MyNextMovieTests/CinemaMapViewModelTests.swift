import MapKit
import Testing

@testable import MyNextMovie

/// Near Helios Magnolia, in the west of the city, far from the station.
private let westOfCityLocation = UserLocation(latitude: 51.1190, longitude: 16.9900, isKnown: true)

/// A walk of 12 minutes and 950 meters.
@MainActor private let testRoute = CinemaRoute(
    line: MKPolyline(), distanceInMeters: 950, travelTime: 720)

@MainActor
struct CinemaMapViewModelTests {
    @Test func showsCinemasAtOnceByName() {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: { testUserLocation })

        #expect(
            namesOf(viewModel.cinemas) == [
                "DCF", "Helios Magnolia", "Kino Nowe Horyzonty", "Multikino Pasaż Grunwaldzki",
            ])
        #expect(!viewModel.userLocation.isKnown)
    }

    @Test func sortsByDistanceOnceUserIsFound() async {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: { testUserLocation })

        await viewModel.locateUser()

        #expect(viewModel.cinemas.first?.name == "DCF")
        #expect(viewModel.userLocation == testUserLocation)
        #expect(!viewModel.isLocating)
    }

    @Test func lastKnownLocationIsUsedWhenNoFreshOneComes() async {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: { fallbackUserLocation },
            lastKnownLocation: { testUserLocation }
        )

        await viewModel.locateUser()

        #expect(viewModel.userLocation == testUserLocation)
        #expect(viewModel.cinemas.first?.name == "DCF")
        #expect(!viewModel.isLocationUnavailable)
    }

    @Test func freshLocationReplacesLastKnownOne() async {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: { testUserLocation },
            lastKnownLocation: { westOfCityLocation }
        )

        await viewModel.locateUser()

        #expect(viewModel.userLocation == testUserLocation)
        #expect(viewModel.cinemas.first?.name == "DCF")
    }

    @Test func saysWhenLocationIsUnavailable() async {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: { fallbackUserLocation })
        #expect(!viewModel.isLocationUnavailable)

        await viewModel.locateUser()

        #expect(viewModel.isLocationUnavailable)
        #expect(namesOf(viewModel.cinemas).first == "DCF")
        #expect(viewModel.cinemas.first?.distanceInMeters == unknownDistance)
    }

    @Test func asksForLocationOnlyOnce() async {
        var askCount = 0
        let findUserLocation: UserLocationFinder = {
            askCount += 1
            return testUserLocation
        }
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: findUserLocation)

        await viewModel.locateUserIfNeeded()
        await viewModel.locateUserIfNeeded()

        #expect(askCount == 1)
    }

    @Test func togglesSelection() {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: { testUserLocation })

        viewModel.toggleCinema(testCinemaDCF.id)
        #expect(viewModel.selectedCinemaId == testCinemaDCF.id)

        viewModel.toggleCinema(testCinemaHelios.id)
        #expect(viewModel.selectedCinemaId == testCinemaHelios.id)

        viewModel.toggleCinema(testCinemaHelios.id)
        #expect(viewModel.selectedCinemaId == noCinemaSelected)
    }

    @Test func mapSelectionIsNilWithoutSelectedCinema() {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: { testUserLocation })
        #expect(viewModel.selectedCinemaIdOrNil == nil)

        viewModel.selectedCinemaIdOrNil = testCinemaDCF.id
        #expect(viewModel.selectedCinemaId == testCinemaDCF.id)

        viewModel.selectedCinemaIdOrNil = nil
        #expect(viewModel.selectedCinemaId == noCinemaSelected)
    }
}

@MainActor
struct CinemaDetailViewModelTests {
    @Test func findsNoRouteWithoutLocation() async {
        var requestCount = 0
        let findRoute: CinemaRouteFinder = { _, _, _ in
            requestCount += 1
            return testRoute
        }
        let viewModel = CinemaDetailViewModel(
            cinema: testCinemaDCF, userLocation: fallbackUserLocation, findRoute: findRoute)

        await viewModel.loadRoute()

        #expect(!viewModel.canFindRoute)
        #expect(requestCount == 0)
        #expect(viewModel.routeState == .idle)
    }

    @Test func findsRouteForSelectedTravelMode() async {
        var requestedTravelMode = TravelMode.walking
        var requestedCinemaId = ""
        let findRoute: CinemaRouteFinder = { _, cinema, travelMode in
            requestedTravelMode = travelMode
            requestedCinemaId = cinema.id
            return testRoute
        }
        let viewModel = CinemaDetailViewModel(
            cinema: testCinemaDCF, userLocation: testUserLocation, findRoute: findRoute)
        viewModel.travelMode = .driving

        await viewModel.loadRoute()

        #expect(requestedTravelMode == .driving)
        #expect(requestedCinemaId == testCinemaDCF.id)
        #expect(viewModel.routeState == .loaded)
        #expect(viewModel.route.distanceInMeters == testRoute.distanceInMeters)
    }

    @Test func showsErrorWhenRouteFails() async {
        let viewModel = CinemaDetailViewModel(
            cinema: testCinemaDCF,
            userLocation: testUserLocation,
            findRoute: { _, _, _ in throw NoRouteFound() }
        )

        await viewModel.loadRoute()

        #expect(viewModel.routeState == .failed)
        #expect(viewModel.errorMessage == "Maps found no way to this cinema.")
    }

    @Test func routeSummaryHasTimeAndDistance() {
        #expect(routeSummary(testRoute) == "12 min · 950 m")
        #expect(formattedTravelTime(4500) == "1 h 15 min")
    }
}
