import MapKit
import SwiftUI

/// Part of the screen height the map takes.
private let mapHeightFraction: CGFloat = 0.45

/// Where the cinema map is shown. Only the sheet has a "Done" button.
enum CinemaMapPlacement {
    case tab
    case sheet
}

/// The cinemas of Wrocław on a map and in a list, nearest first.
struct CinemaMapView: View {
    @State private var viewModel: CinemaMapViewModel
    private let findRoute: CinemaRouteFinder
    private let placement: CinemaMapPlacement

    @State private var cameraPosition = MapCameraPosition.region(wroclawMapRegion)
    @State private var path: [Cinema] = []
    @Environment(\.dismiss) private var dismiss

    init(
        viewModel: CinemaMapViewModel,
        findRoute: @escaping CinemaRouteFinder,
        placement: CinemaMapPlacement
    ) {
        _viewModel = State(initialValue: viewModel)
        self.findRoute = findRoute
        self.placement = placement
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Cinemas")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { doneButton }
                .navigationDestination(for: Cinema.self, destination: detailView)
        }
        .task { await viewModel.locateUserIfNeeded() }
    }

    private var content: some View {
        VStack(spacing: 0) {
            map
            if viewModel.isLocationUnavailable {
                locationOffLine
            }
            ScrollViewReader(content: cinemaList)
        }
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $cameraPosition, selection: mapSelection) {
            UserAnnotation()
            ForEach(viewModel.cinemas, content: cinemaMarker)
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange { context in
            viewModel.visibleRegion = context.region
        }
        .containerRelativeFrame(.vertical) { height, _ in
            height * mapHeightFraction
        }
    }

    private func cinemaMarker(_ cinema: Cinema) -> some MapContent {
        Marker(cinema.name, systemImage: symbolNameCinema, coordinate: cinemaCoordinate(cinema))
            .tag(cinema.id)
    }

    /// The map works with an optional id, the view model with `noCinemaSelected`.
    private var mapSelection: Binding<String?> {
        Binding(
            get: {
                viewModel.selectedCinemaId == noCinemaSelected ? nil : viewModel.selectedCinemaId
            },
            set: { cinemaId in viewModel.selectedCinemaId = cinemaId ?? noCinemaSelected }
        )
    }

    private var locationOffLine: some View {
        Label("Turn on location to see distances and routes.", systemImage: symbolNameLocationOff)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(spacingSmall)
            .background(Color(.secondarySystemBackground))
    }

    // MARK: - List

    private func cinemaList(_ proxy: ScrollViewProxy) -> some View {
        List(viewModel.cinemas) { cinema in
            CinemaRow(
                cinema: cinema,
                isSelected: cinema.id == viewModel.selectedCinemaId,
                select: { select(cinema) },
                showDetails: { path.append(cinema) }
            )
            .id(cinema.id)
        }
        .listStyle(.plain)
        // A tapped pin scrolls the list to its row.
        .onChange(of: viewModel.selectedCinemaId) { _, cinemaId in
            if cinemaId != noCinemaSelected {
                withAnimation { proxy.scrollTo(cinemaId, anchor: .center) }
            }
        }
    }

    /// A tapped row selects its cinema and moves the map to it.
    private func select(_ cinema: Cinema) {
        viewModel.toggleCinema(cinema.id)
        if viewModel.selectedCinemaId == cinema.id {
            let region = regionMoved(viewModel.visibleRegion, to: cinemaCoordinate(cinema))
            withAnimation { cameraPosition = .region(region) }
        }
    }

    private func detailView(_ cinema: Cinema) -> some View {
        let detailViewModel = CinemaDetailViewModel(
            cinema: cinema,
            userLocation: viewModel.userLocation,
            findRoute: findRoute
        )
        return CinemaDetailView(viewModel: detailViewModel)
    }

    @ToolbarContentBuilder
    private var doneButton: some ToolbarContent {
        if placement == .sheet {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

/// Name, address and distance of one cinema, with a button that opens its screen.
private struct CinemaRow: View {
    let cinema: Cinema
    let isSelected: Bool
    let select: () -> Void
    let showDetails: () -> Void

    var body: some View {
        HStack(spacing: spacingMedium) {
            Button(action: select) { texts }
                .buttonStyle(.plain)
            Button(action: showDetails) { detailsIcon }
                .buttonStyle(.borderless)
                .accessibilityLabel("Details of \(cinema.name)")
        }
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.15) : nil)
    }

    private var detailsIcon: some View {
        Image(systemName: symbolNameDetails)
            .imageScale(.large)
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: spacingTiny) {
            Text(cinema.name).font(.headline)
            Text(cinema.address)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            distance
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var distance: some View {
        let text = formattedDistance(cinema.distanceInMeters)
        if !text.isEmpty {
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let viewModel = CinemaMapViewModel(
        cinemas: wroclawCinemas,
        findUserLocation: { fallbackUserLocation }
    )
    CinemaMapView(viewModel: viewModel, findRoute: { _, _, _ in noRoute }, placement: .sheet)
}
