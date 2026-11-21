import MapKit
import Observation

/// The Cinemas tab: every cinema, nearest first once the app knows where the user is.
@Observable
final class CinemaMapViewModel {
    private(set) var cinemas: [Cinema]
    private(set) var userLocation = fallbackUserLocation
    /// Set by the map too, when the user taps a pin.
    var selectedCinemaId = noCinemaSelected
    private(set) var isLocating = false
    var visibleRegion = wroclawMapRegion

    private var hasAskedForLocation = false
    private let findUserLocation: UserLocationFinder
    private let lastKnownLocation: LastKnownLocationReader

    init(
        cinemas: [Cinema],
        findUserLocation: @escaping UserLocationFinder,
        lastKnownLocation: @escaping LastKnownLocationReader = { fallbackUserLocation }
    ) {
        // By name until the app knows where the user is.
        self.cinemas = cinemas.sorted { first, second in first.name < second.name }
        self.findUserLocation = findUserLocation
        self.lastKnownLocation = lastKnownLocation
    }

    /// The app asked for the location, but has none.
    var isLocationUnavailable: Bool {
        return hasAskedForLocation && !isLocating && !userLocation.isKnown
    }

    /// Sorts by the last known location at once, then by a fresh one when it comes.
    func locateUser() async {
        hasAskedForLocation = true
        isLocating = true
        show(lastKnownLocation())
        show(await findUserLocation())
        isLocating = false
    }

    func locateUserIfNeeded() async {
        if !hasAskedForLocation {
            await locateUser()
        }
    }

    /// Selects the cinema, or clears the selection when it is already selected.
    func toggleCinema(_ cinemaId: String) {
        if selectedCinemaId == cinemaId {
            selectedCinemaId = noCinemaSelected
        } else {
            selectedCinemaId = cinemaId
        }
    }

    /// An unknown location never replaces a known one.
    private func show(_ location: UserLocation) {
        if !location.isKnown {
            return
        }
        userLocation = location
        cinemas = cinemasSortedByDistance(cinemas, from: location)
    }
}
