import Foundation
import Testing

@testable import MyNextMovie

/// Long enough that every request sent at once is still waiting when the last one starts.
private let fakeAnswerDelay = Duration.milliseconds(50)

/// Names the fake TMDB knows, with their ids. Every other name finds nothing.
private let knownNames = [
    "Keanu Reeves": 6384,
    "Sandra Bullock": 18277,
    "heist": 10051,
    "bus": 1599,
]

/// What `/discover/movie` and `/search/movie` answer: The Matrix and its first sequel,
/// both Action and Science Fiction, and a Comedy from 1999.
private let movieSearchJSON = """
    {
      "page": 1,
      "results": [
        {"id": 603, "title": "The Matrix", "overview": "", "release_date": "1999-03-31",
         "poster_path": null, "vote_average": 8.2, "genre_ids": [28, 878]},
        {"id": 604, "title": "The Matrix Reloaded", "overview": "", "release_date": "2003-05-15",
         "poster_path": null, "vote_average": 7.0, "genre_ids": [28, 878]},
        {"id": 2000, "title": "Matrix Comedy", "overview": "", "release_date": "1999-01-01",
         "poster_path": null, "vote_average": 5.0, "genre_ids": [35]}
      ]
    }
    """

/// Stands in for TMDB: records every request and answers with the JSON above.
/// Each answer waits a moment, so a test can see how many requests were waiting at once.
@MainActor
private final class FakeTMDB {
    private(set) var requests: [TMDBRequest] = []
    private(set) var mostRequestsAtOnce = 0
    private var waitingRequestCount = 0

    /// Has the type `TMDBFetch`.
    func fetch(_ request: TMDBRequest) async throws -> Data {
        requests.append(request)
        waitingRequestCount += 1
        mostRequestsAtOnce = max(mostRequestsAtOnce, waitingRequestCount)
        try await Task.sleep(for: fakeAnswerDelay)
        waitingRequestCount -= 1
        return Data(answer(request).utf8)
    }

    /// Requests to the path, in the order they were sent.
    func requests(to path: String) -> [TMDBRequest] {
        var matchingRequests: [TMDBRequest] = []
        for request in requests where request.path == path {
            matchingRequests.append(request)
        }
        return matchingRequests
    }

    private func answer(_ request: TMDBRequest) -> String {
        if request.path == tmdbPathSearchPeople || request.path == tmdbPathSearchKeywords {
            return nameSearchAnswer(request.parameters.first?.value ?? "")
        }
        return movieSearchJSON
    }

    private func nameSearchAnswer(_ name: String) -> String {
        guard let id = knownNames[name] else {
            return #"{"page": 1, "results": []}"#
        }
        return #"{"page": 1, "results": [{"id": \#(id)}]}"#
    }
}

@MainActor
struct FilteredSearchTests {
    @Test func namesBecomeIdsInOneDiscoverRequest() async throws {
        let tmdb = FakeTMDB()
        let filters = MovieFilters(
            genreIds: [genreIdAction], fromYear: 1990, toYear: 1999,
            people: ["Keanu Reeves"], keywords: ["heist"], title: "")

        let movies = try await searchMoviesByFilters(filters, fetch: tmdb.fetch)

        let discoverRequests = tmdb.requests(to: tmdbPathDiscoverMovies)
        let discover = try #require(discoverRequests.first)
        #expect(discoverRequests.count == 1)
        #expect(parameterValue(discover, name: "with_genres") == "28")
        #expect(parameterValue(discover, name: "with_people") == "6384")
        #expect(parameterValue(discover, name: "with_keywords") == "10051")
        #expect(parameterValue(discover, name: "primary_release_date.gte") == "1990-01-01")
        // The movies of /discover/movie as they are, TMDB has already filtered them.
        #expect(titlesOf(movies) == ["The Matrix", "The Matrix Reloaded", "Matrix Comedy"])
    }

    @Test func looksUpEveryNameAtOnce() async throws {
        let tmdb = FakeTMDB()
        let filters = MovieFilters(
            genreIds: [], fromYear: noYear, toYear: noYear,
            people: ["Keanu Reeves", "Sandra Bullock"], keywords: ["bus"], title: "")

        _ = try await searchMoviesByFilters(filters, fetch: tmdb.fetch)

        let discover = try #require(tmdb.requests(to: tmdbPathDiscoverMovies).first)
        #expect(tmdb.mostRequestsAtOnce == 3)
        #expect(parameterValue(discover, name: "with_people") == "6384,18277")
        #expect(parameterValue(discover, name: "with_keywords") == "1599")
    }

