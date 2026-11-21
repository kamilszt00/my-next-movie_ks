import CoreLocation

/// How long the app waits for a fresh location before it gives up.
private let locationTimeout: Duration = .seconds(10)

/// A fresh location. `fallbackUserLocation` when the user says no,
/// or when no location comes within `locationTimeout`.
nonisolated func findUserLocation() async -> UserLocation {
    // Two tasks race: the first one to finish wins, the other one is cancelled.
    return await withTaskGroup(of: UserLocation.self) { group in
        group.addTask {
            return await waitForLiveLocation()
        }
        group.addTask {
            try? await Task.sleep(for: locationTimeout)
            return fallbackUserLocation
        }
        let firstLocation = await group.next() ?? fallbackUserLocation
        group.cancelAll()
        return firstLocation
    }
}

/// The location iOS remembers from before, at once. `fallbackUserLocation` when there is none.
func lastKnownUserLocation() -> UserLocation {
    guard let location = CLLocationManager().location else {
        return fallbackUserLocation
    }
    return userLocationFrom(location)
}

nonisolated private func waitForLiveLocation() async -> UserLocation {
    // The session asks for permission and keeps it while the app looks for the location.
    let session = CLServiceSession(authorization: .whenInUse)
    defer { session.invalidate() }
    do {
        for try await update in CLLocationUpdate.liveUpdates() {
            if let location = update.location {
                return userLocationFrom(location)
            }
            if update.authorizationDenied || update.authorizationDeniedGlobally {
                return fallbackUserLocation
            }
        }
    } catch {
        return fallbackUserLocation
    }
    return fallbackUserLocation
}

nonisolated private func userLocationFrom(_ location: CLLocation) -> UserLocation {
    return UserLocation(
        latitude: location.coordinate.latitude,
        longitude: location.coordinate.longitude,
        isKnown: true
    )
}
