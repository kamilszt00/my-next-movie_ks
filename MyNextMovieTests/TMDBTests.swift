import Foundation
import Testing

@testable import MyNextMovie

private let testAPIKey = "test-key"

private let moviePageJSON = """
    {
        "results": [
            {
                "id": 603,
                "title": "The Matrix",
                "overview": "A hacker learns that the world is a simulation.",
                "release_date": "1999-03-31",
                "poster_path": "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg",
                "vote_average": 8.2,
                "genre_ids": [28, 878]
            }
        ]
    }
    """

private let movieWithoutPosterJSON = """
    {
        "results": [
            {
                "id": 1,
                "title": "No Poster",
                "overview": "",
                "release_date": "",
                "poster_path": null,
                "vote_average": 0,
                "genre_ids": []
            }
        ]
    }
    """

private let unexpectedJSON = """
    {"status_code": 7}
    """

private func makeResponse(statusCode: Int) -> HTTPURLResponse {
    let dummyURL = URL(string: "https://example.com")
    return HTTPURLResponse(
        url: dummyURL ?? URL(fileURLWithPath: "/"),
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    ) ?? HTTPURLResponse()
}

@MainActor
struct TMDBTests {
    @Test func decodesSnakeCaseKeys() throws {
        let movies = try decodeTMDBMovies(Data(moviePageJSON.utf8))

        let movie = try #require(movies.first)
        #expect(movie.releaseDate == "1999-03-31")
        #expect(movie.posterPath == "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg")
        #expect(movie.voteAverage == 8.2)
        #expect(movie.genreIds == [28, 878])
    }

    @Test func decodesMissingPosterAsNil() throws {
        let movies = try decodeTMDBMovies(Data(movieWithoutPosterJSON.utf8))

        #expect(movies.first?.posterPath == nil)
    }

    @Test func decodingFailsForOtherJSON() {
        #expect(throws: DecodingError.self) {
            try decodeTMDBMovies(Data(unexpectedJSON.utf8))
        }
    }

    @Test func popularURLHasAPIKey() throws {
        let popularURL = try #require(tmdbPopularURL(apiKey: testAPIKey))
        let expected = "https://api.themoviedb.org/3/movie/popular?api_key=test-key"

        #expect(popularURL.absoluteString == expected)
    }

    @Test func searchWithTextUsesSearchEndpoint() throws {
        let searchURL = try #require(
            tmdbSearchURL(query: "matrix", genreId: noGenreId, apiKey: testAPIKey)
        )
        let components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        #expect(searchURL.path() == "/3/search/movie")
        #expect(queryItems.contains(URLQueryItem(name: "query", value: "matrix")))
    }

    @Test func searchWithGenreOnlyUsesDiscoverEndpoint() throws {
        let searchURL = try #require(
            tmdbSearchURL(query: "", genreId: genreIdAnimation, apiKey: testAPIKey)
        )
        let components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let expectedGenre = URLQueryItem(name: "with_genres", value: String(genreIdAnimation))

        #expect(searchURL.path() == "/3/discover/movie")
        #expect(queryItems.contains(expectedGenre))
    }

    @Test func searchTextIsPercentEncoded() throws {
        let searchURL = try #require(
            tmdbSearchURL(query: "pan tadeusz", genreId: noGenreId, apiKey: testAPIKey)
        )

        #expect(searchURL.absoluteString.contains("query=pan%20tadeusz"))
    }

    @Test func detailsURLAppendsEveryPart() throws {
        let detailsURL = try #require(tmdbMovieDetailsURL(movieId: 603, apiKey: testAPIKey))
        let components = URLComponents(url: detailsURL, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let appendItem = queryItems.first(where: { $0.name == "append_to_response" })
        let appendValue = appendItem?.value ?? ""

        #expect(detailsURL.path() == "/3/movie/603")
        #expect(appendValue.contains("credits"))
        #expect(appendValue.contains("videos"))
        #expect(appendValue.contains("release_dates"))
        #expect(appendValue.contains("watch/providers"))
        #expect(appendValue.contains("recommendations"))
    }

    @Test func okResponsePasses() throws {
        try checkTMDBResponse(makeResponse(statusCode: 200))
    }

    @Test func unauthorizedResponseMentionsAPIKey() {
        let thrownError = #expect(throws: TMDBError.self) {
            try checkTMDBResponse(makeResponse(statusCode: 401))
        }

        #expect(thrownError?.message.contains("API key") == true)
    }

    @Test func otherErrorResponseShowsStatus() {
        let thrownError = #expect(throws: TMDBError.self) {
            try checkTMDBResponse(makeResponse(statusCode: 404))
        }

        #expect(thrownError?.message.contains("404") == true)
    }
}
