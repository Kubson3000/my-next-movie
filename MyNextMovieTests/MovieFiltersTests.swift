import Foundation
import Testing

@testable import MyNextMovie

/// The tests pass their own year, so they work in any year.
private let testYear = 2026

private let keanuReevesId = 6384
private let carrieAnneMossId = 530
private let heistKeywordId = 10051
private let virtualRealityKeywordId = 4565

/// What the model makes of "something light with Keanu from the 90s".
@MainActor private let keanuFilters = MovieFilters(
    genreIds: [genreIdComedy], fromYear: 1990, toYear: 1999,
    people: ["Keanu Reeves"], keywords: [], title: "")

/// The example answer from supabase/functions/movie-filters/index.ts.
private let functionAnswerJSON = """
    {"genreIds": [35], "fromYear": 1990, "toYear": 1999,
     "people": ["Keanu Reeves"], "keywords": [], "title": ""}
    """

/// A shortened response of `/3/search/person`, best match first.
private let keanuSearchJSON = """
    {
      "page": 1,
      "results": [
        {"id": 6384, "name": "Keanu Reeves"},
        {"id": 1000001, "name": "Keanu Pires"}
      ]
    }
    """

private let nothingFoundJSON = """
    {"page": 1, "results": []}
    """

@MainActor
struct MovieFiltersValidationTests {
    @Test func keepsValidFilters() {
        let filters = MovieFilters(
            genreIds: [genreIdComedy, genreIdAction], fromYear: 1990, toYear: 1999,
            people: ["Keanu Reeves"], keywords: ["heist"], title: "")

        #expect(validatedFilters(filters, currentYear: testYear) == filters)
    }

    @Test func dropsUnknownAndRepeatedGenres() {
        let filters = filtersWith(genreIds: [genreIdComedy, 999, genreIdComedy, genreIdAction])

        let checkedFilters = validatedFilters(filters, currentYear: testYear)

        #expect(checkedFilters.genreIds == [genreIdComedy, genreIdAction])
    }

    @Test func keepsAtMostThreeOfEach() {
        let filters = MovieFilters(
            genreIds: [genreIdAction, genreIdAdventure, genreIdAnimation, genreIdComedy],
            fromYear: noYear, toYear: noYear,
            people: ["Keanu Reeves", "Carrie-Anne Moss", "Laurence Fishburne", "Hugo Weaving"],
            keywords: ["heist", "ghost", "time travel", "robot"], title: "")

        let checkedFilters = validatedFilters(filters, currentYear: testYear)

        #expect(checkedFilters.genreIds == [genreIdAction, genreIdAdventure, genreIdAnimation])
        #expect(
            checkedFilters.people == ["Keanu Reeves", "Carrie-Anne Moss", "Laurence Fishburne"])
        #expect(checkedFilters.keywords == ["heist", "ghost", "time travel"])
    }

    @Test func dropsYearsOutOfRange() {
        let outOfRange = validatedFilters(
            filtersWith(fromYear: 1879, toYear: 2032), currentYear: testYear)
        let firstAndLast = validatedFilters(
            filtersWith(fromYear: 1880, toYear: 2031), currentYear: testYear)

        #expect(outOfRange.fromYear == noYear)
        #expect(outOfRange.toYear == noYear)
        #expect(firstAndLast.fromYear == earliestMovieYear)
        #expect(firstAndLast.toYear == testYear + yearsAheadOfToday)
    }

    @Test func swapsYearsInWrongOrder() {
        let checkedFilters = validatedFilters(
            filtersWith(fromYear: 1999, toYear: 1990), currentYear: testYear)

        #expect(checkedFilters.fromYear == 1990)
        #expect(checkedFilters.toYear == 1999)
    }

    @Test func trimsAndDropsEmptyOrRepeatedNames() {
        let filters = MovieFilters(
            genreIds: [], fromYear: noYear, toYear: noYear,
            people: [" Keanu Reeves ", "", "  ", "keanu reeves", "Carrie-Anne Moss\n"],
            keywords: ["heist", "Heist", " "], title: "  The Matrix \n")

        let checkedFilters = validatedFilters(filters, currentYear: testYear)

        #expect(checkedFilters.people == ["Keanu Reeves", "Carrie-Anne Moss"])
        #expect(checkedFilters.keywords == ["heist"])
        #expect(checkedFilters.title == "The Matrix")
    }

    @Test func emptyFiltersHaveNoFilter() {
        #expect(!hasAnyFilter(noMovieFilters))
        #expect(validatedFilters(noMovieFilters, currentYear: testYear) == noMovieFilters)
        #expect(hasAnyFilter(filtersWith(toYear: 1999)))
    }

    @Test func onlyUnknownGenresLeaveNoFilter() {
        let filters = MovieFilters(
            genreIds: [999, noGenreId], fromYear: 1500, toYear: noYear,
            people: [" "], keywords: [""], title: " ")

        #expect(!hasAnyFilter(validatedFilters(filters, currentYear: testYear)))
    }
}

