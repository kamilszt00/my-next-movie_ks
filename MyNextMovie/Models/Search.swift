import Foundation

/// Movies whose title or overview contains the query and which have the genre.
/// Case and diacritics are ignored. An empty query or `noGenreId` matches every movie.
func filterMovies(_ movies: [Movie], query: String, genreId: Int) -> [Movie] {
    // TODO: Lab 2, task 1. Trim the spaces around `query` first
    // (`query.trimmingCharacters(in: .whitespaces)`). Then go through `movies` with a `for` loop
    // and keep a movie only when both hold:
    // - `genreId` is `noGenreId`, or `movie.genreIds` contains `genreId`,
    // - the trimmed query is empty, or `movieContainsText(movie, trimmedQuery)`.
    // Skip a movie with `continue` instead of nesting one `if` in another.
    return []
}

private func movieContainsText(_ movie: Movie, _ searchedText: String) -> Bool {
    // TODO: Lab 2, task 1. True when `textContains` finds `searchedText`
    // in `movie.title` or in `movie.overview`.
    return false
}

/// Whether `fullText` contains `searchedText`, ignoring case and diacritics.
private func textContains(_ fullText: String, _ searchedText: String) -> Bool {
    let comparisonOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
    return fullText.range(of: searchedText, options: comparisonOptions) != nil
}
