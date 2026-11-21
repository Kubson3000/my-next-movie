import Foundation
import SwiftData

// Parts of TMDB API addresses.
// See https://developer.themoviedb.org/reference/intro/getting-started
private let tmdbScheme = "https"
private let tmdbHost = "api.themoviedb.org"
private let tmdbPopularPath = "/3/movie/popular"
let tmdbPathSearchMovies = "/3/search/movie"
let tmdbPathDiscoverMovies = "/3/discover/movie"
let tmdbPathSearchPeople = "/3/search/person"
let tmdbPathSearchKeywords = "/3/search/keyword"
/// The movie id goes after it: "/3/movie/603".
private let tmdbMovieDetailsPathPrefix = "/3/movie/"

// Names of the query parameters.
private let parameterNameAPIKey = "api_key"
private let parameterNameQuery = "query"
private let parameterNameGenres = "with_genres"
private let parameterNamePeople = "with_people"
private let parameterNameKeywords = "with_keywords"
private let parameterNameFromDate = "primary_release_date.gte"
private let parameterNameToDate = "primary_release_date.lte"
private let parameterNameAppendToResponse = "append_to_response"

/// `/discover/movie` finds movies with any of the genres or keywords joined by "|",
/// but only movies with every person joined by ",".
private let anyOfSeparator = "|"
private let everyOfSeparator = ","

/// Year filters cover whole years: "1990" becomes "1990-01-01" to "1999-12-31".
private let firstDayOfYearSuffix = "-01-01"
private let lastDayOfYearSuffix = "-12-31"

/// Id of a person or keyword that TMDB does not know.
let noTMDBId = 0

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

/// One page of TMDB people or keywords. The search needs only their ids.
private nonisolated struct TMDBIdPage: Decodable {
    let results: [TMDBIdResult]
}

private nonisolated struct TMDBIdResult: Decodable {
    let id: Int
}

/// A TMDB request without the API key, so tests can check it without the network.
nonisolated struct TMDBRequest: Equatable {
    let path: String
    let parameters: [URLQueryItem]
}

/// Any function that sends a TMDB request and returns the body of the response.
/// The app passes `fetchTMDBRequest`, tests pass answers written into them.
typealias TMDBFetch =
    @MainActor (_ request: TMDBRequest) async throws -> Data

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
        return tmdbURL(path: tmdbPathDiscoverMovies, parameters: [genreParameter], apiKey: apiKey)
    }
    let queryParameter = URLQueryItem(name: parameterNameQuery, value: query)
    return tmdbURL(path: tmdbPathSearchMovies, parameters: [queryParameter], apiKey: apiKey)
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

/// `/discover/movie` with the filters: any of the genres and keywords, every person,
/// and the release years. Without filters it has no parameters.
func tmdbDiscoverRequest(_ filters: MovieFilters, personIds: [Int], keywordIds: [Int])
    -> TMDBRequest
{
    var parameters: [URLQueryItem] = []
    if !filters.genreIds.isEmpty {
        let genres = joinedIds(filters.genreIds, separator: anyOfSeparator)
        parameters.append(URLQueryItem(name: parameterNameGenres, value: genres))
    }
    if filters.fromYear != noYear {
        let fromDate = String(filters.fromYear) + firstDayOfYearSuffix
        parameters.append(URLQueryItem(name: parameterNameFromDate, value: fromDate))
    }
    if filters.toYear != noYear {
        let toDate = String(filters.toYear) + lastDayOfYearSuffix
        parameters.append(URLQueryItem(name: parameterNameToDate, value: toDate))
    }
    if !personIds.isEmpty {
        let people = joinedIds(personIds, separator: everyOfSeparator)
        parameters.append(URLQueryItem(name: parameterNamePeople, value: people))
    }
    if !keywordIds.isEmpty {
        let keywords = joinedIds(keywordIds, separator: anyOfSeparator)
        parameters.append(URLQueryItem(name: parameterNameKeywords, value: keywords))
    }
    return TMDBRequest(path: tmdbPathDiscoverMovies, parameters: parameters)
}

