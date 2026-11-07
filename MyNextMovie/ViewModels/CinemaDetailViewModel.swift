import Foundation
import Observation

private let secondsPerMinute: TimeInterval = 60
private let minutesPerHour = 60
private let minutesSuffix = "min"
private let hoursSuffix = "h"

/// A cinema's screen: the way there on foot or by car.
/// A class only because SwiftUI's @Observable requires one.
@Observable
final class CinemaDetailViewModel {
    let cinema: Cinema
    let userLocation: UserLocation
    var travelMode = TravelMode.walking
    private(set) var routeState = LoadState.idle
    private(set) var route = noRoute
    private(set) var errorMessage = ""

    private let findRoute: CinemaRouteFinder

    init(cinema: Cinema, userLocation: UserLocation, findRoute: @escaping CinemaRouteFinder) {
        self.cinema = cinema
        self.userLocation = userLocation
        self.findRoute = findRoute
    }

    /// A route needs a start, so the user's location must be known.
    var canFindRoute: Bool {
        return userLocation.isKnown
    }

    /// Finds the way for the selected travel mode. Does nothing without the user's location.
    func loadRoute() async {
        if !canFindRoute {
            return
        }
        routeState = .loading
        do {
            let foundRoute = try await findRoute(userLocation, cinema, travelMode)
            if Task.isCancelled {
                // The user changed the travel mode. The newer request sets the route.
                return
            }
            route = foundRoute
            routeState = .loaded
        } catch {
            if Task.isCancelled {
                return
            }
            route = noRoute
            errorMessage = error.localizedDescription
            routeState = .failed
        }
    }
}

/// 720 -> "12 min", 4500 -> "1 h 15 min". At least "1 min".
func formattedTravelTime(_ travelTime: TimeInterval) -> String {
    let minutes = max(1, Int((travelTime / secondsPerMinute).rounded()))
    if minutes < minutesPerHour {
        return String(minutes) + " " + minutesSuffix
    }
    let hours = String(minutes / minutesPerHour) + " " + hoursSuffix
    return hours + " " + String(minutes % minutesPerHour) + " " + minutesSuffix
}

/// "12 min · 950 m"
func routeSummary(_ route: CinemaRoute) -> String {
    return formattedTravelTime(route.travelTime) + textSeparator
        + formattedDistance(route.distanceInMeters)
}