@MainActor
struct MovieFiltersTextTests {
    @Test func summaryListsEveryFilter() {
        let filters = MovieFilters(
            genreIds: [genreIdComedy, genreIdAction], fromYear: 1990, toYear: 1999,
            people: ["Keanu Reeves"], keywords: ["heist"], title: "Speed")

        #expect(
            filtersSummary(filters)
                == "Speed \u{00B7} Comedy \u{00B7} Action \u{00B7} 1990\u{2013}1999"
                + " \u{00B7} Keanu Reeves \u{00B7} heist")
        #expect(filtersSummary(noMovieFilters).isEmpty)
    }

    @Test func yearRangeTextCoversEveryCase() {
        #expect(yearRangeText(fromYear: 1990, toYear: 1999) == "1990\u{2013}1999")
        #expect(yearRangeText(fromYear: 1990, toYear: noYear) == "1990 or later")
        #expect(yearRangeText(fromYear: noYear, toYear: 1999) == "up to 1999")
        #expect(yearRangeText(fromYear: 1995, toYear: 1995) == "1995")
        #expect(yearRangeText(fromYear: noYear, toYear: noYear).isEmpty)
    }

    @Test func decodesAnswerOfTheFunction() throws {
        let filters = try JSONDecoder().decode(
            MovieFilters.self, from: Data(functionAnswerJSON.utf8))

        #expect(filters == keanuFilters)
    }

    @Test func errorAnswerShowsItsMessage() {
        let limitMessage = "You can ask 50 times a day. Try again tomorrow."
        let limitAnswer = Data(#"{"message": "\#(limitMessage)"}"#.utf8)
        let answerWithoutMessage = Data("Internal error".utf8)

        #expect(functionErrorMessage(statusCode: 429, data: limitAnswer) == limitMessage)
        #expect(functionErrorMessage(statusCode: 500, data: answerWithoutMessage).contains("500"))
    }
}

@MainActor
struct DiscoverRequestTests {
    @Test func withoutFiltersHasNoParameters() {
        let request = tmdbDiscoverRequest(noMovieFilters, personIds: [], keywordIds: [])

        #expect(request == TMDBRequest(path: "/3/discover/movie", parameters: []))
    }

    @Test func anyGenreAndKeywordButEveryPerson() {
        let request = tmdbDiscoverRequest(
            filtersWith(genreIds: [genreIdComedy, genreIdAction]),
            personIds: [keanuReevesId, carrieAnneMossId],
            keywordIds: [heistKeywordId, virtualRealityKeywordId])

        #expect(parameterValue(request, name: "with_genres") == "35|28")
        #expect(parameterValue(request, name: "with_people") == "6384,530")
        #expect(parameterValue(request, name: "with_keywords") == "10051|4565")
    }

    @Test func yearsCoverWholeYears() {
        let bothYears = tmdbDiscoverRequest(
            filtersWith(fromYear: 1990, toYear: 1999), personIds: [], keywordIds: [])
        let onlyFromYear = tmdbDiscoverRequest(
            filtersWith(fromYear: 1990), personIds: [], keywordIds: [])

        #expect(parameterValue(bothYears, name: "primary_release_date.gte") == "1990-01-01")
        #expect(parameterValue(bothYears, name: "primary_release_date.lte") == "1999-12-31")
        #expect(onlyFromYear.parameters.count == 1)
    }

    @Test func nameSearchSendsTheName() {
        let request = tmdbNameSearchRequest(path: tmdbPathSearchPeople, name: "Keanu Reeves")

        #expect(request.path == "/3/search/person")
        #expect(request.parameters == [URLQueryItem(name: "query", value: "Keanu Reeves")])
    }

    @Test func firstIdIsTheBestMatch() throws {
        #expect(try decodeFirstTMDBId(Data(keanuSearchJSON.utf8)) == keanuReevesId)
        #expect(try decodeFirstTMDBId(Data(nothingFoundJSON.utf8)) == noTMDBId)
    }
}

/// Filters with only the given values set. FilteredSearchTests uses it too.
@MainActor
func filtersWith(genreIds: [Int] = [], fromYear: Int = noYear, toYear: Int = noYear)
    -> MovieFilters
{
    return MovieFilters(
        genreIds: genreIds, fromYear: fromYear, toYear: toYear, people: [], keywords: [], title: "")
}

/// Value of the parameter, "" when the request does not have it.
func parameterValue(_ request: TMDBRequest, name: String) -> String {
    for parameter in request.parameters {
        if parameter.name == name {
            return parameter.value ?? ""
        }
    }
    return ""
}
