import SwiftUI

@main
struct MyNextMovieApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

private struct RootView: View {
    var body: some View {
        TabView {
            Tab("Movies", systemImage: symbolNameMovies) {
                MovieListView(viewModel: MovieListViewModel(loadMovies: loadSampleMovies))
            }
            // TODO: Lab 2, task 2. Add a second tab: `Tab("Search", systemImage: symbolNameSearch,
            // role: .search)` with `SearchView(viewModel: SearchViewModel(searchMovies: searchSampleMovies))`.
            // The `.search` role puts the tab apart from the others, at the trailing edge.
        }
    }
}
