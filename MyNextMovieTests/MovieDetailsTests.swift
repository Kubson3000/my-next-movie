import Foundation
import Testing

@testable import MyNextMovie

/// Details of The Matrix as TMDB sends them, shortened. The second actor has no photo,
/// Lana Wachowski is a director twice, an unofficial trailer comes before the official one,
/// and in Poland a release without an age rating comes before the one with "16".
private let matrixDetailsJSON = """
    {
      "id": 603,
      "tagline": "Believe the unbelievable.",
      "runtime": 136,
      "credits": {
        "cast": [
          {"id": 6384, "name": "Keanu Reeves", "character": "Neo", "profile_path": "/8RZL.jpg"},
          {"id": 1090466, "name": "Deni Gordon", "character": "Priestess", "profile_path": null}
        ],
        "crew": [
          {"id": 9340, "name": "Lana Wachowski", "job": "Director"},
          {"id": 9339, "name": "Lilly Wachowski", "job": "Director"},
          {"id": 9340, "name": "Lana Wachowski", "job": "Director"},
          {"id": 9340, "name": "Lana Wachowski", "job": "Screenplay"},
          {"id": 4671, "name": "Zach Staenberg", "job": "Editor"}
        ]
      },
      "videos": {
        "results": [
          {"key": "fanTrailer", "site": "YouTube", "type": "Trailer", "official": false},
          {"key": "vKQi3bBA1y8", "site": "YouTube", "type": "Trailer", "official": true},
          {"key": "makingOf", "site": "YouTube", "type": "Featurette", "official": true}
        ]
      },
      "release_dates": {
        "results": [
          {"iso_3166_1": "PL", "release_dates": [{"certification": ""}, {"certification": "16"}]},
          {"iso_3166_1": "US", "release_dates": [{"certification": "R"}]}
        ]
      },
      "watch/providers": {
        "results": {
          "PL": {
            "link": "https://www.themoviedb.org/movie/603-the-matrix/watch?locale=PL",
            "flatrate": [
              {"provider_id": 8, "provider_name": "Netflix", "logo_path": "/pbpM.jpg"}
            ],
            "rent": [
              {"provider_id": 2, "provider_name": "Apple TV", "logo_path": "/9ghg.jpg"}
            ]
          }
        }
      },
      "recommendations": {
        "page": 1,
        "results": [
          {
            "id": 604,
            "title": "The Matrix Reloaded",
            "overview": "Neo and the rebels fight the machines in Zion.",
            "release_date": "2003-05-15",
            "poster_path": null,
            "vote_average": 7.1,
            "genre_ids": [12, 28, 878]
          }
        ]
      }
    }
    """

/// An announced movie: TMDB does not know its length yet and has empty lists.
private let announcedMovieDetailsJSON = """
    {
      "id": 1,
      "tagline": "",
      "runtime": null,
      "credits": {"cast": [], "crew": []},
      "videos": {"results": []},
      "release_dates": {"results": []},
      "watch/providers": {"results": {}},
      "recommendations": {"page": 1, "results": []}
    }
    """

private let polandRegionCode = "PL"
private let unitedStatesRegionCode = "US"
private let germanyRegionCode = "DE"

@MainActor
struct MovieDetailsDecodingTests {
    @Test func decodesTaglineAndRuntime() throws {
        let details = try decodeMatrixDetails()

        #expect(details.id == 603)
        #expect(details.tagline == "Believe the unbelievable.")
        #expect(details.runtime == 136)
    }

    @Test func decodesCastWithAndWithoutPhoto() throws {
        let cast = try decodeMatrixDetails().credits.cast

        try #require(cast.count == 2)
        #expect(cast[0].profilePath == "/8RZL.jpg")
        #expect(cast[1].profilePath == nil)
    }

    @Test func decodesWatchProvidersUnderSlashKey() throws {
        let details = try decodeMatrixDetails()

        let polishProviders = try #require(details.watchProviders.results[polandRegionCode])
        #expect(polishProviders.flatrate?.first?.providerName == "Netflix")
        #expect(polishProviders.rent?.first?.providerName == "Apple TV")
        #expect(polishProviders.buy == nil)
    }

    @Test func decodesCountryCodeOfReleaseDates() throws {
        let details = try decodeMatrixDetails()

        #expect(details.releaseDates.results.first?.countryCode == polandRegionCode)
    }

