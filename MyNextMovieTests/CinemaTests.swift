import CoreLocation
import Foundation
import MapKit
import Testing

@testable import MyNextMovie

/// Kraków market square, far outside the map of Wrocław.
private let krakowCoordinate = CLLocationCoordinate2D(latitude: 50.0617, longitude: 19.9373)

@MainActor
struct CinemaTests {
    @Test func sortsCinemasClosestFirst() {
        let sortedCinemas = cinemasSortedByDistance(testCinemas, from: testUserLocation)

        #expect(
            namesOf(sortedCinemas) == [
                "DCF", "Kino Nowe Horyzonty", "Multikino Pasaż Grunwaldzki", "Helios Magnolia",
            ])
    }

    @Test func measuresDistanceOfEveryCinema() throws {
        let sortedCinemas = cinemasSortedByDistance(testCinemas, from: testUserLocation)

        for cinema in sortedCinemas {
            #expect(cinema.distanceInMeters > 0)
        }
        // DCF is about 800 m from the station in a straight line.
        let closest = try #require(sortedCinemas.first)
        #expect(closest.distanceInMeters > 700 && closest.distanceInMeters < 900)
    }

    @Test func sortsCinemasAtTheSameDistanceByName() {
        let sameBuilding = [
            makeCinemaAtDCF(id: "zebra", name: "Zebra"),
            makeCinemaAtDCF(id: "aurora", name: "Aurora"),
        ]

        let sortedCinemas = cinemasSortedByDistance(sameBuilding, from: testUserLocation)

        #expect(namesOf(sortedCinemas) == ["Aurora", "Zebra"])
    }

    @Test func findsPositionOfCinema() {
        #expect(positionOfCinema(testCinemas, cinemaId: testCinemaDCF.id) == 2)
        #expect(positionOfCinema(testCinemas, cinemaId: "no-such-cinema") == cinemaNotFound)
        #expect(containsCinema(testCinemas, cinemaId: testCinemaHelios.id))
        #expect(!containsCinema(testCinemas, cinemaId: "no-such-cinema"))
    }

    @Test func unknownDistanceIsEmptyText() {
        #expect(formattedDistance(unknownDistance) == "")
        #expect(formattedDistance(850) == "850 m")
        #expect(formattedDistance(2430) == "2.4 km")
    }

    @Test func phoneLinkHasOnlyDigits() {
        #expect(phoneURL(testCinemaNoweHoryzonty) == URL(string: "tel:+48717864566"))
        #expect(hasPhoneNumber(testCinemaNoweHoryzonty))
        #expect(websiteURL(testCinemaNoweHoryzonty) == URL(string: "https://kinonh.pl"))
        #expect(hasWebsite(testCinemaNoweHoryzonty))
    }

    @Test func noPhoneOrWebsiteMeansNoLink() {
        #expect(phoneURL(testCinemaHelios) == nil)
        #expect(!hasPhoneNumber(testCinemaHelios))
        #expect(websiteURL(testCinemaHelios) == nil)
        #expect(!hasWebsite(testCinemaHelios))
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
            #expect(hasWebsite(cinema), "\(cinema.name)")
        }
    }

    @Test func pointOutsideRegionIsNotOnTheMap() {
        #expect(!isInRegion(krakowCoordinate, wroclawMapRegion))
        let movedRegion = regionMoved(wroclawMapRegion, to: krakowCoordinate)
        #expect(isInRegion(krakowCoordinate, movedRegion))
        #expect(movedRegion.span.latitudeDelta == wroclawMapRegion.span.latitudeDelta)
    }
}

@MainActor
struct MapKitConversionTests {
    @Test func mapItemForCinemaKeepsNameAndPosition() {
        let mapItem = mapItemForCinema(testCinemaNoweHoryzonty)

        #expect(mapItem.name == testCinemaNoweHoryzonty.name)
        #expect(mapItem.location.coordinate.latitude == testCinemaNoweHoryzonty.latitude)
        #expect(mapItem.location.coordinate.longitude == testCinemaNoweHoryzonty.longitude)
        #expect(mapItem.url == URL(string: "https://kinonh.pl"))
    }

    @Test func travelModeBecomesMapKitTransportType() {
        #expect(transportTypeForMapKit(.walking) == .walking)
        #expect(transportTypeForMapKit(.driving) == .automobile)
    }
}

/// A cinema in the same building as DCF, so cinemas made with it are at the same distance.
@MainActor
private func makeCinemaAtDCF(id: String, name: String) -> Cinema {
    return Cinema(
        id: id,
        name: name,
        address: testCinemaDCF.address,
        phoneNumber: "",
        website: "",
        latitude: testCinemaDCF.latitude,
        longitude: testCinemaDCF.longitude
    )
}
