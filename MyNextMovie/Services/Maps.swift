import MapKit

typealias UserLocationFinder = () async -> UserLocation
typealias LastKnownLocationReader = () -> UserLocation

enum TravelMode {
    case walking
    case driving
}

typealias CinemaRouteFinder = (UserLocation, Cinema, TravelMode) async throws -> CinemaRoute

/// The way from the user to a cinema, a plain struct so the views do not depend on `MKRoute`.
struct CinemaRoute {
    let line: MKPolyline
    let distanceInMeters: CLLocationDistance
    let travelTime: TimeInterval
}

/// Shown before the route arrives.
let noRoute = CinemaRoute(line: MKPolyline(), distanceInMeters: 0, travelTime: 0)

struct NoRouteFound: LocalizedError {
    var errorDescription: String? { return "Maps found no way to this cinema." }
}

/// The first route Apple Maps finds from the user to the cinema.
func findMapKitRoute(
    userLocation: UserLocation,
    cinema: Cinema,
    travelMode: TravelMode
) async throws -> CinemaRoute {
    let request = MKDirections.Request()
    let start = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
    request.source = MKMapItem(location: start, address: nil)
    request.destination = mapItemForCinema(cinema)
    request.transportType = transportTypeForMapKit(travelMode)

    let response = try await MKDirections(request: request).calculate()
    guard let route = response.routes.first else {
        throw NoRouteFound()
    }
    return CinemaRoute(
        line: route.polyline,
        distanceInMeters: route.distance,
        travelTime: route.expectedTravelTime
    )
}

func mapItemForCinema(_ cinema: Cinema) -> MKMapItem {
    let location = CLLocation(latitude: cinema.latitude, longitude: cinema.longitude)
    let address = MKAddress(fullAddress: cinema.address, shortAddress: nil)
    let mapItem = MKMapItem(location: location, address: address)
    mapItem.name = cinema.name
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

/// Opens Apple Maps with directions to the cinema.
func openCinemaInMaps(_ cinema: Cinema, travelMode: TravelMode) {
    let directionsMode =
        travelMode == .walking
        ? MKLaunchOptionsDirectionsModeWalking : MKLaunchOptionsDirectionsModeDriving
    mapItemForCinema(cinema).openInMaps(launchOptions: [
        MKLaunchOptionsDirectionsModeKey: directionsMode
    ])
}

/// Street-level photos around the cinema, nil when Apple has none there.
func findLookAroundScene(_ cinema: Cinema) async -> MKLookAroundScene? {
    let request = MKLookAroundSceneRequest(coordinate: cinemaCoordinate(cinema))
    return try? await request.scene
}
