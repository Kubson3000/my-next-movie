import CoreLocation

/// How long to wait for a fresh location before giving up.
private let locationTimeout = Duration.seconds(10)

/// A fresh location of the user. `fallbackUserLocation` when the user does not allow it,
/// or when no location comes in `locationTimeout`. Has the type `UserLocationFinder`.
func findUserLocation() async -> UserLocation {
    let firstResult = await withTaskGroup(of: UserLocation.self) { group in
        group.addTask { await locationFromLiveUpdates() }
        group.addTask { await fallbackAfterTimeout() }
        let first = await group.next()
        // The loser stops: the location updates or the sleep end on cancellation.
        group.cancelAll()
        return first
    }
    return firstResult ?? fallbackUserLocation
}

/// The last location the phone knows, at once, without asking for a new one.
/// `fallbackUserLocation` when there is none. Has the type `LastKnownLocationReader`.
func lastKnownUserLocation() -> UserLocation {
    if let location = CLLocationManager().location {
        return knownUserLocation(location)
    }
    return fallbackUserLocation
}

/// The first location from Core Location. Asks the user for permission the first time.
private func locationFromLiveUpdates() async -> UserLocation {
    let session = CLServiceSession(authorization: .whenInUse)
    defer { session.invalidate() }
    do {
        for try await update in CLLocationUpdate.liveUpdates() {
            if isLocationRefused(update) {
                return fallbackUserLocation
            }
            if let location = update.location {
                return knownUserLocation(location)
            }
        }
    } catch {
        // The updates failed or were cancelled. Both mean no location.
    }
    return fallbackUserLocation
}

/// The user said no, location is off for every app, or the phone does not allow it.
private func isLocationRefused(_ update: CLLocationUpdate) -> Bool {
    return update.authorizationDenied || update.authorizationDeniedGlobally
        || update.authorizationRestricted
}

private func fallbackAfterTimeout() async -> UserLocation {
    try? await Task.sleep(for: locationTimeout)
    return fallbackUserLocation
}

private func knownUserLocation(_ location: CLLocation) -> UserLocation {
    return UserLocation(
        latitude: location.coordinate.latitude,
        longitude: location.coordinate.longitude,
        isKnown: true)
}
