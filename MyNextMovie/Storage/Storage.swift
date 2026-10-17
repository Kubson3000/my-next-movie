import Foundation
import SwiftData

// Reading and writing the SwiftData database.
// Every function gets the context, and the ones that write a date get it as `now`,
// so tests can pass an in-memory database and fixed dates.

/// Recent Searches keeps at most this many searches.
let maxSearchHistoryCount = 10

/// Saved copies of the movie: an empty array or one copy.
func fetchSavedMovies(_ context: ModelContext, movieId: Int) -> [SavedMovie] {
    let descriptor = FetchDescriptor<SavedMovie>(
        predicate: #Predicate { savedMovie in savedMovie.movieId == movieId }
    )
    return (try? context.fetch(descriptor)) ?? []
}

func isMovieSaved(_ context: ModelContext, movieId: Int) -> Bool {
    return !fetchSavedMovies(context, movieId: movieId).isEmpty
}

/// Saves the movie, or removes it when it is saved already.
func toggleSavedMovie(_ context: ModelContext, _ movie: Movie, now: Date) {
    let savedCopies = fetchSavedMovies(context, movieId: movie.id)
    if savedCopies.isEmpty {
        context.insert(SavedMovie(movie: movie, savedAt: now))
    }
    for savedCopy in savedCopies {
        context.delete(savedCopy)
    }
}

/// The saved copy as a `Movie` again, for views and navigation.
func movieFromSaved(_ savedMovie: SavedMovie) -> Movie {
    return Movie(
        id: savedMovie.movieId,
        title: savedMovie.title,
        overview: savedMovie.overview,
        releaseDate: savedMovie.releaseDate,
        posterPath: savedMovie.posterPath,
        voteAverage: savedMovie.voteAverage,
        genreIds: savedMovie.genreIds
    )
}

func moviesFromSaved(_ savedMovies: [SavedMovie]) -> [Movie] {
    var movies: [Movie] = []
    for savedMovie in savedMovies {
        movies.append(movieFromSaved(savedMovie))
    }
    return movies
}

/// Remembers the search. Empty text is not recorded. A text that is in the history
/// already gets the new date, which moves it to the top.
func recordSearch(_ context: ModelContext, query: String, now: Date) {
    let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
    if trimmedQuery.isEmpty {
        return
    }
    let earlierEntries = fetchSearchHistoryEntries(context, query: trimmedQuery)
    if earlierEntries.isEmpty {
        context.insert(SearchHistoryEntry(query: trimmedQuery, searchedAt: now))
    }
    for earlierEntry in earlierEntries {
        earlierEntry.searchedAt = now
    }
    removeOldSearches(context)
}

/// Newest first, at most `maxSearchHistoryCount`.
func recentSearches(_ context: ModelContext) -> [SearchHistoryEntry] {
    return Array(fetchSearchHistoryNewestFirst(context).prefix(maxSearchHistoryCount))
}

/// Removes every search, one by one, because `context.delete(model:)`
/// skips searches that are not saved to disk yet.
func clearSearchHistory(_ context: ModelContext) {
    for entry in fetchSearchHistoryNewestFirst(context) {
        context.delete(entry)
    }
}

/// Keeps the `maxSearchHistoryCount` newest searches and removes the older ones.
/// Counts in a loop over the whole list, because `fetchOffset` skips searches not saved yet.
private func removeOldSearches(_ context: ModelContext) {
    for oldEntry in fetchSearchHistoryNewestFirst(context).dropFirst(maxSearchHistoryCount) {
        context.delete(oldEntry)
    }
}

private func fetchSearchHistoryEntries(
    _ context: ModelContext,
    query: String
) -> [SearchHistoryEntry] {
    let descriptor = FetchDescriptor<SearchHistoryEntry>(
        predicate: #Predicate { entry in entry.query == query }
    )
    return (try? context.fetch(descriptor)) ?? []
}

private func fetchSearchHistoryNewestFirst(_ context: ModelContext) -> [SearchHistoryEntry] {
    let descriptor = FetchDescriptor<SearchHistoryEntry>(
        sortBy: [SortDescriptor(\.searchedAt, order: .reverse)]
    )
    return (try? context.fetch(descriptor)) ?? []
}

/// Stores the JSON under the key. One key holds one response, a newer one replaces it.
func storeCachedResponse(_ context: ModelContext, key: String, data: Data, now: Date) {
    let storedResponses = fetchCachedResponses(context, key: key)
    if storedResponses.isEmpty {
        context.insert(CachedResponse(key: key, data: data, fetchedAt: now))
    }
    for storedResponse in storedResponses {
        storedResponse.data = data
        storedResponse.fetchedAt = now
    }
}

/// The JSON stored under the key, empty `Data()` when there is none.
func cachedResponseData(_ context: ModelContext, key: String) -> Data {
    return fetchCachedResponses(context, key: key).first?.data ?? Data()
}

/// Fresh data from `fetch`, which is also stored under the key.
/// When `fetch` fails, the data stored earlier. When there is none, the error from `fetch`.
/// `@MainActor` is the default here anyway. Written out, because without it the test target
/// sees this async function as nonisolated and refuses to pass it the main actor's context.
@MainActor
func fetchWithCacheFallback(
    _ context: ModelContext,
    key: String,
    fetch: () async throws -> Data
) async throws -> Data {
    do {
        let freshData = try await fetch()
        storeCachedResponse(context, key: key, data: freshData, now: Date.now)
        return freshData
    } catch {
        let cachedData = cachedResponseData(context, key: key)
        if cachedData.isEmpty {
            throw error
        }
        return cachedData
    }
}

private func fetchCachedResponses(_ context: ModelContext, key: String) -> [CachedResponse] {
    let descriptor = FetchDescriptor<CachedResponse>(
        predicate: #Predicate { cachedResponse in cachedResponse.key == key }
    )
    return (try? context.fetch(descriptor)) ?? []
}
