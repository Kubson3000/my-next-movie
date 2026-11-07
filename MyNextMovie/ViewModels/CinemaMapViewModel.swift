import Foundation
import MapKit
import Observation

/// The Cinemas tab: the cinemas, the closest first once the user's location is known.
/// A class only because SwiftUI's @Observable requires one.
@Observable
final class CinemaMapViewModel {
    private(set) var cinemas: [Cinema]
    private(set) var userLocation = fallbackUserLocation
    var selectedCinemaId = noCinemaSelected
    private(set) var isLocating = false
    /// The part of the map on screen. The view keeps it up to date.
    var visibleRegion = wroclawMapRegion

    private let findUserLocation: UserLocationFinder
    private let lastKnownLocation: LastKnownLocationReader
    private var hasAskedForLocation = false

    /// Shows the cinemas at once, by name, before the location is known.
    init(
        cinemas: [Cinema],
        findUserLocation: @escaping UserLocationFinder,
        lastKnownLocation: @escaping LastKnownLocationReader = { fallbackUserLocation }
    ) {
        self.cinemas = cinemas.sorted(by: isCloser)
        self.findUserLocation = findUserLocation
        self.lastKnownLocation = lastKnownLocation
    }

    /// The selection as SwiftUI's Map wants it: nil when no cinema is selected.
    /// A tapped pin sets it, a tap beside the pins clears it.
    var selectedCinemaIdOrNil: String? {
        get {
            if selectedCinemaId == noCinemaSelected {
                return nil
            }
            return selectedCinemaId
        }
        set {
            selectedCinemaId = newValue ?? noCinemaSelected
        }
    }

    /// The app asked for the location and has none: the user said no, or none came in time.
    var isLocationUnavailable: Bool {
        return hasAskedForLocation && !isLocating && !userLocation.isKnown
    }

    /// Sorts the cinemas by the last known location at once, then by a fresh one.
    /// An unknown location does not replace a known one.
    func locateUser() async {
        hasAskedForLocation = true
        isLocating = true
        useLocationIfKnown(lastKnownLocation())
        let freshLocation = await findUserLocation()
        useLocationIfKnown(freshLocation)
        isLocating = false
    }

    /// Locates the user the first time the screen appears.
    func locateUserIfNeeded() async {
        if !hasAskedForLocation {
            await locateUser()
        }
    }

    /// Selects the cinema, or clears the selection when the cinema is already selected.
    func toggleCinema(_ cinemaId: String) {
        if selectedCinemaId == cinemaId || !containsCinema(cinemas, cinemaId: cinemaId) {
            selectedCinemaId = noCinemaSelected
        } else {
            selectedCinemaId = cinemaId
        }
    }

    private func useLocationIfKnown(_ location: UserLocation) {
        if !location.isKnown {
            return
        }
        userLocation = location
        cinemas = cinemasSortedByDistance(cinemas, from: location)
    }
}
