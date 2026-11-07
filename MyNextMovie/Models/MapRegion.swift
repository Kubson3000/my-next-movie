import MapKit

/// The area of Wrocław where every cinema is on the map.
let wroclawMapRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(
        latitude: 51.0956, longitude: 17.0230),
    latitudinalMeters: 15500,
    longitudinalMeters: 14000)

/// The region of the same size with the center moved to `center`.
func regionMoved(_ region: MKCoordinateRegion, to center: CLLocationCoordinate2D)
    -> MKCoordinateRegion
{
    return MKCoordinateRegion(center: center, span: region.span)
}

/// Whether the point is inside the region, on its edge too.
func isInRegion(_ coordinate: CLLocationCoordinate2D, _ region: MKCoordinateRegion) -> Bool {
    let latitudeFromCenter = abs(coordinate.latitude - region.center.latitude)
    let longitudeFromCenter = abs(coordinate.longitude - region.center.longitude)
    return latitudeFromCenter <= region.span.latitudeDelta / 2
        && longitudeFromCenter <= region.span.longitudeDelta / 2
}
