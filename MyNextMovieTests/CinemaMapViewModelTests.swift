import MapKit
import Testing

@testable import MyNextMovie

/// A known place other than the station, for the last known location.
@MainActor
private let rynekLocation = UserLocation(
    latitude: fallbackCoordinate.latitude,
    longitude: fallbackCoordinate.longitude,
    isKnown: true
)

@MainActor
struct CinemaMapViewModelTests {
    @Test func showsCinemasAtOnceByName() {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: { testUserLocation })

        #expect(
            namesOf(viewModel.cinemas) == [
                "DCF", "Helios Magnolia", "Kino Nowe Horyzonty", "Multikino Pasaż Grunwaldzki",
            ])
    }

    @Test func sortsByDistanceOnceUserIsFound() async {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: { testUserLocation })

        await viewModel.locateUser()

        #expect(viewModel.cinemas.first?.name == "DCF")
        #expect(viewModel.userLocation == testUserLocation)
    }

    @Test func lastKnownLocationIsUsedWhenNoFreshOneComes() async {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: { fallbackUserLocation },
            lastKnownLocation: { testUserLocation }
        )

        await viewModel.locateUser()

        #expect(viewModel.userLocation == testUserLocation)
        #expect(!viewModel.isLocationUnavailable)
    }

    @Test func freshLocationReplacesLastKnownOne() async {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: { testUserLocation },
            lastKnownLocation: { rynekLocation }
        )

        await viewModel.locateUser()

        #expect(viewModel.userLocation == testUserLocation)
    }

    @Test func saysWhenLocationIsUnavailable() async {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: { fallbackUserLocation })
        #expect(!viewModel.isLocationUnavailable)

        await viewModel.locateUser()

        #expect(viewModel.isLocationUnavailable)
        #expect(viewModel.cinemas.first?.name == "DCF")
        #expect(viewModel.cinemas.first?.distanceInMeters == unknownDistance)
    }

    @Test func asksForLocationOnlyOnce() async {
        var findCallCount = 0
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas,
            findUserLocation: {
                findCallCount += 1
                return testUserLocation
            }
        )

        await viewModel.locateUserIfNeeded()
        await viewModel.locateUserIfNeeded()

        #expect(findCallCount == 1)
    }

    @Test func togglesSelection() {
        let viewModel = CinemaMapViewModel(
            cinemas: testCinemas, findUserLocation: { testUserLocation })

        viewModel.toggleCinema("dcf")
        #expect(viewModel.selectedCinemaId == "dcf")

        viewModel.toggleCinema("dcf")
        #expect(viewModel.selectedCinemaId == noCinemaSelected)
    }
}

@MainActor
private let testRoute = CinemaRoute(line: MKPolyline(), distanceInMeters: 950, travelTime: 720)

@MainActor
struct CinemaDetailViewModelTests {
    @Test func findsNoRouteWithoutLocation() async {
        var findCallCount = 0
        let viewModel = CinemaDetailViewModel(
            cinema: testCinemaDCF,
            userLocation: fallbackUserLocation,
            findRoute: { _, _, _ in
                findCallCount += 1
                return testRoute
            }
        )

        await viewModel.loadRoute()

        #expect(!viewModel.canFindRoute)
        #expect(findCallCount == 0)
        #expect(viewModel.routeState == .idle)
    }

    @Test func findsRouteForSelectedTravelMode() async {
        var requestedMode = TravelMode.walking
        let viewModel = CinemaDetailViewModel(
            cinema: testCinemaDCF,
            userLocation: testUserLocation,
            findRoute: { _, _, travelMode in
                requestedMode = travelMode
                return testRoute
            }
        )
        viewModel.travelMode = .driving

        await viewModel.loadRoute()

        #expect(requestedMode == .driving)
        #expect(viewModel.routeState == .loaded)
        #expect(viewModel.route.distanceInMeters == 950)
    }

    @Test func showsErrorWhenRouteFails() async {
        let viewModel = CinemaDetailViewModel(
            cinema: testCinemaDCF,
            userLocation: testUserLocation,
            findRoute: { _, _, _ in throw NoRouteFound() }
        )

        await viewModel.loadRoute()

        #expect(viewModel.routeState == .failed)
        #expect(viewModel.errorMessage == "Maps found no way to this cinema.")
    }

    @Test func routeSummaryHasTimeAndDistance() {
        #expect(routeSummary(testRoute) == "12 min \u{00B7} 950 m")
    }
}
