import CoreLocation
import Foundation

// Lab 6: the data types of the Cinemas tab are ready.
// Write the other constants and the functions from task 1 in this file.

/// Distance of a cinema before the app knows where the user is.
nonisolated let unknownDistance: CLLocationDistance = -1

/// A cinema in Wrocław, a plain struct,
/// so the views and tests do not depend on `MKMapItem`.
nonisolated struct Cinema: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String  // empty when unknown
    let phoneNumber: String  // empty when unknown
    let website: String  // empty when unknown
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    var distanceInMeters = unknownDistance
}

/// Where the user is. `isKnown` is false when the app does not know it.
nonisolated struct UserLocation: Equatable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let isKnown: Bool
}

/// `CinemaMapViewModel.selectedCinemaId` when no cinema is selected.
let noCinemaSelected = ""

/// `positionOfCinema` when the list has no cinema with the id.
let cinemaNotFound = -1

/// Distances under this many meters are in meters, longer ones in kilometers.
private let metersPerKilometer: CLLocationDistance = 1000
private let kilometersFormat = "%.1f"
private let metersSuffix = "m"
private let kilometersSuffix = "km"

private let phoneURLScheme = "tel:"
/// The only characters a `tel:` link keeps from "+48 71 796 34 87".
private let phoneNumberCharacters = "+0123456789"

/// The market square (Rynek), used when the user's location is unknown.
let fallbackCoordinate = CLLocationCoordinate2D(
    latitude: 51.1100, longitude: 17.0320)
let fallbackUserLocation = UserLocation(
    latitude: fallbackCoordinate.latitude,
    longitude: fallbackCoordinate.longitude,
    isKnown: false)

func cinemaCoordinate(_ cinema: Cinema) -> CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: cinema.latitude, longitude: cinema.longitude)
}

func userCoordinate(_ userLocation: UserLocation) -> CLLocationCoordinate2D {
    return CLLocationCoordinate2D(
        latitude: userLocation.latitude, longitude: userLocation.longitude)
}

/// Distance in a straight line, not along the streets.
func distanceInMeters(from userLocation: UserLocation, to cinema: Cinema) -> CLLocationDistance {
    let user = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
    let cinemaLocation = CLLocation(latitude: cinema.latitude, longitude: cinema.longitude)
    return user.distance(from: cinemaLocation)
}

/// The cinemas with their distance from the user, the closest first.
func cinemasSortedByDistance(_ cinemas: [Cinema], from userLocation: UserLocation) -> [Cinema] {
    var measuredCinemas: [Cinema] = []
    for cinema in cinemas {
        var measuredCinema = cinema
        measuredCinema.distanceInMeters = distanceInMeters(from: userLocation, to: cinema)
        measuredCinemas.append(measuredCinema)
    }
    return measuredCinemas.sorted(by: isCloser)
}

/// Whether `first` goes before `second`: the closer one first, by name at the same distance.
/// Before the distances are known they are all `unknownDistance`, so the cinemas go by name.
func isCloser(_ first: Cinema, _ second: Cinema) -> Bool {
    if first.distanceInMeters != second.distanceInMeters {
        return first.distanceInMeters < second.distanceInMeters
    }
    return first.name < second.name
}

/// Index of the cinema with the id, `cinemaNotFound` when there is none.
func positionOfCinema(_ cinemas: [Cinema], cinemaId: String) -> Int {
    for (position, cinema) in cinemas.enumerated() {
        if cinema.id == cinemaId {
            return position
        }
    }
    return cinemaNotFound
}

func containsCinema(_ cinemas: [Cinema], cinemaId: String) -> Bool {
    return positionOfCinema(cinemas, cinemaId: cinemaId) != cinemaNotFound
}

/// 850 -> "850 m", 2430 -> "2.4 km", "" for `unknownDistance`.
func formattedDistance(_ distance: CLLocationDistance) -> String {
    if distance < 0 {
        return ""
    }
    if distance < metersPerKilometer {
        return String(Int(distance.rounded())) + " " + metersSuffix
    }
    let kilometers = String(format: kilometersFormat, distance / metersPerKilometer)
    return kilometers + " " + kilometersSuffix
}

/// "+48 71 796 34 87" -> "tel:+48717963487", nil when the cinema has no phone number.
func phoneURL(_ cinema: Cinema) -> URL? {
    var dialedCharacters = ""
    for character in cinema.phoneNumber where phoneNumberCharacters.contains(character) {
        dialedCharacters.append(character)
    }
    if dialedCharacters.isEmpty {
        return nil
    }
    return URL(string: phoneURLScheme + dialedCharacters)
}

func hasPhoneNumber(_ cinema: Cinema) -> Bool {
    return phoneURL(cinema) != nil
}

/// The cinema's website, nil when it has none.
func websiteURL(_ cinema: Cinema) -> URL? {
    if cinema.website.isEmpty {
        return nil
    }
    return URL(string: cinema.website)
}

func hasWebsite(_ cinema: Cinema) -> Bool {
    return websiteURL(cinema) != nil
}
