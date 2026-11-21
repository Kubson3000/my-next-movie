import Testing

@testable import MyNextMovie

/// The tests pass their own year, so they work in any year.
private let testYear = 2026

private let keanuWish = "something light with Keanu from the 90s"

/// What the model makes of `keanuWish`.
@MainActor private let keanuFilters = MovieFilters(
    genreIds: [genreIdComedy], fromYear: 1990, toYear: 1999,
    people: ["Keanu Reeves"], keywords: [], title: "")

/// Records what the view model passes to its functions.
@MainActor
private final class SearchCalls {
    var parsedWishes: [String] = []
    var searchedFilters: [MovieFilters] = []
    var searchedTexts: [String] = []
    var searchedGenreIds: [Int] = []
}

@MainActor
struct WishSearchViewModelTests {
    @Test func searchesWithTheFiltersOfTheModel() async {
        let calls = SearchCalls()
        let viewModel = makeViewModel(calls, modelAnswer: { keanuFilters })
        viewModel.wish = keanuWish

        await viewModel.search()

        #expect(calls.parsedWishes == [keanuWish])
        #expect(calls.searchedFilters == [keanuFilters])
        #expect(calls.searchedTexts.isEmpty)
        #expect(viewModel.state == .loaded)
        #expect(viewModel.movies == [testMovies[0]])
        #expect(viewModel.filters == keanuFilters)
        #expect(!viewModel.isPlainSearch)
    }

    @Test func checksTheModelAnswerBeforeSearching() async {
        let calls = SearchCalls()
        let modelFilters = MovieFilters(
            genreIds: [genreIdComedy, 999], fromYear: 1999, toYear: 1990,
            people: [" Keanu Reeves ", ""], keywords: [], title: "")
        let viewModel = makeViewModel(calls, modelAnswer: { modelFilters })
        viewModel.wish = keanuWish

        await viewModel.search()

        #expect(calls.searchedFilters == [keanuFilters])
        #expect(viewModel.filters == keanuFilters)
    }

    @Test func fallsBackToTextSearchWhenTheModelFails() async {
        let calls = SearchCalls()
        let viewModel = makeViewModel(calls, modelAnswer: { throw NoConnection() })
        viewModel.wish = "  the matrix \n"

        await viewModel.search()

        #expect(calls.parsedWishes == ["the matrix"])
        #expect(calls.searchedFilters.isEmpty)
        #expect(calls.searchedTexts == ["the matrix"])
        #expect(calls.searchedGenreIds == [noGenreId])
        #expect(viewModel.state == .loaded)
        #expect(viewModel.movies == [testMovies[1]])
        #expect(viewModel.isPlainSearch)
        #expect(viewModel.plainSearchReason == "No connection")
    }

    @Test func fallsBackToTextSearchWithoutFilters() async {
        let calls = SearchCalls()
        let unknownGenreOnly = MovieFilters(
            genreIds: [999], fromYear: noYear, toYear: noYear, people: [], keywords: [], title: "")
        let viewModel = makeViewModel(calls, modelAnswer: { unknownGenreOnly })
        viewModel.wish = "hmm"

        await viewModel.search()

        #expect(calls.searchedFilters.isEmpty)
        #expect(calls.searchedTexts == ["hmm"])
        #expect(viewModel.isPlainSearch)
        #expect(viewModel.plainSearchReason == noFiltersReason)
        #expect(viewModel.movies == [testMovies[1]])
    }

    @Test func showsErrorWhenTheMovieSearchFails() async {
        let viewModel = WishSearchViewModel(
            parseWish: { _ in keanuFilters },
            searchByFilters: { _ in throw NoConnection() },
            searchByText: { _, _ in [] },
            currentYear: testYear)
        viewModel.wish = keanuWish

        await viewModel.search()

        #expect(viewModel.state == .failed)
        #expect(viewModel.errorMessage == "No connection")
    }

    @Test func emptyWishDoesNothing() async {
        let calls = SearchCalls()
        let viewModel = makeViewModel(calls, modelAnswer: { keanuFilters })
        viewModel.wish = "  \n "
        #expect(!viewModel.canSearch)

        await viewModel.search()

        #expect(calls.parsedWishes.isEmpty)
        #expect(viewModel.state == .idle)
        viewModel.wish = keanuWish
        #expect(viewModel.canSearch)
    }

    @Test func nextSearchForgetsThePlainSearchReason() async {
        let calls = SearchCalls()
        // The model is down for the first wish and answers the second one.
        let modelAnswer: @MainActor () throws -> MovieFilters = {
            if calls.parsedWishes.count == 1 {
                throw NoConnection()
            }
            return keanuFilters
        }
        let viewModel = makeViewModel(calls, modelAnswer: modelAnswer)
        viewModel.wish = keanuWish
        await viewModel.search()
        #expect(viewModel.isPlainSearch)

        await viewModel.search()

        #expect(!viewModel.isPlainSearch)
        #expect(viewModel.plainSearchReason.isEmpty)
        #expect(viewModel.filters == keanuFilters)
    }
}

/// A view model whose model answers with `modelAnswer`, whose filter search returns
/// The Matrix and whose text search returns Inception. `calls` records every call.
@MainActor
private func makeViewModel(
    _ calls: SearchCalls, modelAnswer: @escaping @MainActor () throws -> MovieFilters
) -> WishSearchViewModel {
    return WishSearchViewModel(
        parseWish: { wish in
            calls.parsedWishes.append(wish)
            return try modelAnswer()
        },
        searchByFilters: { filters in
            calls.searchedFilters.append(filters)
            return [testMovies[0]]
        },
        searchByText: { query, genreId in
            calls.searchedTexts.append(query)
            calls.searchedGenreIds.append(genreId)
            return [testMovies[1]]
        },
        currentYear: testYear
    )
}
