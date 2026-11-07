import Foundation
import MapKit

/// Any function that finds where the user is now. The app passes `findUserLocation`,
/// tests pass a closure with a location written out.
typealias UserLocationFinder = () async -> UserLocation

/// Any function that returns the last known location at once.
typealias LastKnownLocationReader = () -> UserLocation

nonisolated enum TravelMode {
    case walking
    case driving
}

/// Any function that finds the way from the user to the cinema.
typealias CinemaRouteFinder = (UserLocation, Cinema, TravelMode) async throws -> CinemaRoute

/// The way to a cinema: the line on the map, its length and how long it takes.
struct CinemaRoute {
    let line: MKPolyline
    let distanceInMeters: CLLocationDistance
    let travelTime: TimeInterval
}

/// Shown until a route loads.
let noRoute = CinemaRoute(line: MKPolyline(), distanceInMeters: 0, travelTime: 0)

struct NoRouteFound: LocalizedError {
    var errorDescription: String? { "Maps found no way to this cinema." }
}

/// The first route Apple Maps finds. Has the type `CinemaRouteFinder`.
func findMapKitRoute(userLocation: UserLocation, cinema: Cinema, travelMode: TravelMode)
    async throws -> CinemaRoute
{
    let request = MKDirections.Request()
    request.source = MKMapItem(
        location: CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude),
        address: nil)
    request.destination = mapItemForCinema(cinema)
    request.transportType = transportTypeForMapKit(travelMode)
    let response = try await MKDirections(request: request).calculate()
    guard let route = response.routes.first else {
        throw NoRouteFound()
    }
    return CinemaRoute(
        line: route.polyline,
        distanceInMeters: route.distance,
        travelTime: route.expectedTravelTime)
}

/// The cinema as a place in MapKit, with its name, address, phone number and website.
/// A new item each time, so `sending` lets the caller pass it on to MapKit's requests,
/// which run off the main actor.
func mapItemForCinema(_ cinema: Cinema) -> sending MKMapItem {
    let location = CLLocation(latitude: cinema.latitude, longitude: cinema.longitude)
    // nil when MapKit cannot read the address, e.g. an empty one.
    let address = MKAddress(fullAddress: cinema.address, shortAddress: nil)
    let mapItem = MKMapItem(location: location, address: address)
    mapItem.name = cinema.name
    if !cinema.phoneNumber.isEmpty {
        mapItem.phoneNumber = cinema.phoneNumber
    }
    mapItem.url = websiteURL(cinema)
    return mapItem
}

func transportTypeForMapKit(_ travelMode: TravelMode) -> MKDirectionsTransportType {
    switch travelMode {
    case .walking:
        return .walking
    case .driving:
        return .automobile
    }
}

/// Opens Apple Maps with the way from the user to the cinema.
func openCinemaInMaps(_ cinema: Cinema, travelMode: TravelMode) {
    let launchOptions = [MKLaunchOptionsDirectionsModeKey: directionsModeForMaps(travelMode)]
    mapItemForCinema(cinema).openInMaps(launchOptions: launchOptions)
}

private func directionsModeForMaps(_ travelMode: TravelMode) -> String {
    switch travelMode {
    case .walking:
        return MKLaunchOptionsDirectionsModeWalking
    case .driving:
        return MKLaunchOptionsDirectionsModeDriving
    }
}

/// Street-level photos of the cinema's street, nil when Apple has none there.
/// MapKit's scenes are not Sendable, so the request runs off the main actor and
/// `sending` hands the new scene over to the caller.
@concurrent
nonisolated func findLookAroundScene(_ cinema: Cinema) async -> sending MKLookAroundScene? {
    let coordinate = CLLocationCoordinate2D(latitude: cinema.latitude, longitude: cinema.longitude)
    let request = MKLookAroundSceneRequest(coordinate: coordinate)
    return try? await request.scene
}
