import MapKit

/// The part of Wrocław where every cinema is on the map.
let wroclawMapRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 51.0956, longitude: 17.0230),
    latitudinalMeters: 15500,
    longitudinalMeters: 14000
)

/// The same size of region, with a new center.
func regionMoved(_ region: MKCoordinateRegion, to center: CLLocationCoordinate2D)
    -> MKCoordinateRegion
{
    return MKCoordinateRegion(center: center, span: region.span)
}

func isInRegion(_ coordinate: CLLocationCoordinate2D, _ region: MKCoordinateRegion) -> Bool {
    let halfHeight = region.span.latitudeDelta / 2
    let halfWidth = region.span.longitudeDelta / 2
    let isInLatitude = abs(coordinate.latitude - region.center.latitude) <= halfHeight
    let isInLongitude = abs(coordinate.longitude - region.center.longitude) <= halfWidth
    return isInLatitude && isInLongitude
}
