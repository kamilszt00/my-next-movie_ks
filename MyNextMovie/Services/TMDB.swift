import Foundation
import SwiftData

// MARK: - Constants

let tmdbScheme = "https"
let tmdbHost = "api.themoviedb.org"

let tmdbPopularPath = "/3/movie/popular"
let tmdbSearchPath = "/3/search/movie"
let tmdbDiscoverPath = "/3/discover/movie"
let tmdbMovieDetailsPathPrefix = "/3/movie/"

let tmdbAPIKeyParam = "api_key"
let tmdbQueryParam = "query"
let tmdbWithGenresParam = "with_genres"
let tmdbAppendToResponseParam = "append_to_response"

let tmdbAppendToResponseValue =
    "credits,videos,release_dates,watch/providers,recommendations"

let httpStatusOK = 200
let httpStatusUnauthorized = 401

let missingTMDBAPIKeyMessage = "Missing TMDB API key. Add it to Config/Secrets.xcconfig."

let popularMoviesCacheKey = "popular"
let movieDetailsCacheKeyPrefix = "movie/"

// MARK: - Types

/// One page of movies as TMDB returns it.
/// TMDB list endpoints wrap the array in an object with a `results` field.
nonisolated struct TMDBMoviePage: Decodable {
    let results: [Movie]
}

/// Error with a message to show on the screen through `error.localizedDescription`.
nonisolated struct TMDBError: LocalizedError {
    let message: String
    var errorDescription: String? { return message }
}

// MARK: - URL building

/// TMDB URL with `api_key` as the first query parameter and `parameters` after it.
func tmdbURL(path: String, parameters: [URLQueryItem], apiKey: String) -> URL? {
    var components = URLComponents()
    components.scheme = tmdbScheme
    components.host = tmdbHost
    components.path = path
    components.queryItems = [URLQueryItem(name: tmdbAPIKeyParam, value: apiKey)] + parameters
    return components.url
}

func tmdbPopularURL(apiKey: String) -> URL? {
    return tmdbURL(path: tmdbPopularPath, parameters: [], apiKey: apiKey)
}

func tmdbMovieDetailsURL(movieId: Int, apiKey: String) -> URL? {
    let path = tmdbMovieDetailsPathPrefix + String(movieId)
    let appendParameter = URLQueryItem(
        name: tmdbAppendToResponseParam,
        value: tmdbAppendToResponseValue
    )
    return tmdbURL(path: path, parameters: [appendParameter], apiKey: apiKey)
}

/// With a non-empty query: `/search/movie` with `query`.
/// Without a query: `/discover/movie` with `with_genres`.
/// `/search/movie` cannot filter by genre, so when both are given, the caller filters locally.
func tmdbSearchURL(query: String, genreId: Int, apiKey: String) -> URL? {
    if query.isEmpty {
        let genreParameter = URLQueryItem(name: tmdbWithGenresParam, value: String(genreId))
        return tmdbURL(path: tmdbDiscoverPath, parameters: [genreParameter], apiKey: apiKey)
    }
    let queryParameter = URLQueryItem(name: tmdbQueryParam, value: query)
    return tmdbURL(path: tmdbSearchPath, parameters: [queryParameter], apiKey: apiKey)
}

// MARK: - Decoding and response check

func decodeTMDBMovies(_ data: Data) throws -> [Movie] {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let page = try decoder.decode(TMDBMoviePage.self, from: data)
    return page.results
}

func decodeTMDBMovieDetails(_ data: Data) throws -> MovieDetails {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(MovieDetails.self, from: data)
}

func checkTMDBResponse(_ response: URLResponse) throws {
    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
    if statusCode == httpStatusOK {
        return
    }
    if statusCode == httpStatusUnauthorized {
        throw TMDBError(message: "Invalid TMDB API key. Check Config/Secrets.xcconfig.")
    }
    throw TMDBError(message: "TMDB request failed with status \(statusCode).")
}

// MARK: - Public requests

func fetchPopularMovies() async throws -> [Movie] {
    let apiKey = try requireTMDBAPIKey()
    let data = try await fetchTMDBData(tmdbPopularURL(apiKey: apiKey))
    return try decodeTMDBMovies(data)
}

func searchTMDBMovies(query: String, genreId: Int) async throws -> [Movie] {
    let apiKey = try requireTMDBAPIKey()
    let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
    let searchURL = tmdbSearchURL(query: trimmedQuery, genreId: genreId, apiKey: apiKey)
    let data = try await fetchTMDBData(searchURL)
    let movies = try decodeTMDBMovies(data)
    if !trimmedQuery.isEmpty && genreId != noGenreId {
        return filterMovies(movies, query: "", genreId: genreId)
    }
    return movies
}

func fetchMovieDetails(movieId: Int) async throws -> MovieDetails {
    let apiKey = try requireTMDBAPIKey()
    let data = try await fetchTMDBData(tmdbMovieDetailsURL(movieId: movieId, apiKey: apiKey))
    return try decodeTMDBMovieDetails(data)
}

/// Popular movies with offline fallback to the last cached response.
func loadPopularMovies(cache: ModelContext) async throws -> [Movie] {
    let apiKey = try requireTMDBAPIKey()
    let data = try await fetchWithCacheFallback(cache, key: popularMoviesCacheKey) {
        try await fetchTMDBData(tmdbPopularURL(apiKey: apiKey))
    }
    return try decodeTMDBMovies(data)
}

/// Movie details with offline fallback to the last cached response.
func loadTMDBMovieDetails(movieId: Int, cache: ModelContext) async throws -> MovieDetails {
    let apiKey = try requireTMDBAPIKey()
    let cacheKey = movieDetailsCacheKeyPrefix + String(movieId)
    let data = try await fetchWithCacheFallback(cache, key: cacheKey) {
        try await fetchTMDBData(tmdbMovieDetailsURL(movieId: movieId, apiKey: apiKey))
    }
    return try decodeTMDBMovieDetails(data)
}

// MARK: - Private helpers

private func requireTMDBAPIKey() throws -> String {
    let apiKey = tmdbAPIKey()
    if apiKey.isEmpty {
        throw TMDBError(message: missingTMDBAPIKeyMessage)
    }
    return apiKey
}

private func fetchTMDBData(_ address: URL?) async throws -> Data {
    guard let address else {
        throw TMDBError(message: "Could not build TMDB URL.")
    }
    let (data, response) = try await URLSession.shared.data(from: address)
    try checkTMDBResponse(response)
    return data
}
