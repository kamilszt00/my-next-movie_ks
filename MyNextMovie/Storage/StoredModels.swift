import Foundation
import SwiftData

/// A movie saved to the device.
/// Stores every field of `Movie` so the Saved tab works without network.
@Model
final class SavedMovie {
    @Attribute(.unique) var movieId: Int
    var title: String
    var overview: String
    var releaseDate: String
    var posterPath: String?
    var voteAverage: Double
    var genreIds: [Int]
    var savedAt: Date
    var isInCloud: Bool = false

    init(movie: Movie, savedAt: Date) {
        self.movieId = movie.id
        self.title = movie.title
        self.overview = movie.overview
        self.releaseDate = movie.releaseDate
        self.posterPath = movie.posterPath
        self.voteAverage = movie.voteAverage
        self.genreIds = movie.genreIds
        self.savedAt = savedAt
        self.isInCloud = false
    }
}

/// One past search typed into the search bar.
@Model
final class SearchHistoryEntry {
    @Attribute(.unique) var query: String
    var searchedAt: Date

    init(query: String, searchedAt: Date) {
        self.query = query
        self.searchedAt = searchedAt
    }
}

/// Raw JSON of the last successful TMDB response, keyed by endpoint.
/// Lets the app show something when the network is down.
@Model
final class CachedResponse {
    @Attribute(.unique) var key: String
    var data: Data
    var fetchedAt: Date

    init(key: String, data: Data, fetchedAt: Date) {
        self.key = key
        self.data = data
        self.fetchedAt = fetchedAt
    }
}

/// Every SwiftData model in the app, passed to `modelContainer` and tests.
let storedModelTypes: [any PersistentModel.Type] = [
    SavedMovie.self,
    SearchHistoryEntry.self,
    CachedResponse.self,
]
