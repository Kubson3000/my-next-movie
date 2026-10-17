import Foundation
import SwiftData

// Parts of TMDB API addresses.
// See https://developer.themoviedb.org/reference/intro/getting-started
private let tmdbScheme = "https"
private let tmdbHost = "api.themoviedb.org"
private let tmdbPopularPath = "/3/movie/popular"
private let tmdbSearchPath = "/3/search/movie"
private let tmdbDiscoverPath = "/3/discover/movie"
/// The movie id goes after it: "/3/movie/603".
private let tmdbMovieDetailsPathPrefix = "/3/movie/"

// Names of the query parameters.
private let parameterNameAPIKey = "api_key"
private let parameterNameQuery = "query"
private let parameterNameGenres = "with_genres"
private let parameterNameAppendToResponse = "append_to_response"

/// Parts that the details request adds to the response, so one request gets them all.
private let movieDetailsAppendedParts =
    "credits,videos,release_dates,watch/providers,recommendations"

// Keys of the TMDB responses in the cache.
private let popularMoviesCacheKey = "popular"
/// The movie id goes after it: "movie/603".
private let movieDetailsCacheKeyPrefix = "movie/"

let httpStatusOK = 200
let httpStatusUnauthorized = 401

private let missingAPIKeyMessage = "Missing TMDB API key. Add it to Config/Secrets.xcconfig."
private let invalidAPIKeyMessage = "TMDB rejected the API key. Check it in Config/Secrets.xcconfig."
private let invalidAddressMessage = "Could not build the TMDB address."
private let notHTTPResponseMessage = "TMDB sent a response that is not HTTP."
/// The HTTP status code goes after it.
private let failedRequestMessage = "TMDB request failed with HTTP status "

/// One page of a TMDB movie list, e.g. popular movies or search results.
nonisolated struct TMDBMoviePage: Decodable {
    let results: [Movie]
}

/// A TMDB request that failed. `error.localizedDescription` shows the message on screen.
struct TMDBError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

/// TMDB address with the API key as the first parameter, then `parameters`.
/// nil when the parts do not make a valid address.
func tmdbURL(path: String, parameters: [URLQueryItem], apiKey: String) -> URL? {
    var addressParts = URLComponents()
    addressParts.scheme = tmdbScheme
    addressParts.host = tmdbHost
    addressParts.path = path
    addressParts.queryItems = [URLQueryItem(name: parameterNameAPIKey, value: apiKey)] + parameters
    return addressParts.url
}

func tmdbPopularURL(apiKey: String) -> URL? {
    return tmdbURL(path: tmdbPopularPath, parameters: [], apiKey: apiKey)
}

/// With text: `/search/movie` with the query. Without text: `/discover/movie` with the genre.
func tmdbSearchURL(query: String, genreId: Int, apiKey: String) -> URL? {
    if query.isEmpty {
        let genreParameter = URLQueryItem(name: parameterNameGenres, value: String(genreId))
        return tmdbURL(path: tmdbDiscoverPath, parameters: [genreParameter], apiKey: apiKey)
    }
    let queryParameter = URLQueryItem(name: parameterNameQuery, value: query)
    return tmdbURL(path: tmdbSearchPath, parameters: [queryParameter], apiKey: apiKey)
}

/// Details of one movie with its cast, videos, age ratings, streaming services
/// and recommendations, all in one response.
func tmdbMovieDetailsURL(movieId: Int, apiKey: String) -> URL? {
    let appendedParts = URLQueryItem(
        name: parameterNameAppendToResponse,
        value: movieDetailsAppendedParts
    )
    let path = tmdbMovieDetailsPathPrefix + String(movieId)
    return tmdbURL(path: path, parameters: [appendedParts], apiKey: apiKey)
}

func decodeTMDBMovies(_ data: Data) throws -> [Movie] {
    let moviePage = try makeTMDBDecoder().decode(TMDBMoviePage.self, from: data)
    return moviePage.results
}

