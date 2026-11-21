import Foundation
import SwiftData
import Testing

@testable import MyNextMovie

/// The saved movies table of one account. A class, so the closures in
/// `SavedMoviesCloud` and the test see the same rows.
@MainActor
private final class TestCloud {
    var movies: [CloudSavedMovie] = []
    var isOffline = false
    var uploadCallCount = 0

    func makeCloud() -> SavedMoviesCloud {
        return SavedMoviesCloud(
            fetchMovies: fetch,
            uploadMovies: upload,
            removeMovie: remove
        )
    }

    private func fetch() throws -> [CloudSavedMovie] {
        try failWhenOffline()
        return movies
    }

    /// Like `upsert` with `ignoreDuplicates`: rows the account has stay as they are.
    private func upload(_ cloudMovies: [CloudSavedMovie]) throws {
        try failWhenOffline()
        uploadCallCount += 1
        for cloudMovie in cloudMovies where !movieIds.contains(cloudMovie.id) {
            movies.append(cloudMovie)
        }
    }

    private func remove(_ movieId: Int) throws {
        try failWhenOffline()
        movies.removeAll { cloudMovie in cloudMovie.id == movieId }
    }

    private func failWhenOffline() throws {
        if isOffline {
            throw NoConnection()
        }
    }

    var movieIds: [Int] {
        return movies.map(\.id)
    }
}

private let firstSaveDate = Date(timeIntervalSince1970: 1_000)
private let laterSaveDate = Date(timeIntervalSince1970: 2_000)

@MainActor
private func cloudMovie(_ movie: Movie, savedAt: Date) -> CloudSavedMovie {
    let savedMovie = SavedMovie(movie: movie, savedAt: savedAt, isInCloud: true)
    return cloudMovieFromSaved(savedMovie)
}

@MainActor
private func savedMovieIds(_ context: ModelContext) -> Set<Int> {
    let savedMovies = (try? context.fetch(FetchDescriptor<SavedMovie>())) ?? []
    return Set(savedMovies.map(\.movieId))
}

@MainActor
private func removedMarkCount(_ context: ModelContext) -> Int {
    return (try? context.fetchCount(FetchDescriptor<RemovedSavedMovie>())) ?? 0
}

@MainActor
struct SavedMoviesSyncTests {
    @Test func movieSavedOnDeviceGoesToAccount() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        toggleSavedMovie(context, testMovies[0], now: firstSaveDate)

        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        #expect(testCloud.movieIds == [testMovies[0].id])
        #expect(fetchSavedMovies(context, movieId: testMovies[0].id).first?.isInCloud == true)
    }

    @Test func movieIsSentOnlyOnce() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        toggleSavedMovie(context, testMovies[0], now: firstSaveDate)

        try await syncSavedMovies(context, cloud: testCloud.makeCloud())
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        #expect(testCloud.uploadCallCount == 1)
        #expect(testCloud.movieIds == [testMovies[0].id])
    }

    @Test func movieFromAccountComesToDevice() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        testCloud.movies = [cloudMovie(testMovies[0], savedAt: firstSaveDate)]

        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        let savedCopies = fetchSavedMovies(context, movieId: testMovies[0].id)
        #expect(moviesFromSaved(savedCopies) == [testMovies[0]])
        #expect(savedCopies.first?.savedAt == firstSaveDate)
        #expect(savedCopies.first?.isInCloud == true)
    }

    @Test func deviceAndAccountListsAreMerged() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        testCloud.movies = [cloudMovie(testMovies[0], savedAt: firstSaveDate)]
        toggleSavedMovie(context, testMovies[1], now: laterSaveDate)

        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        let bothIds: Set = [testMovies[0].id, testMovies[1].id]
        #expect(savedMovieIds(context) == bothIds)
        #expect(Set(testCloud.movieIds) == bothIds)
    }

    @Test func movieRemovedOnDeviceIsRemovedFromAccount() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        toggleSavedMovie(context, testMovies[0], now: firstSaveDate)
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        toggleSavedMovie(context, testMovies[0], now: laterSaveDate)
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        #expect(testCloud.movies.isEmpty)
        #expect(removedMarkCount(context) == 0)
    }

    @Test func movieRemovedOnAnotherDeviceIsRemovedHere() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        testCloud.movies = [cloudMovie(testMovies[0], savedAt: firstSaveDate)]
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        testCloud.movies = []
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        #expect(savedMovieIds(context).isEmpty)
    }

    @Test func changesMadeOfflineAreSentWithTheNextSync() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        toggleSavedMovie(context, testMovies[0], now: firstSaveDate)
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        testCloud.isOffline = true
        toggleSavedMovie(context, testMovies[0], now: laterSaveDate)
        toggleSavedMovie(context, testMovies[1], now: laterSaveDate)
        await #expect(throws: NoConnection.self) {
            try await syncSavedMovies(context, cloud: testCloud.makeCloud())
        }
        #expect(testCloud.movieIds == [testMovies[0].id])

        testCloud.isOffline = false
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        #expect(testCloud.movieIds == [testMovies[1].id])
        #expect(savedMovieIds(context) == [testMovies[1].id])
    }

    @Test func movieRemovedAndSavedAgainOfflineStays() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        toggleSavedMovie(context, testMovies[0], now: firstSaveDate)
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        toggleSavedMovie(context, testMovies[0], now: laterSaveDate)
        toggleSavedMovie(context, testMovies[0], now: laterSaveDate)
        try await syncSavedMovies(context, cloud: testCloud.makeCloud())

        #expect(testCloud.movieIds == [testMovies[0].id])
        #expect(testCloud.movies.first?.savedAt == laterSaveDate)
        #expect(savedMovieIds(context) == [testMovies[0].id])
        #expect(removedMarkCount(context) == 0)
    }
}

@MainActor
struct CloudSavedMovieTests {
    @Test func encodesColumnNamesInSnakeCase() throws {
        let data = try JSONEncoder().encode(cloudMovie(testMovies[0], savedAt: firstSaveDate))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        for key in ["release_date", "poster_path", "vote_average", "genre_ids", "saved_at"] {
            #expect(json[key] != nil, "missing \(key)")
        }
    }

    @Test func cloudCopyKeepsEveryMovieField() {
        let savedMovie = SavedMovie(movie: testMovies[0], savedAt: firstSaveDate, isInCloud: false)

        #expect(movieFromCloud(cloudMovieFromSaved(savedMovie)) == testMovies[0])
    }
}