/// A search for a person, a keyword or a movie title, depending on the path.
func tmdbNameSearchRequest(path: String, name: String) -> TMDBRequest {
    let queryParameter = URLQueryItem(name: parameterNameQuery, value: name)
    return TMDBRequest(path: path, parameters: [queryParameter])
}

/// Id of the first person or keyword in the response, which TMDB ranks as the best match.
/// `noTMDBId` when nothing was found.
func decodeFirstTMDBId(_ data: Data) throws -> Int {
    let idPage = try makeTMDBDecoder().decode(TMDBIdPage.self, from: data)
    return idPage.results.first?.id ?? noTMDBId
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

/// Movies from TMDB that match the filters. Has the type `FilteredMovieSearch`.
func searchTMDBMoviesByFilters(_ filters: MovieFilters) async throws -> [Movie] {
    return try await searchMoviesByFilters(filters, fetch: fetchTMDBRequest)
}

/// With a title: `/search/movie` with it, then only the found movies with the genres and years.
/// Without one: the names of people and keywords become TMDB ids, all asked at once,
/// and then one `/discover/movie` request finds the movies.
/// An unknown person finds nothing, because every person must be in the movie.
/// An unknown keyword is left out. When no filter is left, it finds nothing too,
/// because `/discover/movie` without filters returns the popular movies.
func searchMoviesByFilters(_ filters: MovieFilters, fetch: @escaping TMDBFetch) async throws
    -> [Movie]
{
    if !filters.title.isEmpty {
        let titleSearch = tmdbNameSearchRequest(path: tmdbPathSearchMovies, name: filters.title)
        let foundMovies = try decodeTMDBMovies(try await fetch(titleSearch))
        return moviesMatchingFilters(foundMovies, filters)
    }
    async let personIds = findTMDBIds(filters.people, path: tmdbPathSearchPeople, fetch: fetch)
    async let keywordIds = findTMDBIds(
        filters.keywords, path: tmdbPathSearchKeywords, fetch: fetch)
    let foundPersonIds = try await personIds
    let foundKeywordIds = try await keywordIds
    if foundPersonIds.contains(noTMDBId) {
        return []
    }
    let knownKeywordIds = foundKeywordIds.filter { keywordId in keywordId != noTMDBId }
    let discover = tmdbDiscoverRequest(
        filters, personIds: foundPersonIds, keywordIds: knownKeywordIds)
    if discover.parameters.isEmpty {
        return []
    }
    return try decodeTMDBMovies(try await fetch(discover))
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

/// Sends the request with the API key. Has the type `TMDBFetch`.
func fetchTMDBRequest(_ request: TMDBRequest) async throws
    -> Data
{
    let apiKey = try requireTMDBAPIKey()
    let address = tmdbURL(
        path: request.path,
        parameters: request.parameters, apiKey: apiKey)
    return try await fetchTMDBData(address)
}

/// TMDB ids of the names, in the same order, with `noTMDBId` for a name TMDB does not know.
/// Every name is a separate request, and they all go at once.
private func findTMDBIds(_ names: [String], path: String, fetch: @escaping TMDBFetch)
    async throws -> [Int]
{
    var requests: [TMDBRequest] = []
    for name in names {
        requests.append(tmdbNameSearchRequest(path: path, name: name))
    }
    let responses = try await withThrowingTaskGroup(of: (Int, Data).self) { group in
        for (position, request) in requests.enumerated() {
            group.addTask { (position, try await fetch(request)) }
        }
        // The answers come in any order, the position puts them back in the order of the names.
        var responsesInOrder = Array(repeating: Data(), count: requests.count)
        for try await (position, data) in group {
            responsesInOrder[position] = data
        }
        return responsesInOrder
    }
    var ids: [Int] = []
    for data in responses {
        ids.append(try decodeFirstTMDBId(data))
    }
    return ids
}

/// "35|28" or "6384,530".
private func joinedIds(_ ids: [Int], separator: String) -> String {
    var idTexts: [String] = []
    for id in ids {
        idTexts.append(String(id))
    }
    return idTexts.joined(separator: separator)
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
