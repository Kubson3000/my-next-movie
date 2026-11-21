import Foundation
import Observation

/// Shown instead of the filters when the model found none in the sentence.
let noFiltersReason = "No filters in that sentence, so these movies match it as a title."

/// The "Ask AI" search: one sentence becomes movie filters, and the filters find movies.
/// When the model fails or finds no filters, the sentence is searched as a plain title.
/// A class only because SwiftUI's @Observable requires one.
@Observable
final class WishSearchViewModel {
    var wish = ""
    private(set) var state = LoadState.idle
    private(set) var movies: [Movie] = []
    private(set) var errorMessage = ""
    /// The checked filters of the model, `noMovieFilters` before it answers.
    private(set) var filters = noMovieFilters
    /// Why the movies come from a plain title search, "" when they come from the filters.
    private(set) var plainSearchReason = ""

    private let parseWish: MovieWishParser
    private let searchByFilters: FilteredMovieSearch
    private let searchByText: MovieSearch
    private let currentYear: Int

    init(
        parseWish: @escaping MovieWishParser,
        searchByFilters: @escaping FilteredMovieSearch,
        searchByText: @escaping MovieSearch,
        currentYear: Int = yearOfToday()
    ) {
        self.parseWish = parseWish
        self.searchByFilters = searchByFilters
        self.searchByText = searchByText
        self.currentYear = currentYear
    }

    var isPlainSearch: Bool { !plainSearchReason.isEmpty }

    var isSearching: Bool { state == .loading }

    var canSearch: Bool { !trimmedWish.isEmpty && !isSearching }

    private var trimmedWish: String { wish.trimmingCharacters(in: .whitespacesAndNewlines) }

    func search() async {
        let sentWish = trimmedWish
        if sentWish.isEmpty {
            return
        }
        state = .loading
        filters = noMovieFilters
        plainSearchReason = ""
        do {
            movies = try await findMovies(sentWish)
            state = .loaded
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
        }
    }

    /// Asks the model for filters and searches with them, or searches the sentence as a title.
    private func findMovies(_ sentWish: String) async throws -> [Movie] {
        let modelFilters: MovieFilters
        do {
            modelFilters = try await parseWish(sentWish)
        } catch {
            plainSearchReason = error.localizedDescription
            return try await searchByText(sentWish, noGenreId)
        }
        filters = validatedFilters(modelFilters, currentYear: currentYear)
        if !hasAnyFilter(filters) {
            plainSearchReason = noFiltersReason
            return try await searchByText(sentWish, noGenreId)
        }
        return try await searchByFilters(filters)
    }
}