func decodeTMDBMovieDetails(_ data: Data) throws -> MovieDetails {
    return try makeTMDBDecoder().decode(MovieDetails.self, from: data)
}

/// Throws a `TMDBError` unless the response has the status 200 OK.
func checkTMDBResponse(_ response: URLResponse) throws {
    guard let httpResponse = response as? HTTPURLResponse else {
        throw TMDBError(message: notHTTPResponseMessage)
    }
    if httpResponse.statusCode == httpStatusUnauthorized {
        throw TMDBError(message: invalidAPIKeyMessage)
    }
    if httpResponse.statusCode != httpStatusOK {
        throw TMDBError(message: failedRequestMessage + String(httpResponse.statusCode))
    }
}

/// Popular movies from TMDB. Has the type `MovieLoader`.
func fetchPopularMovies() async throws -> [Movie] {
    let apiKey = try requireTMDBAPIKey()
    let data = try await fetchTMDBData(tmdbPopularURL(apiKey: apiKey))
    return try decodeTMDBMovies(data)
}

/// Like `fetchPopularMovies`, but stores the response in the cache,
/// and shows the stored one when the request fails, e.g. without internet.
func loadPopularMovies(cache: ModelContext) async throws -> [Movie] {
    let apiKey = try requireTMDBAPIKey()
    let data = try await fetchWithCacheFallback(cache, key: popularMoviesCacheKey) {
        try await fetchTMDBData(tmdbPopularURL(apiKey: apiKey))
    }
    return try decodeTMDBMovies(data)
}

/// Movies from TMDB that match the text and the genre. Has the type `MovieSearch`.
/// `/search/movie` cannot filter by genre, so the found movies are filtered here.
func searchTMDBMovies(query: String, genreId: Int) async throws -> [Movie] {
    let apiKey = try requireTMDBAPIKey()
    let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
    let searchURL = tmdbSearchURL(query: trimmedQuery, genreId: genreId, apiKey: apiKey)
    let data = try await fetchTMDBData(searchURL)
    let foundMovies = try decodeTMDBMovies(data)
    return filterMovies(foundMovies, query: "", genreId: genreId)
}

/// Details of the movie from TMDB. Has the type `MovieDetailsLoader`.
func fetchMovieDetails(movieId: Int) async throws -> MovieDetails {
    let apiKey = try requireTMDBAPIKey()
    let data = try await fetchTMDBData(tmdbMovieDetailsURL(movieId: movieId, apiKey: apiKey))
    return try decodeTMDBMovieDetails(data)
}

/// Like `fetchMovieDetails`, but stores the response in the cache,
/// and shows the stored one when the request fails, e.g. without internet.
func loadTMDBMovieDetails(movieId: Int, cache: ModelContext) async throws -> MovieDetails {
    let apiKey = try requireTMDBAPIKey()
    let cacheKey = movieDetailsCacheKeyPrefix + String(movieId)
    let data = try await fetchWithCacheFallback(cache, key: cacheKey) {
        try await fetchTMDBData(tmdbMovieDetailsURL(movieId: movieId, apiKey: apiKey))
    }
    return try decodeTMDBMovieDetails(data)
}

/// The key from `Config/Secrets.xcconfig`, or a `TMDBError` when there is none.
private func requireTMDBAPIKey() throws -> String {
    let apiKey = tmdbAPIKey()
    if apiKey.isEmpty {
        throw TMDBError(message: missingAPIKeyMessage)
    }
    return apiKey
}

/// Sends a GET request, checks the status code and returns the body of the response.
private func fetchTMDBData(_ address: URL?) async throws -> Data {
    guard let address else {
        throw TMDBError(message: invalidAddressMessage)
    }
    let (data, response) = try await URLSession.shared.data(from: address)
    try checkTMDBResponse(response)
    return data
}

/// TMDB JSON keys are snake_case, e.g. `release_date`, Swift fields are camelCase.
private func makeTMDBDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
}
