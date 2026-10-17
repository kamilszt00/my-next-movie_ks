import Foundation
import SwiftData

let maxSearchHistoryCount = 10

// MARK: - Saved movies

/// Saved copies of the movie: empty when the user has not saved it, one otherwise.
func fetchSavedMovies(_ context: ModelContext, movieId: Int) -> [SavedMovie] {
    let descriptor = FetchDescriptor<SavedMovie>(
        predicate: #Predicate { savedMovie in savedMovie.movieId == movieId }
    )
    return (try? context.fetch(descriptor)) ?? []
}

func isMovieSaved(_ context: ModelContext, movieId: Int) -> Bool {
    return !fetchSavedMovies(context, movieId: movieId).isEmpty
}

/// Saves the movie, or removes it when it is already saved.
func toggleSavedMovie(_ context: ModelContext, _ movie: Movie, now: Date) {
    let existingCopies = fetchSavedMovies(context, movieId: movie.id)
    if existingCopies.isEmpty {
        context.insert(SavedMovie(movie: movie, savedAt: now))
    } else {
        for saved in existingCopies {
            context.delete(saved)
        }
    }
}

/// The saved copy as a `Movie`, so views and navigation can use it.
func movieFromSaved(_ savedMovie: SavedMovie) -> Movie {
    return Movie(
        id: savedMovie.movieId,
        title: savedMovie.title,
        overview: savedMovie.overview,
        releaseDate: savedMovie.releaseDate,
        posterPath: savedMovie.posterPath,
        voteAverage: savedMovie.voteAverage,
        genreIds: savedMovie.genreIds
    )
}

func moviesFromSaved(_ savedMovies: [SavedMovie]) -> [Movie] {
    var movies: [Movie] = []
    for saved in savedMovies {
        movies.append(movieFromSaved(saved))
    }
    return movies
}

// MARK: - Search history

/// Trims whitespace. Empty queries are skipped. A repeated query updates the date
/// so it moves to the top. Keeps at most `maxSearchHistoryCount` recent entries.
func recordSearch(_ context: ModelContext, query: String, now: Date) {
    let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
    if trimmedQuery.isEmpty {
        return
    }

    let existingEntries = fetchSearchEntries(context, query: trimmedQuery)
    if let entry = existingEntries.first {
        entry.searchedAt = now
    } else {
        context.insert(SearchHistoryEntry(query: trimmedQuery, searchedAt: now))
    }

    removeOldSearches(context)
}

/// Most recent searches first, at most `maxSearchHistoryCount` entries.
func recentSearches(_ context: ModelContext) -> [SearchHistoryEntry] {
    let descriptor = FetchDescriptor<SearchHistoryEntry>(
        sortBy: [SortDescriptor(\.searchedAt, order: .reverse)]
    )
    let allEntries = (try? context.fetch(descriptor)) ?? []
    return Array(allEntries.prefix(maxSearchHistoryCount))
}

func clearSearchHistory(_ context: ModelContext) {
    let allEntries = (try? context.fetch(FetchDescriptor<SearchHistoryEntry>())) ?? []
    for entry in allEntries {
        context.delete(entry)
    }
}

private func fetchSearchEntries(_ context: ModelContext, query: String) -> [SearchHistoryEntry] {
    let descriptor = FetchDescriptor<SearchHistoryEntry>(
        predicate: #Predicate { entry in entry.query == query }
    )
    return (try? context.fetch(descriptor)) ?? []
}

private func removeOldSearches(_ context: ModelContext) {
    let descriptor = FetchDescriptor<SearchHistoryEntry>(
        sortBy: [SortDescriptor(\.searchedAt, order: .reverse)]
    )
    let allEntries = (try? context.fetch(descriptor)) ?? []
    for entry in allEntries.dropFirst(maxSearchHistoryCount) {
        context.delete(entry)
    }
}

// MARK: - Response cache

/// Replaces the cached JSON under the given key.
func storeCachedResponse(_ context: ModelContext, key: String, data: Data, now: Date) {
    if let existing = fetchCachedResponse(context, key: key) {
        existing.data = data
        existing.fetchedAt = now
    } else {
        context.insert(CachedResponse(key: key, data: data, fetchedAt: now))
    }
}

/// Cached JSON for the key, empty `Data()` when nothing is cached.
func cachedResponseData(_ context: ModelContext, key: String) -> Data {
    return fetchCachedResponse(context, key: key)?.data ?? Data()
}

/// Runs `fetch`, caches and returns its result. On failure returns the cached JSON,
/// or rethrows the error when nothing is cached.
@MainActor
func fetchWithCacheFallback(
    _ context: ModelContext,
    key: String,
    fetch: @MainActor () async throws -> Data
) async throws -> Data {
    do {
        let freshData = try await fetch()
        storeCachedResponse(context, key: key, data: freshData, now: Date())
        return freshData
    } catch {
        let cachedData = cachedResponseData(context, key: key)
        if cachedData.isEmpty {
            throw error
        }
        return cachedData
    }
}

private func fetchCachedResponse(_ context: ModelContext, key: String) -> CachedResponse? {
    let descriptor = FetchDescriptor<CachedResponse>(
        predicate: #Predicate { entry in entry.key == key }
    )
    return (try? context.fetch(descriptor))?.first
}
