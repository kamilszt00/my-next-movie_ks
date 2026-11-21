import CoreLocation
import MapKit
import Testing

@testable import MyNextMovie

@MainActor
struct CinemaTests {
    @Test func sortsCinemasClosestFirst() {
        let sorted = cinemasSortedByDistance(testCinemas, from: testUserLocation)

        #expect(
            namesOf(sorted) == [
                "DCF", "Kino Nowe Horyzonty", "Multikino Pasaż Grunwaldzki", "Helios Magnolia",
            ])
    }

    @Test func measuresDistanceOfEveryCinema() {
        let sorted = cinemasSortedByDistance(testCinemas, from: testUserLocation)

        for cinema in sorted {
            #expect(cinema.distanceInMeters > 0)
        }
        // DCF is under a kilometer from the station.
        #expect(sorted[0].distanceInMeters < 1000)
    }

    @Test func sortsCinemasAtTheSameDistanceByName() {
        let zeta = Cinema(
            id: "zeta", name: "Zeta", address: "", phoneNumber: "", website: "",
            latitude: 51.1, longitude: 17.03)
        let alpha = Cinema(
            id: "alpha", name: "Alpha", address: "", phoneNumber: "", website: "",
            latitude: 51.1, longitude: 17.03)

        let sorted = cinemasSortedByDistance([zeta, alpha], from: testUserLocation)

        #expect(namesOf(sorted) == ["Alpha", "Zeta"])
    }

    @Test func findsPositionOfCinema() {
        #expect(positionOfCinema(testCinemas, cinemaId: "dcf") == 2)
        #expect(positionOfCinema(testCinemas, cinemaId: "nowhere") == cinemaNotFound)
        #expect(containsCinema(testCinemas, cinemaId: "helios-magnolia"))
        #expect(!containsCinema(testCinemas, cinemaId: "nowhere"))
    }

    @Test func unknownDistanceIsEmptyText() {
        #expect(formattedDistance(unknownDistance) == "")
    }

    @Test func formatsMetersAndKilometers() {
        #expect(formattedDistance(850) == "850 m")
        #expect(formattedDistance(2437) == "2.4 km")
    }

    @Test func phoneLinkHasOnlyDigits() {
        #expect(phoneURL(testCinemaNoweHoryzonty)?.absoluteString == "tel:+48717864566")
        #expect(hasPhoneNumber(testCinemaNoweHoryzonty))
    }

    @Test func noPhoneOrWebsiteMeansNoLink() {
        #expect(phoneURL(testCinemaDCF) == nil)
        #expect(websiteURL(testCinemaDCF) == nil)
        #expect(!hasPhoneNumber(testCinemaDCF))
        #expect(!hasWebsite(testCinemaDCF))
    }
}

@MainActor
struct WroclawCinemasTests {
    @Test func everyCinemaIsOnTheStartMap() {
        for cinema in wroclawCinemas {
            #expect(isInRegion(cinemaCoordinate(cinema), wroclawMapRegion), "\(cinema.name)")
        }
    }

    @Test func idsAreUnique() {
        var ids = Set<String>()
        for cinema in wroclawCinemas {
            ids.insert(cinema.id)
        }

        #expect(ids.count == wroclawCinemas.count)
    }

    @Test func everyCinemaHasAddressAndWebsite() {
        for cinema in wroclawCinemas {
            #expect(!cinema.address.isEmpty, "\(cinema.name)")
            #expect(websiteURL(cinema) != nil, "\(cinema.name)")
        }
    }

    @Test func pointOutsideRegionIsNotOnTheMap() {
        let warsaw = CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122)

        #expect(!isInRegion(warsaw, wroclawMapRegion))
    }
}

@MainActor
struct MapKitConversionTests {
    @Test func mapItemForCinemaKeepsNameAndPosition() {
        let mapItem = mapItemForCinema(testCinemaDCF)

        #expect(mapItem.name == testCinemaDCF.name)
        #expect(mapItem.location.coordinate.latitude == testCinemaDCF.latitude)
        #expect(mapItem.location.coordinate.longitude == testCinemaDCF.longitude)
    }

    @Test func travelModeBecomesMapKitTransportType() {
        #expect(transportTypeForMapKit(.walking) == .walking)
        #expect(transportTypeForMapKit(.driving) == .automobile)
    }
}
