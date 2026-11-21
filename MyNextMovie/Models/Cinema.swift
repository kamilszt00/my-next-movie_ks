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

// MARK: - Constants

nonisolated let noCinemaSelected = ""
nonisolated let cinemaNotFound = -1

/// Rynek, the market square, used when the app does not know where the user is.
nonisolated let fallbackCoordinate = CLLocationCoordinate2D(latitude: 51.1100, longitude: 17.0320)
nonisolated let fallbackUserLocation = UserLocation(
    latitude: fallbackCoordinate.latitude,
    longitude: fallbackCoordinate.longitude,
    isKnown: false
)

private let metersPerKilometer: CLLocationDistance = 1000
/// One digit after the decimal point: 2437 m -> "2.4 km".
private let kilometersFormat = "%.1f km"
private let phoneURLScheme = "tel:"
private let phoneNumberSymbols = "+0123456789"

// MARK: - Positions and distances

func cinemaCoordinate(_ cinema: Cinema) -> CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: cinema.latitude, longitude: cinema.longitude)
}

func userCoordinate(_ userLocation: UserLocation) -> CLLocationCoordinate2D {
    return CLLocationCoordinate2D(
        latitude: userLocation.latitude, longitude: userLocation.longitude)
}

/// Distance in a straight line, in meters.
func distanceInMeters(
    from start: CLLocationCoordinate2D,
    to end: CLLocationCoordinate2D
) -> CLLocationDistance {
    let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
    let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
    return startLocation.distance(from: endLocation)
}

/// The cinemas with their distance from the user, closest first.
func cinemasSortedByDistance(_ cinemas: [Cinema], from userLocation: UserLocation) -> [Cinema] {
    let start = userCoordinate(userLocation)
    var measuredCinemas: [Cinema] = []
    for cinema in cinemas {
        var measuredCinema = cinema
        measuredCinema.distanceInMeters = distanceInMeters(
            from: start, to: cinemaCoordinate(cinema))
        measuredCinemas.append(measuredCinema)
    }
    return measuredCinemas.sorted(by: isCloser)
}

/// Closer first. Cinemas at the same distance go by name.
func isCloser(_ first: Cinema, _ second: Cinema) -> Bool {
    if first.distanceInMeters != second.distanceInMeters {
        return first.distanceInMeters < second.distanceInMeters
    }
    return first.name < second.name
}

/// Index of the cinema in the list, `cinemaNotFound` when it is not there.
func positionOfCinema(_ cinemas: [Cinema], cinemaId: String) -> Int {
    for (index, cinema) in cinemas.enumerated() where cinema.id == cinemaId {
        return index
    }
    return cinemaNotFound
}

func containsCinema(_ cinemas: [Cinema], cinemaId: String) -> Bool {
    return positionOfCinema(cinemas, cinemaId: cinemaId) != cinemaNotFound
}

/// 850 -> "850 m", 2437 -> "2.4 km", `unknownDistance` -> "".
func formattedDistance(_ distanceInMeters: CLLocationDistance) -> String {
    if distanceInMeters < 0 {
        return ""
    }
    if distanceInMeters < metersPerKilometer {
        return "\(Int(distanceInMeters.rounded())) m"
    }
    return String(format: kilometersFormat, distanceInMeters / metersPerKilometer)
}

// MARK: - Links

/// "tel:+48717864566" for "+48 71 786 45 66", nil when the number is unknown.
func phoneURL(_ cinema: Cinema) -> URL? {
    if !hasPhoneNumber(cinema) {
        return nil
    }
    let symbols = cinema.phoneNumber.filter { character in phoneNumberSymbols.contains(character) }
    return URL(string: phoneURLScheme + symbols)
}

func hasPhoneNumber(_ cinema: Cinema) -> Bool {
    return !cinema.phoneNumber.isEmpty
}

func websiteURL(_ cinema: Cinema) -> URL? {
    if !hasWebsite(cinema) {
        return nil
    }
    return URL(string: cinema.website)
}

func hasWebsite(_ cinema: Cinema) -> Bool {
    return !cinema.website.isEmpty
}
