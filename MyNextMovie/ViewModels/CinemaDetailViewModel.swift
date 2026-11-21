import MapKit
import Observation

private let secondsPerMinute: TimeInterval = 60

/// The screen of one cinema, with the way there.
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

    /// A route needs the place where the user is.
    var canFindRoute: Bool {
        return userLocation.isKnown
    }

    func loadRoute() async {
        if !canFindRoute {
            return
        }
        routeState = .loading
        do {
            route = try await findRoute(userLocation, cinema, travelMode)
            routeState = .loaded
        } catch {
            route = noRoute
            errorMessage = error.localizedDescription
            routeState = .failed
        }
    }
}

/// 720 seconds -> "12 min". At least one minute.
func formattedTravelTime(_ travelTime: TimeInterval) -> String {
    let minutes = max(1, Int((travelTime / secondsPerMinute).rounded()))
    return "\(minutes) min"
}

/// "12 min · 950 m"
func routeSummary(_ route: CinemaRoute) -> String {
    return formattedTravelTime(route.travelTime) + textSeparator
        + formattedDistance(route.distanceInMeters)
}