    @Test func unknownPersonFindsNothing() async throws {
        let tmdb = FakeTMDB()
        let filters = MovieFilters(
            genreIds: [genreIdComedy], fromYear: noYear, toYear: noYear,
            people: ["Keanu Reeves", "Nobody Known"], keywords: [], title: "")

        let movies = try await searchMoviesByFilters(filters, fetch: tmdb.fetch)

        #expect(movies.isEmpty)
        #expect(tmdb.requests(to: tmdbPathDiscoverMovies).isEmpty)
    }

    @Test func onlyUnknownKeywordsFindNothing() async throws {
        let tmdb = FakeTMDB()
        let filters = MovieFilters(
            genreIds: [], fromYear: noYear, toYear: noYear,
            people: [], keywords: ["no such keyword"], title: "")

        let movies = try await searchMoviesByFilters(filters, fetch: tmdb.fetch)

        #expect(movies.isEmpty)
        #expect(tmdb.requests(to: tmdbPathDiscoverMovies).isEmpty)
    }

    @Test func unknownKeywordNextToGenreStillSearches() async throws {
        let tmdb = FakeTMDB()
        let filters = MovieFilters(
            genreIds: [genreIdComedy], fromYear: noYear, toYear: noYear,
            people: [], keywords: ["no such keyword"], title: "")

        let movies = try await searchMoviesByFilters(filters, fetch: tmdb.fetch)

        let discover = try #require(tmdb.requests(to: tmdbPathDiscoverMovies).first)
        #expect(parameterValue(discover, name: "with_genres") == "35")
        #expect(parameterValue(discover, name: "with_keywords").isEmpty)
        #expect(!movies.isEmpty)
    }

    @Test func titleSearchKeepsYearsAndGenres() async throws {
        let tmdb = FakeTMDB()
        let filters = MovieFilters(
            genreIds: [genreIdAction], fromYear: 1990, toYear: 1999,
            people: ["Keanu Reeves"], keywords: [], title: "Matrix")

        let movies = try await searchMoviesByFilters(filters, fetch: tmdb.fetch)

        let titleSearch = TMDBRequest(
            path: tmdbPathSearchMovies, parameters: [URLQueryItem(name: "query", value: "Matrix")])
        // Only the title search: with a title the people and keywords are not looked up.
        #expect(tmdb.requests == [titleSearch])
        #expect(titlesOf(movies) == ["The Matrix"])
    }
}

@MainActor
struct MoviesMatchingFiltersTests {
    @Test func withoutGenresAndYearsAllMatch() {
        let filters = MovieFilters(
            genreIds: [], fromYear: noYear, toYear: noYear,
            people: ["Keanu Reeves"], keywords: ["heist"], title: "")

        #expect(moviesMatchingFilters(testMovies, filters) == testMovies)
    }

    @Test func anyOfTheGenresMatches() {
        let filters = filtersWith(genreIds: [genreIdAnimation, genreIdRomance])

        let matchingMovies = moviesMatchingFilters(testMovies, filters)

        #expect(titlesOf(matchingMovies) == ["Spirited Away", "Titanic"])
    }

    @Test func movieWithoutYearDoesNotMatchYears() {
        let announcedMovie = Movie(
            id: 1, title: "Announced", overview: "", releaseDate: "", posterPath: nil,
            voteAverage: 0, genreIds: [genreIdDrama])

        #expect(moviesMatchingFilters([announcedMovie], filtersWith(fromYear: 1990)).isEmpty)
        #expect(moviesMatchingFilters([announcedMovie], filtersWith()) == [announcedMovie])
    }

    @Test func yearsIncludeBothEnds() {
        let matchingMovies = moviesMatchingFilters(
            testMovies, filtersWith(fromYear: 1994, toYear: 1999))

        #expect(titlesOf(matchingMovies) == ["The Matrix", "Pulp Fiction", "Titanic"])
    }
}

private func titlesOf(_ movies: [Movie]) -> [String] {
    var movieTitles: [String] = []
    for movie in movies {
        movieTitles.append(movie.title)
    }
    return movieTitles
}
