import Foundation
import Testing

@testable import MyNextMovie

private let testAPIKey = "test-key"
private let httpStatusNotFound = 404

/// A shortened response of `/3/movie/popular`.
private let popularMoviesJSON = """
    {
      "page": 1,
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
      "page": 1,
      "results": [
        {
          "id": 1,
          "title": "Announced",
          "overview": "",
          "release_date": "",
          "poster_path": null,
          "vote_average": 0,
          "genre_ids": []
        }
      ]
    }
    """

/// What TMDB sends instead of movies, e.g. for a wrong key.
private let tmdbErrorJSON = """
    {"status_code": 7}
    """

@MainActor
struct TMDBTests {
    @Test func decodesSnakeCaseKeys() throws {
        let movies = try decodeTMDBMovies(Data(popularMoviesJSON.utf8))

        let matrix = try #require(movies.first)
        #expect(matrix.releaseDate == "1999-03-31")
        #expect(matrix.posterPath == "/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg")
        #expect(matrix.voteAverage == 8.2)
        #expect(matrix.genreIds == [genreIdAction, genreIdScienceFiction])
    }

    @Test func decodesMissingPosterAsNil() throws {
        let movies = try decodeTMDBMovies(Data(movieWithoutPosterJSON.utf8))

        let announcedMovie = try #require(movies.first)
        #expect(announcedMovie.posterPath == nil)
    }

    @Test func decodingFailsForOtherJSON() {
        #expect(throws: DecodingError.self) {
            try decodeTMDBMovies(Data(tmdbErrorJSON.utf8))
        }
    }

    @Test func popularURLHasAPIKey() {
        let expectedAddress = "https://api.themoviedb.org/3/movie/popular?api_key=test-key"

        #expect(tmdbPopularURL(apiKey: testAPIKey)?.absoluteString == expectedAddress)
    }

    @Test func searchWithTextUsesSearchEndpoint() throws {
        let searchURL = try #require(
            tmdbSearchURL(query: "matrix", genreId: noGenreId, apiKey: testAPIKey)
        )

        #expect(searchURL.path() == "/3/search/movie")
        #expect(queryItems(searchURL).contains(URLQueryItem(name: "query", value: "matrix")))
    }

    @Test func searchWithGenreOnlyUsesDiscoverEndpoint() throws {
        let searchURL = try #require(
            tmdbSearchURL(query: "", genreId: genreIdAnimation, apiKey: testAPIKey)
        )
        let genreParameter = URLQueryItem(name: "with_genres", value: String(genreIdAnimation))

        #expect(searchURL.path() == "/3/discover/movie")
        #expect(queryItems(searchURL).contains(genreParameter))
    }

    @Test func searchTextIsPercentEncoded() throws {
        let searchURL = try #require(
            tmdbSearchURL(query: "pan tadeusz", genreId: noGenreId, apiKey: testAPIKey)
        )

        #expect(searchURL.absoluteString.contains("query=pan%20tadeusz"))
    }

    @Test func detailsURLAppendsEveryPart() throws {
        let detailsURL = try #require(tmdbMovieDetailsURL(movieId: 603, apiKey: testAPIKey))
        let appendedParts = queryValue(detailsURL, name: "append_to_response")

        #expect(detailsURL.path() == "/3/movie/603")
        #expect(
            appendedParts.split(separator: ",")
                == ["credits", "videos", "release_dates", "watch/providers", "recommendations"]
        )
    }

    @Test func okResponsePasses() throws {
        let response = try makeResponse(statusCode: httpStatusOK)

        #expect(throws: Never.self) {
            try checkTMDBResponse(response)
        }
    }

    @Test func unauthorizedResponseMentionsAPIKey() throws {
        let response = try makeResponse(statusCode: httpStatusUnauthorized)

        let thrownError = #expect(throws: TMDBError.self) {
            try checkTMDBResponse(response)
        }

        #expect(thrownError?.message.contains("API key") == true)
    }

    @Test func otherErrorResponseShowsStatus() throws {
        let response = try makeResponse(statusCode: httpStatusNotFound)

        let thrownError = #expect(throws: TMDBError.self) {
            try checkTMDBResponse(response)
        }

        #expect(thrownError?.message.contains(String(httpStatusNotFound)) == true)
    }
}

private func queryItems(_ address: URL) -> [URLQueryItem] {
    let addressParts = URLComponents(url: address, resolvingAgainstBaseURL: false)
    return addressParts?.queryItems ?? []
}

/// Value of the query parameter, "" when the address does not have it.
private func queryValue(_ address: URL, name: String) -> String {
    for queryItem in queryItems(address) {
        if queryItem.name == name {
            return queryItem.value ?? ""
        }
    }
    return ""
}

/// A TMDB response with the status code and no body.
@MainActor
private func makeResponse(statusCode: Int) throws -> HTTPURLResponse {
    let address = try #require(tmdbPopularURL(apiKey: testAPIKey))
    return try #require(
        HTTPURLResponse(url: address, statusCode: statusCode, httpVersion: nil, headerFields: nil)
    )
}
