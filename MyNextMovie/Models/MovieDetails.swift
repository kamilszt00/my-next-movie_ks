import Foundation

// MARK: - Constants

private let tmdbProfileImageBaseURL = "https://image.tmdb.org/t/p/w185"
private let tmdbLogoImageBaseURL = "https://image.tmdb.org/t/p/w92"
private let youtubeWatchURL = "https://www.youtube.com/watch?v="

private let directorJob = "Director"
private let youtubeSite = "YouTube"
private let trailerType = "Trailer"

private let minutesPerHour = 60
private let defaultRegionCode = "PL"

/// Country from the phone settings, falls back to Poland when unknown.
let watchRegionCode = Locale.current.region?.identifier ?? defaultRegionCode

// MARK: - Decodable structures

/// Movie details with everything the detail screen needs in one request.
nonisolated struct MovieDetails: Decodable {
    let id: Int
    let tagline: String
    let runtime: Int?
    let credits: Credits
    let videos: VideoList
    let releaseDates: ReleaseDateList
    let watchProviders: WatchProviderList
    let recommendations: TMDBMoviePage

    enum CodingKeys: String, CodingKey {
        case id
        case tagline
        case runtime
        case credits
        case videos
        case releaseDates
        case watchProviders = "watch/providers"
        case recommendations
    }
}

nonisolated struct Credits: Decodable {
    let cast: [CastMember]
    let crew: [CrewMember]
}

nonisolated struct CastMember: Decodable, Identifiable {
    let id: Int
    let name: String
    let character: String
    let profilePath: String?
}

nonisolated struct CrewMember: Decodable {
    let id: Int
    let name: String
    let job: String
}

nonisolated struct VideoList: Decodable {
    let results: [Video]
}

nonisolated struct Video: Decodable {
    let key: String
    let site: String
    let type: String
    let official: Bool
}

nonisolated struct ReleaseDateList: Decodable {
    let results: [CountryReleaseDates]
}

nonisolated struct CountryReleaseDates: Decodable {
    let countryCode: String
    let releaseDates: [ReleaseDate]

    enum CodingKeys: String, CodingKey {
        case countryCode = "iso31661"
        case releaseDates
    }
}

nonisolated struct ReleaseDate: Decodable {
    let certification: String
}

nonisolated struct WatchProviderList: Decodable {
    let results: [String: CountryWatchProviders]
}

nonisolated struct CountryWatchProviders: Decodable {
    let link: String
    let flatrate: [WatchProvider]?
    let rent: [WatchProvider]?
    let buy: [WatchProvider]?
}

nonisolated struct WatchProvider: Decodable, Identifiable {
    let providerId: Int
    let providerName: String
    let logoPath: String?

    var id: Int { return providerId }
}

// MARK: - Empty values

/// Shown on the detail screen before the real details arrive.
let emptyMovieDetails = MovieDetails(
    id: 0,
    tagline: "",
    runtime: nil,
    credits: Credits(cast: [], crew: []),
    videos: VideoList(results: []),
    releaseDates: ReleaseDateList(results: []),
    watchProviders: WatchProviderList(results: [:]),
    recommendations: TMDBMoviePage(results: [])
)

/// Returned by `watchProviders` for a country TMDB has no data for.
let noWatchProviders = CountryWatchProviders(
    link: "",
    flatrate: nil,
    rent: nil,
    buy: nil
)

// MARK: - Formatting

/// 136 → "2h 16m", 45 → "45m", nil or 0 → "".
func formattedRuntime(_ details: MovieDetails) -> String {
    guard let runtime = details.runtime, runtime > 0 else {
        return ""
    }
    let hours = runtime / minutesPerHour
    let minutes = runtime % minutesPerHour
    if hours == 0 {
        return "\(minutes)m"
    }
    return "\(hours)h \(minutes)m"
}

/// Names of people whose job is "Director", each listed once.
/// TMDB often lists one person as director and writer, so duplicates are skipped.
func directorNames(_ details: MovieDetails) -> String {
    var uniqueDirectorNames: [String] = []
    for member in details.credits.crew {
        if member.job != directorJob {
            continue
        }
        if uniqueDirectorNames.contains(member.name) {
            continue
        }
        uniqueDirectorNames.append(member.name)
    }
    return uniqueDirectorNames.joined(separator: ", ")
}

/// First non-empty certification for the given country, "" when there is none.
func ageCertification(_ details: MovieDetails, regionCode: String) -> String {
    for country in details.releaseDates.results {
        if country.countryCode != regionCode {
            continue
        }
        for release in country.releaseDates {
            if !release.certification.isEmpty {
                return release.certification
            }
        }
    }
    return ""
}

/// YouTube trailer key. Official wins, otherwise the first unofficial, "" when none.
func trailerKey(_ details: MovieDetails) -> String {
    var firstUnofficialKey = ""
    for video in details.videos.results {
        if video.site != youtubeSite || video.type != trailerType {
            continue
        }
        if video.official {
            return video.key
        }
        if firstUnofficialKey.isEmpty {
            firstUnofficialKey = video.key
        }
    }
    return firstUnofficialKey
}

func trailerURL(_ details: MovieDetails) -> URL? {
    let key = trailerKey(details)
    if key.isEmpty {
        return nil
    }
    return URL(string: youtubeWatchURL + key)
}

func hasTrailer(_ details: MovieDetails) -> Bool {
    return !trailerKey(details).isEmpty
}

/// "1999 · ★ 8.2 · 2h 16m · 16", skipping parts that are missing.
func movieFactsLine(_ movie: Movie, _ details: MovieDetails, regionCode: String) -> String {
    var parts: [String] = [yearAndRating(movie)]

    let runtime = formattedRuntime(details)
    if !runtime.isEmpty {
        parts.append(runtime)
    }

    let certification = ageCertification(details, regionCode: regionCode)
    if !certification.isEmpty {
        parts.append(certification)
    }

    return parts.joined(separator: textSeparator)
}

// MARK: - Watch providers

func watchProviders(_ details: MovieDetails, regionCode: String) -> CountryWatchProviders {
    return details.watchProviders.results[regionCode] ?? noWatchProviders
}

func hasWatchProviders(_ countryProviders: CountryWatchProviders) -> Bool {
    let empty =
        (countryProviders.flatrate ?? []).isEmpty
        && (countryProviders.rent ?? []).isEmpty
        && (countryProviders.buy ?? []).isEmpty
    return !empty
}

// MARK: - Image URLs

func profileURL(_ castMember: CastMember) -> URL? {
    let path = castMember.profilePath ?? ""
    if path.isEmpty {
        return nil
    }
    return URL(string: tmdbProfileImageBaseURL + path)
}

func logoURL(_ provider: WatchProvider) -> URL? {
    let path = provider.logoPath ?? ""
    if path.isEmpty {
        return nil
    }
    return URL(string: tmdbLogoImageBaseURL + path)
}
