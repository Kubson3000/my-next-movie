import Foundation

/// TMDB image server address for cast photos 185 pixels wide.
let tmdbProfileBaseURL = "https://image.tmdb.org/t/p/w185"

/// TMDB image server address for streaming service logos 92 pixels wide.
let tmdbLogoBaseURL = "https://image.tmdb.org/t/p/w92"

/// The trailer key goes after it.
let youTubeWatchBaseURL = "https://www.youtube.com/watch?v="

let youTubeVideoSite = "YouTube"
let trailerVideoType = "Trailer"
let directorJob = "Director"

/// Country of streaming services and age ratings when the phone has no region set.
let defaultWatchRegionCode = "PL"

private let minutesPerHour = 60
private let hoursSuffix = "h"
private let minutesSuffix = "m"
private let directorNamesSeparator = ", "

/// Details of a movie, from one TMDB request with `append_to_response`.
nonisolated struct MovieDetails: Decodable {
    let id: Int
    let tagline: String
    let runtime: Int?  // nil when TMDB does not know the length, e.g. of an announced movie
    let credits: Credits
    let videos: VideoList
    let releaseDates: ReleaseDateList
    let watchProviders: WatchProviderList
    let recommendations: TMDBMoviePage

    /// `watch/providers` has a slash, so it cannot be a Swift field name.
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
    let profilePath: String?  // nil when TMDB has no photo
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
    let key: String  // YouTube video id for videos from YouTube
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

    /// `.convertFromSnakeCase` turns `iso_3166_1` into `iso31661`.
    enum CodingKeys: String, CodingKey {
        case countryCode = "iso31661"
        case releaseDates
    }
}

nonisolated struct ReleaseDate: Decodable {
    let certification: String  // age rating, e.g. "16", empty when unknown
}

nonisolated struct WatchProviderList: Decodable {
    let results: [String: CountryWatchProviders]  // the key is a country code, e.g. "PL"
}

/// Streaming services in one country. TMDB leaves out the lists that the country does not have.
nonisolated struct CountryWatchProviders: Decodable {
    let link: String
    let flatrate: [WatchProvider]?  // in a subscription
    let rent: [WatchProvider]?
    let buy: [WatchProvider]?
}

nonisolated struct WatchProvider: Decodable, Identifiable {
    let providerId: Int
    let providerName: String
    let logoPath: String?

    var id: Int { return providerId }
}

/// Shown until the real details load.
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

/// For a country without streaming data.
let noWatchProviders = CountryWatchProviders(link: "", flatrate: nil, rent: nil, buy: nil)

/// Country from the phone settings, `defaultWatchRegionCode` when there is none.
let watchRegionCode = Locale.current.region?.identifier ?? defaultWatchRegionCode

/// 136 -> "2h 16m", 45 -> "45m", "" when the length is unknown.
func formattedRuntime(_ details: MovieDetails) -> String {
    let runtime = details.runtime ?? 0
    if runtime <= 0 {
        return ""
    }
    let hours = runtime / minutesPerHour
    let minutes = runtime % minutesPerHour
    if hours == 0 {
        return String(minutes) + minutesSuffix
    }
    return String(hours) + hoursSuffix + " " + String(minutes) + minutesSuffix
}

/// "Lana Wachowski, Lilly Wachowski". TMDB often lists one person several times,
/// so every director is here once.
func directorNames(_ details: MovieDetails) -> String {
    var names: [String] = []
    for crewMember in details.credits.crew {
        if crewMember.job == directorJob && !names.contains(crewMember.name) {
            names.append(crewMember.name)
        }
    }
    return names.joined(separator: directorNamesSeparator)
}

/// First non-empty age rating in the country, e.g. "16", "" when there is none.
func ageCertification(_ details: MovieDetails, regionCode: String) -> String {
    for countryReleaseDates in details.releaseDates.results {
        if countryReleaseDates.countryCode == regionCode {
            return firstCertification(countryReleaseDates.releaseDates)
        }
    }
    return ""
}

private func firstCertification(_ releaseDates: [ReleaseDate]) -> String {
    for releaseDate in releaseDates {
        if !releaseDate.certification.isEmpty {
            return releaseDate.certification
        }
    }
    return ""
}

/// Key of the YouTube trailer. An official trailer wins, otherwise the first unofficial one.
/// "" when there is no trailer.
func trailerKey(_ details: MovieDetails) -> String {
    var unofficialTrailerKey = ""
    for video in details.videos.results {
        if !isYouTubeTrailer(video) {
            continue
        }
        if video.official {
            return video.key
        }
        if unofficialTrailerKey.isEmpty {
            unofficialTrailerKey = video.key
        }
    }
    return unofficialTrailerKey
}

private func isYouTubeTrailer(_ video: Video) -> Bool {
    return video.site == youTubeVideoSite && video.type == trailerVideoType
}

/// Trailer address on YouTube, nil when there is no trailer.
func trailerURL(_ details: MovieDetails) -> URL? {
    let key = trailerKey(details)
    if key.isEmpty {
        return nil
    }
    return URL(string: youTubeWatchBaseURL + key)
}

func hasTrailer(_ details: MovieDetails) -> Bool {
    return trailerURL(details) != nil
}

/// "1999 · ★ 8.2 · 2h 16m · 16", without the parts that are unknown.
/// Before the details load it is `yearAndRating`: "1999 · ★ 8.2".
func movieFactsLine(_ movie: Movie, _ details: MovieDetails, regionCode: String) -> String {
    var parts = [yearAndRating(movie)]
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

/// Streaming services in the country, `noWatchProviders` when TMDB has none there.
func watchProviders(_ details: MovieDetails, regionCode: String) -> CountryWatchProviders {
    return details.watchProviders.results[regionCode] ?? noWatchProviders
}

/// Whether at least one service streams, rents or sells the movie.
func hasWatchProviders(_ countryProviders: CountryWatchProviders) -> Bool {
    let streamingServices = countryProviders.flatrate ?? []
    let rentalServices = countryProviders.rent ?? []
    let stores = countryProviders.buy ?? []
    return !streamingServices.isEmpty || !rentalServices.isEmpty || !stores.isEmpty
}

/// Photo address on the TMDB image server, nil when the actor has no photo.
func profileURL(_ castMember: CastMember) -> URL? {
    let profilePath = castMember.profilePath ?? ""
    if profilePath.isEmpty {
        return nil
    }
    return URL(string: tmdbProfileBaseURL + profilePath)
}

/// Logo address on the TMDB image server, nil when the service has no logo.
func logoURL(_ provider: WatchProvider) -> URL? {
    let logoPath = provider.logoPath ?? ""
    if logoPath.isEmpty {
        return nil
    }
    return URL(string: tmdbLogoBaseURL + logoPath)
}
