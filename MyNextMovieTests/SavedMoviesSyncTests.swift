import Foundation
import SwiftData
import Testing

@testable import MyNextMovie

/// Pretends to be the `saved_movies` table of one account.
/// A class, so the closures in `SavedMoviesCloud` and the test see the same rows.
private final class TestCloud {
    var movies: [CloudSavedMovie] = []
    var isOffline = false
    /// How many rows `uploadMovies` got in total.
    var uploadedMovieCount = 0

    func fetchMovies() throws -> [CloudSavedMovie] {
        if isOffline {
            throw NoConnection()
        }
        return movies
    }

    /// Like the upsert with `ignoreDuplicates`: a movie the account has stays as it is.
    func uploadMovies(_ cloudMovies: [CloudSavedMovie]) throws {
        if isOffline {
            throw NoConnection()
        }
        uploadedMovieCount += cloudMovies.count
        for cloudMovie in cloudMovies {
            if !movieIds(movies).contains(cloudMovie.id) {
                movies.append(cloudMovie)
            }
        }
    }

    func removeMovie(_ movieId: Int) throws {
        if isOffline {
            throw NoConnection()
        }
        movies.removeAll { cloudMovie in cloudMovie.id == movieId }
    }
}

@MainActor
struct SavedMoviesSyncTests {
    @Test func movieSavedOnDeviceGoesToAccount() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        let matrix = testMovies[0]
        toggleSavedMovie(context, matrix, now: minute(1))

        try await syncSavedMovies(context, cloud: makeCloud(testCloud))

        #expect(movieIds(testCloud.movies) == [matrix.id])
        #expect(fetchSavedMovies(context, movieId: matrix.id).first?.isInCloud == true)
    }

    @Test func movieIsSentOnlyOnce() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        toggleSavedMovie(context, testMovies[0], now: minute(1))

        try await syncSavedMovies(context, cloud: makeCloud(testCloud))
        try await syncSavedMovies(context, cloud: makeCloud(testCloud))

        #expect(testCloud.uploadedMovieCount == 1)
    }

    @Test func movieFromAccountComesToDevice() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        let inception = testMovies[1]
        testCloud.movies = [makeCloudMovie(inception, savedAt: minute(5))]

        try await syncSavedMovies(context, cloud: makeCloud(testCloud))

        let savedCopy = try #require(fetchSavedMovies(context, movieId: inception.id).first)
        #expect(movieFromSaved(savedCopy) == inception)
        #expect(savedCopy.savedAt == minute(5))
        #expect(savedCopy.isInCloud)
    }

    @Test func deviceAndAccountListsAreMerged() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        let matrix = testMovies[0]
        let inception = testMovies[1]
        toggleSavedMovie(context, matrix, now: minute(1))
        testCloud.movies = [makeCloudMovie(inception, savedAt: minute(2))]

        try await syncSavedMovies(context, cloud: makeCloud(testCloud))

        #expect(Set(movieIds(testCloud.movies)) == [matrix.id, inception.id])
        #expect(Set(savedMovieIds(context)) == [matrix.id, inception.id])
    }

    @Test func movieRemovedOnDeviceIsRemovedFromAccount() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        let matrix = testMovies[0]
        toggleSavedMovie(context, matrix, now: minute(1))
        try await syncSavedMovies(context, cloud: makeCloud(testCloud))

        toggleSavedMovie(context, matrix, now: minute(2))
        try await syncSavedMovies(context, cloud: makeCloud(testCloud))

        #expect(testCloud.movies.isEmpty)
        #expect(fetchRemovalMarks(context).isEmpty)
        #expect(savedMovieIds(context).isEmpty)
    }

    @Test func movieRemovedOnAnotherDeviceIsRemovedHere() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        toggleSavedMovie(context, testMovies[0], now: minute(1))
        try await syncSavedMovies(context, cloud: makeCloud(testCloud))

        testCloud.movies = []
        try await syncSavedMovies(context, cloud: makeCloud(testCloud))

        #expect(savedMovieIds(context).isEmpty)
    }

    @Test func changesMadeOfflineAreSentWithTheNextSync() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        let matrix = testMovies[0]
        let inception = testMovies[1]
        let interstellar = testMovies[2]
        toggleSavedMovie(context, matrix, now: minute(1))
        toggleSavedMovie(context, inception, now: minute(2))
        try await syncSavedMovies(context, cloud: makeCloud(testCloud))

        testCloud.isOffline = true
        toggleSavedMovie(context, matrix, now: minute(3))
        toggleSavedMovie(context, interstellar, now: minute(4))
        await #expect(throws: NoConnection.self) {
            try await syncSavedMovies(context, cloud: makeCloud(testCloud))
        }
        #expect(Set(movieIds(testCloud.movies)) == [matrix.id, inception.id])

        testCloud.isOffline = false
        try await syncSavedMovies(context, cloud: makeCloud(testCloud))

        #expect(Set(movieIds(testCloud.movies)) == [inception.id, interstellar.id])
    }

    @Test func movieRemovedAndSavedAgainOfflineStays() async throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let testCloud = TestCloud()
        let matrix = testMovies[0]
        toggleSavedMovie(context, matrix, now: minute(1))
        try await syncSavedMovies(context, cloud: makeCloud(testCloud))

        toggleSavedMovie(context, matrix, now: minute(2))
        toggleSavedMovie(context, matrix, now: minute(3))
        try await syncSavedMovies(context, cloud: makeCloud(testCloud))

        let cloudMatrix = try #require(testCloud.movies.first)
        #expect(movieIds(testCloud.movies) == [matrix.id])
        #expect(cloudMatrix.savedAt == minute(3))
        #expect(savedMovieIds(context) == [matrix.id])
        #expect(fetchRemovalMarks(context).isEmpty)
    }
}

