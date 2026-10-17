import SwiftUI

/// Fetches popular movies from TMDB and shows the content when they arrive.
/// Lets single-movie previews use real data without a view model.
struct PopularMoviesPreview<Content: View>: View {
    @ViewBuilder let content: ([Movie]) -> Content

    @State private var movies: [Movie] = []
    @State private var errorMessage = ""

    var body: some View {
        Group {
            if !movies.isEmpty {
                content(movies)
            } else if !errorMessage.isEmpty {
                Text(errorMessage).foregroundStyle(.red)
            } else {
                ProgressView()
            }
        }
        .task { await loadPopularMovies() }
    }

    private func loadPopularMovies() async {
        do {
            movies = try await fetchPopularMovies()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
