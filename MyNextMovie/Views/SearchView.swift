import SwiftUI

/// How long to wait after the last keystroke before searching.
private let searchDelayAfterTyping = Duration.milliseconds(300)

private let searchResultThumbnailWidth: CGFloat = 56
private let searchResultTitleMaxLines = 2
private let searchInputKeySeparator = "|"

struct SearchView: View {
    @State private var viewModel: SearchViewModel

    init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                genreFilter
                content.frame(maxHeight: .infinity)
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Title or keyword")
            .navigationDestination(for: Movie.self) { movie in MovieDetailView(movie: movie) }
            .task(id: searchInputKey(viewModel.query, viewModel.selectedGenreId)) {
                await searchAfterPause()
            }
        }
    }

    private var genreFilter: some View {
        GenreFilter(selectedGenreId: viewModel.selectedGenreId, toggleGenre: viewModel.toggleGenre)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            ContentUnavailableView(
                "Find a movie",
                systemImage: symbolNameSearch,
                description: Text("Search by title or keyword, or pick a genre.")
            )
        case .loading:
            ProgressView()
        case .loaded:
            SearchResults(movies: viewModel.movies, query: viewModel.query)
        case .failed:
            ErrorView(title: "Search failed", message: viewModel.errorMessage) {
                Task { await viewModel.search() }
            }
        }
    }

    /// Waits until the user stops typing. Every keystroke cancels the previous wait.
    private func searchAfterPause() async {
        try? await Task.sleep(for: searchDelayAfterTyping)
        if Task.isCancelled {
            return
        }
        await viewModel.search()
    }
}

/// Changes whenever the search input changes, which restarts the search task.
private func searchInputKey(_ query: String, _ selectedGenreId: Int) -> String {
    return String(selectedGenreId) + searchInputKeySeparator + query
}

/// Every genre from `genreTable` as a chip in one row that scrolls sideways.
/// Tapping a chip selects its genre, tapping it again clears the selection.
private struct GenreFilter: View {
    let selectedGenreId: Int
    let toggleGenre: (Int) -> Void

    // TODO: Lab 2, task 2. Like `GenreRow` in `MovieDetailView`:
    // a `ScrollView(.horizontal, showsIndicators: false)` with an `HStack(spacing: spacingSmall)`
    // and `ForEach(genreTable)` inside. `Genre` is `Identifiable`, so no `id:` is needed.
    // Give the `HStack` `.padding(.horizontal)` and `.padding(.vertical, spacingSmall)`.
    // Draw every chip with `genreFilterChip(genre.id)`.
    var body: some View {
        EmptyView()
    }

    // TODO: Lab 2, task 2. A `Button` that calls `toggleGenre(genreId)`, with
    // `GenreChip(genreId:isSelected:)` as its label. The chip is selected when
    // `genreId == selectedGenreId`. Add `.buttonStyle(.plain)`.
    private func genreFilterChip(_ genreId: Int) -> some View {
        GenreChip(genreId: genreId)
    }
}

/// Found movies as a list, or a "no results" message when nothing matches.
private struct SearchResults: View {
    let movies: [Movie]
    let query: String

    // TODO: Lab 2, task 2. When `movies` is empty, show `ContentUnavailableView.search(text: query)`.
    // Otherwise a `List(movies)` with a `SearchResultRow` for every movie and `.listStyle(.plain)`.
    // An `if` in `body` needs `@ViewBuilder`, as `content` in `SearchView` has.
    var body: some View {
        Text("\(movies.count) movies, build the list here")
    }
}

/// One found movie: a small poster on the left, the title, subtitle and rating on the right.
/// Tapping it opens the movie details.
private struct SearchResultRow: View {
    let movie: Movie

    // TODO: Lab 2, task 2. A `NavigationLink(value: movie)` with an `HStack(spacing: spacingMedium)`
    // of `thumbnail` and `details`, and `.padding(.vertical, spacingExtraSmall)` on the `HStack`.
    // - `thumbnail`: `PosterView(movie:cornerRadius:)` with `thumbnailCornerRadius`,
    //   `.frame(width: searchResultThumbnailWidth)`,
    // - `details`: a `VStack(alignment: .leading, spacing: spacingExtraSmall)` with
    //   `Text(movie.title)` in `.headline` limited to `searchResultTitleMaxLines`,
    //   `Text(movieSubtitle(movie))` in `.subheadline` and `Text(ratingWithStar(movie))`
    //   in `.caption`. Both last texts are `.secondary`.
    var body: some View {
        Text(movie.title)
    }
}

#Preview {
    SearchView(viewModel: SearchViewModel(searchMovies: searchSampleMovies))
}