@MainActor
struct CloudSavedMovieTests {
    @Test func encodesColumnNamesInSnakeCase() throws {
        let cloudMovie = makeCloudMovie(testMovies[0], savedAt: minute(1))

        let json = try JSONEncoder().encode(cloudMovie)
        let columns = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])

        let snakeCaseColumns = [
            "release_date", "poster_path", "vote_average", "genre_ids", "saved_at",
        ]
        for column in snakeCaseColumns {
            #expect(columns[column] != nil, "missing column \(column)")
        }
    }

    @Test func cloudCopyKeepsEveryMovieField() throws {
        let container = try makeTestContainer()
        let context = container.mainContext
        let matrix = testMovies[0]
        toggleSavedMovie(context, matrix, now: minute(1))
        let savedCopy = try #require(fetchSavedMovies(context, movieId: matrix.id).first)

        #expect(movieFromCloud(cloudMovieFromSaved(savedCopy)) == matrix)
    }
}

/// A `SavedMoviesCloud` whose closures read and change the rows of `testCloud`.
@MainActor
private func makeCloud(_ testCloud: TestCloud) -> SavedMoviesCloud {
    return SavedMoviesCloud(
        fetchMovies: { try testCloud.fetchMovies() },
        uploadMovies: { cloudMovies in try testCloud.uploadMovies(cloudMovies) },
        removeMovie: { movieId in try testCloud.removeMovie(movieId) }
    )
}

private func makeCloudMovie(_ movie: Movie, savedAt: Date) -> CloudSavedMovie {
    return CloudSavedMovie(
        id: movie.id,
        title: movie.title,
        overview: movie.overview,
        releaseDate: movie.releaseDate,
        posterPath: movie.posterPath,
        voteAverage: movie.voteAverage,
        genreIds: movie.genreIds,
        savedAt: savedAt
    )
}

private func movieIds(_ cloudMovies: [CloudSavedMovie]) -> [Int] {
    var ids: [Int] = []
    for cloudMovie in cloudMovies {
        ids.append(cloudMovie.id)
    }
    return ids
}

@MainActor
private func savedMovieIds(_ context: ModelContext) -> [Int] {
    var ids: [Int] = []
    for savedMovie in fetchAllSavedMovies(context) {
        ids.append(savedMovie.movieId)
    }
    return ids
}
