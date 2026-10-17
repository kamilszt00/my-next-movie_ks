import Foundation
import Testing

@testable import MyNextMovie

private let matrixDetailsJSON = """
    {
        "id": 603,
        "tagline": "Believe the unbelievable.",
        "runtime": 136,
        "credits": {
            "cast": [
                {"id": 6384, "name": "Keanu Reeves", "character": "Neo", "profile_path": "/k.jpg"},
                {"id": 2975, "name": "Fishburne", "character": "Morpheus", "profile_path": null}
            ],
            "crew": [
                {"id": 9340, "name": "Lana Wachowski", "job": "Director"},
                {"id": 9340, "name": "Lana Wachowski", "job": "Writer"},
                {"id": 9340, "name": "Lana Wachowski", "job": "Director"},
                {"id": 9351, "name": "Lilly Wachowski", "job": "Director"}
            ]
        },
        "videos": {
            "results": [
                {"key": "unoff", "site": "YouTube", "type": "Trailer", "official": false},
                {"key": "offkey", "site": "YouTube", "type": "Trailer", "official": true}
            ]
        },
        "release_dates": {
            "results": [
                {
                    "iso_3166_1": "PL",
                    "release_dates": [
                        {"certification": ""},
                        {"certification": "16"}
                    ]
                }
            ]
        },
        "watch/providers": {
            "results": {
                "PL": {
                    "link": "https://themoviedb.org/pl",
                    "flatrate": [
                        {"provider_id": 119, "provider_name": "Prime", "logo_path": "/a.png"}
                    ],
                    "rent": [
                        {"provider_id": 2, "provider_name": "Apple TV", "logo_path": "/b.png"}
                    ]
                }
            }
        },
        "recommendations": {
            "results": [
                {
                    "id": 604,
                    "title": "The Matrix Reloaded",
                    "overview": "Neo returns.",
                    "release_date": "2003-05-15",
                    "poster_path": "/reloaded.jpg",
                    "vote_average": 7.2,
                    "genre_ids": [28, 878]
                }
            ]
        }
    }
    """

private let announcedMovieJSON = """
    {
        "id": 999,
        "tagline": "",
        "runtime": null,
        "credits": {"cast": [], "crew": []},
        "videos": {"results": []},
        "release_dates": {"results": []},
        "watch/providers": {"results": {}},
        "recommendations": {"results": []}
    }
    """

@MainActor
struct MovieDetailsDecodingTests {
    @Test func decodesTaglineAndRuntime() throws {
        let details = try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))

        #expect(details.id == 603)
        #expect(details.tagline == "Believe the unbelievable.")
        #expect(details.runtime == 136)
    }

    @Test func decodesCastWithAndWithoutPhoto() throws {
        let details = try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))

        #expect(details.credits.cast[0].profilePath == "/k.jpg")
        #expect(details.credits.cast[1].profilePath == nil)
    }

    @Test func decodesWatchProvidersUnderSlashKey() throws {
        let details = try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))
        let polish = try #require(details.watchProviders.results["PL"])

        #expect(polish.flatrate?.isEmpty == false)
        #expect(polish.rent?.isEmpty == false)
        #expect(polish.buy == nil)
    }

    @Test func decodesCountryCodeOfReleaseDates() throws {
        let details = try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))

        #expect(details.releaseDates.results.first?.countryCode == "PL")
    }

    @Test func decodesRecommendationsAsMovies() throws {
        let details = try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))
        let firstRecommendation = try #require(details.recommendations.results.first)

        #expect(firstRecommendation.title == "The Matrix Reloaded")
    }

    @Test func decodesAnnouncedMovieWithoutRuntime() throws {
        let details = try decodeTMDBMovieDetails(Data(announcedMovieJSON.utf8))

        #expect(details.runtime == nil)
        #expect(formattedRuntime(details) == "")
        #expect(!hasWatchProviders(watchProviders(details, regionCode: "PL")))
    }
}

@MainActor
struct MovieDetailsTests {
    @Test func runtimeInHoursAndMinutes() {
        #expect(formattedRuntime(makeMovieDetails(runtime: 136)) == "2h 16m")
        #expect(formattedRuntime(makeMovieDetails(runtime: 120)) == "2h 0m")
    }

    @Test func runtimeUnderAnHourHasOnlyMinutes() {
        #expect(formattedRuntime(makeMovieDetails(runtime: 45)) == "45m")
    }

    @Test func runtimeIsEmptyWhenUnknown() {
        #expect(formattedRuntime(makeMovieDetails(runtime: nil)) == "")
        #expect(formattedRuntime(makeMovieDetails(runtime: 0)) == "")
    }

