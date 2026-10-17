import SwiftData
import SwiftUI

struct SavedMoviesView: View {
    @Query(sort: \SavedMovie.savedAt, order: .reverse) private var savedMovies: [SavedMovie]
    private let loadDetails: MovieDetailsLoader

    init(loadDetails: @escaping MovieDetailsLoader) {
        self.loadDetails = loadDetails
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Watch Later")
                .navigationDestination(for: Movie.self) { movie in
                    MovieDetailView(movie: movie, loadDetails: loadDetails)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if savedMovies.isEmpty {
            ContentUnavailableView(
                "No saved movies",
                systemImage: symbolNameSaved,
                description: Text("Tap the bookmark on a movie's details to save it.")
            )
        } else {
            MovieGrid(title: "Watch Later", movies: moviesFromSaved(savedMovies))
        }
    }
}

/// Toolbar button that saves or removes the current movie.
struct SaveMovieButton: View {
    let movie: Movie
    @Environment(\.modelContext) private var modelContext
    @Query private var savedCopies: [SavedMovie]

    init(movie: Movie) {
        self.movie = movie
        let movieId = movie.id
        _savedCopies = Query(filter: #Predicate { saved in saved.movieId == movieId })
    }

    var body: some View {
        Button(action: toggle) {
            Image(systemName: isSaved ? symbolNameSavedFilled : symbolNameSaved)
        }
        .accessibilityLabel(isSaved ? "Remove from saved" : "Save movie")
    }

    private var isSaved: Bool {
        return !savedCopies.isEmpty
    }

    private func toggle() {
        toggleSavedMovie(modelContext, movie, now: Date())
    }
}

#Preview {
    SavedMoviesView(loadDetails: fetchMovieDetails)
        .modelContainer(for: storedModelTypes, inMemory: true)
}