    @Test func decodesRecommendationsAsMovies() throws {
        let recommendedMovies = try decodeMatrixDetails().recommendations.results

        let reloaded = try #require(recommendedMovies.first)
        #expect(reloaded.title == "The Matrix Reloaded")
        #expect(reloaded.releaseDate == "2003-05-15")
        #expect(reloaded.genreIds == [genreIdAdventure, genreIdAction, genreIdScienceFiction])
    }

    @Test func decodesAnnouncedMovieWithoutRuntime() throws {
        let details = try decodeTMDBMovieDetails(Data(announcedMovieDetailsJSON.utf8))

        #expect(details.runtime == nil)
        #expect(formattedRuntime(details) == "")
        #expect(!hasWatchProviders(watchProviders(details, regionCode: polandRegionCode)))
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

    @Test func directorsAreListedOnceEach() throws {
        let details = try decodeMatrixDetails()

        #expect(directorNames(details) == "Lana Wachowski, Lilly Wachowski")
    }

    @Test func directorsAreEmptyWithoutDirector() {
        let editor = CrewMember(id: 4671, name: "Zach Staenberg", job: "Editor")

        #expect(directorNames(makeMovieDetails(crew: [editor])) == "")
    }

    @Test func certificationSkipsEmptyOnes() throws {
        let details = try decodeMatrixDetails()

        #expect(ageCertification(details, regionCode: polandRegionCode) == "16")
        #expect(ageCertification(details, regionCode: unitedStatesRegionCode) == "R")
    }

    @Test func certificationIsEmptyForOtherCountry() throws {
        let details = try decodeMatrixDetails()

        #expect(ageCertification(details, regionCode: germanyRegionCode) == "")
    }

    @Test func officialTrailerWins() throws {
        let details = try decodeMatrixDetails()

        #expect(trailerKey(details) == "vKQi3bBA1y8")
    }

    @Test func unofficialTrailerWhenNoOfficial() {
        let videos = [
            Video(key: "teaser", site: "YouTube", type: "Teaser", official: true),
            Video(key: "fanTrailer", site: "YouTube", type: "Trailer", official: false),
        ]

        #expect(trailerKey(makeMovieDetails(videos: videos)) == "fanTrailer")
    }

    @Test func trailerOnOtherSiteIsSkipped() {
        let vimeoTrailer = Video(key: "123456", site: "Vimeo", type: "Trailer", official: true)
        let details = makeMovieDetails(videos: [vimeoTrailer])

        #expect(trailerKey(details) == "")
        #expect(trailerURL(details) == nil)
        #expect(!hasTrailer(details))
    }

    @Test func trailerURLPointsToYouTube() throws {
        let details = try decodeMatrixDetails()

        #expect(trailerURL(details) == URL(string: "https://www.youtube.com/watch?v=vKQi3bBA1y8"))
        #expect(hasTrailer(details))
    }

    @Test func factsLineAddsRuntimeAndCertification() throws {
        let matrix = makeMovie(releaseDate: "1999-03-31", voteAverage: 8.2)
        let details = try decodeMatrixDetails()

        let factsLine = movieFactsLine(matrix, details, regionCode: polandRegionCode)

        #expect(factsLine == "1999 · ★ 8.2 · 2h 16m · 16")
    }

    @Test func factsLineBeforeDetailsLoad() {
        let matrix = makeMovie(releaseDate: "1999-03-31", voteAverage: 8.2)

        let factsLine = movieFactsLine(matrix, emptyMovieDetails, regionCode: polandRegionCode)

        #expect(factsLine == "1999 · ★ 8.2")
    }

    @Test func profileURLIsNilWithoutPhoto() throws {
        let cast = try decodeMatrixDetails().credits.cast

        try #require(cast.count == 2)
        #expect(profileURL(cast[0]) == URL(string: tmdbProfileBaseURL + "/8RZL.jpg"))
        #expect(profileURL(cast[1]) == nil)
    }
}

@MainActor
private func decodeMatrixDetails() throws -> MovieDetails {
    return try decodeTMDBMovieDetails(Data(matrixDetailsJSON.utf8))
}

/// Details with only the given parts, the rest empty.
func makeMovieDetails(
    runtime: Int? = nil,
    crew: [CrewMember] = [],
    videos: [Video] = []
) -> MovieDetails {
    return MovieDetails(
        id: 1,
        tagline: "",
        runtime: runtime,
        credits: Credits(cast: [], crew: crew),
        videos: VideoList(results: videos),
        releaseDates: ReleaseDateList(results: []),
        watchProviders: WatchProviderList(results: [:]),
        recommendations: TMDBMoviePage(results: [])
    )
}
