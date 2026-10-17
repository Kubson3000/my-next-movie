import Foundation
import SwiftData

// Keeps the saved movies on the device and in the account the same.
// SwiftData is the source for the screens, the account is a copy in the cloud.
//
// The user can save or remove a movie during every `await`. So after an `await`
// the database is read again, and only movie ids are carried across it.

/// Syncs in three steps, in this order:
/// 1. Movies removed on the device are removed from the account.
/// 2. Movies from the account come to the device. Movies the account no longer has,
///    because another device removed them, leave the device.
/// 3. New movies from the device go to the account.
/// Throws when a request fails. Changes not sent yet keep their marks for the next sync.
/// `@MainActor` is the default here anyway. Written out, because without it the test target
/// sees this async function as nonisolated and refuses to pass it the main actor's context.
@MainActor
func syncSavedMovies(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    try await sendRemovedMovies(context, cloud: cloud)
    try await mergeMoviesFromAccount(context, cloud: cloud)
    try await sendNewMovies(context, cloud: cloud)
}

/// The row to send to the account.
func cloudMovieFromSaved(_ savedMovie: SavedMovie) -> CloudSavedMovie {
    return CloudSavedMovie(
        id: savedMovie.movieId,
        title: savedMovie.title,
        overview: savedMovie.overview,
        releaseDate: savedMovie.releaseDate,
        posterPath: savedMovie.posterPath,
        voteAverage: savedMovie.voteAverage,
        genreIds: savedMovie.genreIds,
        savedAt: savedMovie.savedAt
    )
}

func movieFromCloud(_ cloudMovie: CloudSavedMovie) -> Movie {
    return Movie(
        id: cloudMovie.id,
        title: cloudMovie.title,
        overview: cloudMovie.overview,
        releaseDate: cloudMovie.releaseDate,
        posterPath: cloudMovie.posterPath,
        voteAverage: cloudMovie.voteAverage,
        genreIds: cloudMovie.genreIds
    )
}

/// Step 1: removes from the account every movie with a `RemovedSavedMovie` mark,
/// then the mark. A mark stays when its request fails.
private func sendRemovedMovies(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    var removedMovieIds: [Int] = []
    for removalMark in fetchRemovalMarks(context) {
        removedMovieIds.append(removalMark.movieId)
    }
    for movieId in removedMovieIds {
        try await cloud.removeMovie(movieId)
        for removalMark in fetchRemovalMarks(context, movieId: movieId) {
            context.delete(removalMark)
        }
    }
}

/// Step 2: makes the device have what the account has.
private func mergeMoviesFromAccount(
    _ context: ModelContext,
    cloud: SavedMoviesCloud
) async throws {
    let cloudMovies = try await cloud.fetchMovies()
    removeMoviesGoneFromAccount(context, cloudMovies)
    for cloudMovie in cloudMovies {
        addMovieFromAccount(context, cloudMovie)
    }
}

/// A movie with `isInCloud` that the account no longer has was removed on another device.
private func removeMoviesGoneFromAccount(
    _ context: ModelContext,
    _ cloudMovies: [CloudSavedMovie]
) {
    var accountMovieIds = Set<Int>()
    for cloudMovie in cloudMovies {
        accountMovieIds.insert(cloudMovie.id)
    }
    for savedMovie in fetchAllSavedMovies(context) {
        if savedMovie.isInCloud && !accountMovieIds.contains(savedMovie.movieId) {
            context.delete(savedMovie)
        }
    }
}

/// A movie the device has already gets `isInCloud`. A movie with a removal mark
/// does not come back. Any other movie comes with the date it was saved in the account.
private func addMovieFromAccount(_ context: ModelContext, _ cloudMovie: CloudSavedMovie) {
    let savedCopies = fetchSavedMovies(context, movieId: cloudMovie.id)
    for savedCopy in savedCopies {
        savedCopy.isInCloud = true
    }
    if !savedCopies.isEmpty || !fetchRemovalMarks(context, movieId: cloudMovie.id).isEmpty {
        return
    }
    let movie = movieFromCloud(cloudMovie)
    context.insert(SavedMovie(movie: movie, savedAt: cloudMovie.savedAt, isInCloud: true))
}

/// Step 3: sends every movie without `isInCloud` in one request, then sets `isInCloud`.
/// A movie removed while it was being sent gets a removal mark, so it leaves the account too.
private func sendNewMovies(_ context: ModelContext, cloud: SavedMoviesCloud) async throws {
    var newCloudMovies: [CloudSavedMovie] = []
    for savedMovie in fetchMoviesNotInCloud(context) {
        newCloudMovies.append(cloudMovieFromSaved(savedMovie))
    }
    if newCloudMovies.isEmpty {
        return
    }
    try await cloud.uploadMovies(newCloudMovies)
    for sentMovie in newCloudMovies {
        markMovieSent(context, movieId: sentMovie.id)
    }
}

private func markMovieSent(_ context: ModelContext, movieId: Int) {
    let savedCopies = fetchSavedMovies(context, movieId: movieId)
    if savedCopies.isEmpty {
        markMovieRemoved(context, movieId: movieId)
    }
    for savedCopy in savedCopies {
        savedCopy.isInCloud = true
    }
}

private func fetchMoviesNotInCloud(_ context: ModelContext) -> [SavedMovie] {
    let descriptor = FetchDescriptor<SavedMovie>(
        predicate: #Predicate { savedMovie in !savedMovie.isInCloud }
    )
    return (try? context.fetch(descriptor)) ?? []
}