    @Test func directorsAreListedOnceEach() {
        let crew = [
            CrewMember(id: 1, name: "Lana Wachowski", job: "Director"),
            CrewMember(id: 1, name: "Lana Wachowski", job: "Writer"),
            CrewMember(id: 1, name: "Lana Wachowski", job: "Director"),
            CrewMember(id: 2, name: "Lilly Wachowski", job: "Director"),
        ]

        #expect(directorNames(makeMovieDetails(crew: crew)) == "Lana Wachowski, Lilly Wachowski")
    }

    @Test func directorsAreEmptyWithoutDirector() {
        let crew = [CrewMember(id: 1, name: "Someone", job: "Writer")]

        #expect(directorNames(makeMovieDetails(crew: crew)) == "")
    }

    @Test func certificationSkipsEmptyOnes() {
        let releases = [
            CountryReleaseDates(
                countryCode: "PL",
                releaseDates: [
                    ReleaseDate(certification: ""),
                    ReleaseDate(certification: "16"),
                ]),
            CountryReleaseDates(
                countryCode: "US",
                releaseDates: [
                    ReleaseDate(certification: "R")
                ]),
        ]
        let details = makeMovieDetails(releaseDates: releases)

        #expect(ageCertification(details, regionCode: "PL") == "16")
        #expect(ageCertification(details, regionCode: "US") == "R")
    }

    @Test func certificationIsEmptyForOtherCountry() {
        #expect(ageCertification(makeMovieDetails(), regionCode: "GB") == "")
    }

    @Test func officialTrailerWins() {
        let videos = [
            Video(key: "unofficial", site: "YouTube", type: "Trailer", official: false),
            Video(key: "official", site: "YouTube", type: "Trailer", official: true),
        ]

        #expect(trailerKey(makeMovieDetails(videos: videos)) == "official")
    }

    @Test func unofficialTrailerWhenNoOfficial() {
        let videos = [
            Video(key: "unoff1", site: "YouTube", type: "Trailer", official: false),
            Video(key: "unoff2", site: "YouTube", type: "Trailer", official: false),
        ]

        #expect(trailerKey(makeMovieDetails(videos: videos)) == "unoff1")
    }

    @Test func trailerOnOtherSiteIsSkipped() {
        let videos = [Video(key: "x", site: "Vimeo", type: "Trailer", official: true)]

        #expect(trailerKey(makeMovieDetails(videos: videos)) == "")
    }

    @Test func trailerURLPointsToYouTube() {
        let videos = [Video(key: "abc123", site: "YouTube", type: "Trailer", official: true)]
        let url = trailerURL(makeMovieDetails(videos: videos))

        #expect(url?.absoluteString == "https://www.youtube.com/watch?v=abc123")
    }

    @Test func factsLineAddsRuntimeAndCertification() {
        let movie = makeMovie(releaseDate: "1999-03-31", voteAverage: 8.2)
        let releases = [
            CountryReleaseDates(
                countryCode: "PL",
                releaseDates: [
                    ReleaseDate(certification: "16")
                ])
        ]
        let details = makeMovieDetails(runtime: 136, releaseDates: releases)

        #expect(movieFactsLine(movie, details, regionCode: "PL") == "1999 · ★ 8.2 · 2h 16m · 16")
    }

    @Test func factsLineBeforeDetailsLoad() {
        let movie = makeMovie(releaseDate: "1999-03-31", voteAverage: 8.2)

        #expect(movieFactsLine(movie, emptyMovieDetails, regionCode: "PL") == "1999 · ★ 8.2")
    }

    @Test func profileURLIsNilWithoutPhoto() {
        let withPhoto = CastMember(id: 1, name: "A", character: "A", profilePath: "/a.jpg")
        let withoutPhoto = CastMember(id: 2, name: "B", character: "B", profilePath: nil)

        #expect(profileURL(withPhoto) != nil)
        #expect(profileURL(withoutPhoto) == nil)
    }
}

func makeMovieDetails(
    runtime: Int? = nil,
    cast: [CastMember] = [],
    crew: [CrewMember] = [],
    videos: [Video] = [],
    releaseDates: [CountryReleaseDates] = [],
    watchProviders: [String: CountryWatchProviders] = [:],
    recommendations: [Movie] = []
) -> MovieDetails {
    return MovieDetails(
        id: 1,
        tagline: "",
        runtime: runtime,
        credits: Credits(cast: cast, crew: crew),
        videos: VideoList(results: videos),
        releaseDates: ReleaseDateList(results: releaseDates),
        watchProviders: WatchProviderList(results: watchProviders),
        recommendations: TMDBMoviePage(results: recommendations)
    )
}
