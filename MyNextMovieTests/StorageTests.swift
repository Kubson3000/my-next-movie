import Foundation
import SwiftData
import Testing

@testable import MyNextMovie

/// Fixed dates, so every test knows which one is newer.
private let firstDate = Date(timeIntervalSince1970: 0)
private let secondsPerMinute: TimeInterval = 60

private let popularMoviesCacheKey = "popular"
private let olderJSON = Data(#"{"page": 1}"#.utf8)
private let newerJSON = Data(#"{"page": 2}"#.utf8)

/// A new, empty database in memory. Keep the container in a variable until the test ends.
@MainActor
func makeTestContainer() throws -> ModelContainer {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: Schema(storedModelTypes), configurations: [configuration])
}

@MainActor
struct SavedMovieTests {
    @Test func toggleSavesThenRemoves() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let matrix = testMovies[0]

        toggleSavedMovie(context, matrix, now: minute(1))
        #expect(isMovieSaved(context, movieId: matrix.id))

        toggleSavedMovie(context, matrix, now: minute(2))
        #expect(!isMovieSaved(context, movieId: matrix.id))
    }

    @Test func savedCopyKeepsEveryField() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let matrix = testMovies[0]

        toggleSavedMovie(context, matrix, now: minute(1))
        let savedMovies = try context.fetch(FetchDescriptor<SavedMovie>())

        #expect(moviesFromSaved(savedMovies) == [matrix])
    }
}

@MainActor
struct SearchHistoryTests {
    @Test func newestSearchComesFirst() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "matrix", now: minute(1))
        recordSearch(context, query: "alien", now: minute(2))

        #expect(queriesOf(recentSearches(context)) == ["alien", "matrix"])
    }

    @Test func repeatedSearchMovesToTop() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "matrix", now: minute(1))
        recordSearch(context, query: "alien", now: minute(2))
        recordSearch(context, query: "matrix", now: minute(3))

        #expect(queriesOf(recentSearches(context)) == ["matrix", "alien"])
    }

    @Test func emptyAndSpacesAreNotRecorded() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        recordSearch(context, query: "", now: minute(1))
        recordSearch(context, query: "   ", now: minute(2))
        recordSearch(context, query: "  dune  ", now: minute(3))

        #expect(queriesOf(recentSearches(context)) == ["dune"])
    }

    @Test func keepsOnlyRecentSearches() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let searchCount = 13

        for searchNumber in 1...searchCount {
            recordSearch(context, query: "movie " + String(searchNumber), now: minute(searchNumber))
        }
        let storedEntries = try context.fetch(FetchDescriptor<SearchHistoryEntry>())

        #expect(storedEntries.count == maxSearchHistoryCount)
        #expect(recentSearches(context).first?.query == "movie " + String(searchCount))
    }

    @Test func clearRemovesEverything() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        recordSearch(context, query: "matrix", now: minute(1))
        recordSearch(context, query: "alien", now: minute(2))

        clearSearchHistory(context)

        #expect(recentSearches(context).isEmpty)
    }
}

@MainActor
struct ResponseCacheTests {
    @Test func missingKeyGivesEmptyData() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        #expect(cachedResponseData(context, key: popularMoviesCacheKey).isEmpty)
    }

    @Test func storingAgainReplacesData() throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        storeCachedResponse(context, key: popularMoviesCacheKey, data: olderJSON, now: minute(1))
        storeCachedResponse(context, key: popularMoviesCacheKey, data: newerJSON, now: minute(2))

        #expect(cachedResponseData(context, key: popularMoviesCacheKey) == newerJSON)
        #expect(try context.fetchCount(FetchDescriptor<CachedResponse>()) == 1)
    }

    @Test func freshAnswerIsReturnedAndCached() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        let data = try await fetchWithCacheFallback(context, key: popularMoviesCacheKey) {
            newerJSON
        }

        #expect(data == newerJSON)
        #expect(cachedResponseData(context, key: popularMoviesCacheKey) == newerJSON)
    }

    @Test func cachedAnswerIsReturnedWhenOffline() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        storeCachedResponse(context, key: popularMoviesCacheKey, data: olderJSON, now: minute(1))

        let data = try await fetchWithCacheFallback(context, key: popularMoviesCacheKey) {
            throw NoConnection()
        }

        #expect(data == olderJSON)
    }

    @Test func errorIsRethrownWhenNothingCached() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext

        await #expect(throws: NoConnection.self) {
            try await fetchWithCacheFallback(context, key: popularMoviesCacheKey) {
                throw NoConnection()
            }
        }
    }
}

/// `firstDate` plus the minutes.
private func minute(_ minutes: Int) -> Date {
    return firstDate.addingTimeInterval(secondsPerMinute * TimeInterval(minutes))
}

@MainActor
private func queriesOf(_ entries: [SearchHistoryEntry]) -> [String] {
    var queries: [String] = []
    for entry in entries {
        queries.append(entry.query)
    }
    return queries
}
