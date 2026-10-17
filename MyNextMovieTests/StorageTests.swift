import Foundation
import SwiftData
import Testing

@testable import MyNextMovie

@MainActor
func makeTestContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: Schema(storedModelTypes), configurations: [configuration])
}

private let searchHistoryBaseDate = Date(timeIntervalSince1970: 0)

private func minute(_ index: Int) -> Date {
    return searchHistoryBaseDate.addingTimeInterval(TimeInterval(60 * index))
}

@MainActor
struct SavedMovieTests {
    @Test func toggleSavesThenRemoves() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let movie = testMovies[0]

        toggleSavedMovie(context, movie, now: Date())
        #expect(isMovieSaved(context, movieId: movie.id))

        toggleSavedMovie(context, movie, now: Date())
        #expect(!isMovieSaved(context, movieId: movie.id))
    }

    @Test func savedCopyKeepsEveryField() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let movie = testMovies[0]

        toggleSavedMovie(context, movie, now: Date())
        let savedCopies = fetchSavedMovies(context, movieId: movie.id)

        #expect(moviesFromSaved(savedCopies) == [movie])
    }
}

@MainActor
struct SearchHistoryTests {
    @Test func newestSearchComesFirst() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "matrix", now: minute(1))
        recordSearch(context, query: "alien", now: minute(2))

        #expect(recentSearches(context).map(\.query) == ["alien", "matrix"])
    }

    @Test func repeatedSearchMovesToTop() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "matrix", now: minute(1))
        recordSearch(context, query: "alien", now: minute(2))
        recordSearch(context, query: "matrix", now: minute(3))

        #expect(recentSearches(context).map(\.query) == ["matrix", "alien"])
    }

    @Test func emptyAndSpacesAreNotRecorded() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "", now: minute(1))
        recordSearch(context, query: "   ", now: minute(2))
        recordSearch(context, query: "  dune  ", now: minute(3))

        #expect(recentSearches(context).map(\.query) == ["dune"])
    }

    @Test func keepsOnlyRecentSearches() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        for index in 0..<13 {
            recordSearch(context, query: "query\(index)", now: minute(index))
        }

        let searches = recentSearches(context)
        #expect(searches.count == 10)
        #expect(searches.first?.query == "query12")
    }

    @Test func clearRemovesEverything() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "matrix", now: minute(1))
        clearSearchHistory(context)

        #expect(recentSearches(context).isEmpty)
    }
}

@MainActor
struct ResponseCacheTests {
    @Test func missingKeyGivesEmptyData() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        #expect(cachedResponseData(context, key: "nope").isEmpty)
    }

    @Test func storingAgainReplacesData() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        storeCachedResponse(context, key: "k", data: Data("first".utf8), now: Date())
        storeCachedResponse(context, key: "k", data: Data("second".utf8), now: Date())

        #expect(cachedResponseData(context, key: "k") == Data("second".utf8))

        let objectCount = try context.fetchCount(FetchDescriptor<CachedResponse>())
        #expect(objectCount == 1)
    }

    @Test func freshAnswerIsReturnedAndCached() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let freshData = Data("fresh".utf8)

        let result = try await fetchWithCacheFallback(context, key: "k") { freshData }

        #expect(result == freshData)
        #expect(cachedResponseData(context, key: "k") == freshData)
    }

    @Test func cachedAnswerIsReturnedWhenOffline() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let cachedData = Data("cached".utf8)
        storeCachedResponse(context, key: "k", data: cachedData, now: Date())

        let result = try await fetchWithCacheFallback(context, key: "k") {
            throw NoConnection()
        }

        #expect(result == cachedData)
    }

    @Test func errorIsRethrownWhenNothingCached() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        await #expect(throws: NoConnection.self) {
            _ = try await fetchWithCacheFallback(context, key: "k") {
                throw NoConnection()
            }
        }
    }
}
