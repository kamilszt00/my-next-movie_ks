import MapKit
import SwiftUI

private let detailMapHeight: CGFloat = 240
private let lookAroundHeight: CGFloat = 180
private let routeLineWidth: CGFloat = 5

/// One cinema: the way there, links and street-level photos.
struct CinemaDetailView: View {
    @State private var viewModel: CinemaDetailViewModel
    @State private var cameraPosition = MapCameraPosition.automatic
    @State private var lookAroundScene: MKLookAroundScene?

    init(viewModel: CinemaDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            mapSection
            addressSection
            wayThereSection
            linksSection
            lookAroundSection
        }
        .navigationTitle(viewModel.cinema.name)
        .navigationBarTitleDisplayMode(.inline)
        // Finds the route again after every change between Walk and Drive.
        .task(id: viewModel.travelMode) { await viewModel.loadRoute() }
        .task { lookAroundScene = await findLookAroundScene(viewModel.cinema) }
        .onChange(of: viewModel.routeState) {
            // Fits the map to the cinema and the new route.
            cameraPosition = .automatic
        }
    }

    // MARK: - Sections

    private var mapSection: some View {
        Section {
            routeMap
                .frame(height: detailMapHeight)
                .listRowInsets(EdgeInsets())
        }
    }

    private var routeMap: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            Marker(
                viewModel.cinema.name, systemImage: symbolNameCinema,
                coordinate: cinemaCoordinate(viewModel.cinema))
            MapPolyline(viewModel.route.line)
                .stroke(.blue, lineWidth: routeLineWidth)
        }
    }

    private var addressSection: some View {
        Section {
            Text(viewModel.cinema.address)
            let distance = formattedDistance(viewModel.cinema.distanceInMeters)
            if !distance.isEmpty {
                LabeledContent("Distance", value: distance)
            }
        }
    }

    private var wayThereSection: some View {
        Section("Way There") {
            Picker("Travel mode", selection: $viewModel.travelMode) {
                Label("Walk", systemImage: symbolNameWalking).tag(TravelMode.walking)
                Label("Drive", systemImage: symbolNameDriving).tag(TravelMode.driving)
            }
            .pickerStyle(.segmented)
            routeStatus
        }
    }

    @ViewBuilder
    private var routeStatus: some View {
        if viewModel.canFindRoute {
            routeStateText
        } else {
            Text("Turn on location to see the way there.")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var routeStateText: some View {
        switch viewModel.routeState {
        case .idle, .loading:
            ProgressView()
        case .loaded:
            Text(routeSummary(viewModel.route))
        case .failed:
            Text(viewModel.errorMessage).foregroundStyle(.red)
        }
    }

    private var linksSection: some View {
        Section {
            Button(action: openInMaps) {
                Label("Directions in Maps", systemImage: symbolNameDirections)
            }
            if let url = phoneURL(viewModel.cinema) {
                Link(destination: url) { phoneLabel }
            }
            if let url = websiteURL(viewModel.cinema) {
                Link(destination: url) { websiteLabel }
            }
        }
    }

    private var phoneLabel: some View {
        Label(viewModel.cinema.phoneNumber, systemImage: symbolNamePhone)
    }

    private var websiteLabel: some View {
        Label("Website", systemImage: symbolNameWebsite)
    }

    @ViewBuilder
    private var lookAroundSection: some View {
        if let lookAroundScene {
            Section("Look Around") {
                lookAroundPreview(lookAroundScene)
            }
        }
    }

    private func lookAroundPreview(_ scene: MKLookAroundScene) -> some View {
        LookAroundPreview(initialScene: scene)
            .frame(height: lookAroundHeight)
            .listRowInsets(EdgeInsets())
    }

    private func openInMaps() {
        openCinemaInMaps(viewModel.cinema, travelMode: viewModel.travelMode)
    }
}

#Preview {
    let viewModel = CinemaDetailViewModel(
        cinema: wroclawCinemas[0],
        userLocation: fallbackUserLocation,
        findRoute: { _, _, _ in noRoute }
    )
    NavigationStack {
        CinemaDetailView(viewModel: viewModel)
    }
}
