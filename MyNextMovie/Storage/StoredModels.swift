import Foundation
import SwiftData

/// Every model the app keeps in its SwiftData database.
let storedModelTypes: [any PersistentModel.Type] = [
    SavedMovie.self,
    RemovedSavedMovie.self,
    SearchHistoryEntry.self,
    CachedResponse.self,
]

/// A movie on the Watch Later list. It keeps every field of `Movie`,
/// so the Saved tab works without the network.
@Model
final class SavedMovie {
    @Attribute(.unique) var movieId: Int
    var title: String
    var overview: String
    var releaseDate: String
    var posterPath: String?
    var voteAverage: Double
    var genreIds: [Int]
    var savedAt: Date
    /// Whether the Supabase account has the movie already.
    var isInCloud: Bool = false

    init(movie: Movie, savedAt: Date, isInCloud: Bool) {
        movieId = movie.id
        title = movie.title
        overview = movie.overview
        releaseDate = movie.releaseDate
        posterPath = movie.posterPath
        voteAverage = movie.voteAverage
        genreIds = movie.genreIds
        self.savedAt = savedAt
        self.isInCloud = isInCloud
    }
}

/// A mark that the movie was removed on the device but not from the account yet.
/// The next sync removes the movie from the account, then the mark.
/// Without it, a movie removed offline would come back from the account.
@Model
final class RemovedSavedMovie {
    @Attribute(.unique) var movieId: Int

    init(movieId: Int) {
        self.movieId = movieId
    }
}

/// A text the user searched for. Searching for it again only updates the date.
@Model
final class SearchHistoryEntry {
    @Attribute(.unique) var query: String
    var searchedAt: Date

    init(query: String, searchedAt: Date) {
        self.query = query
        self.searchedAt = searchedAt
    }
}

/// The last TMDB response for a request, shown when the next request fails.
/// Keeps the raw JSON, so it decodes again after the Swift structures change.
@Model
final class CachedResponse {
    @Attribute(.unique) var key: String
    var data: Data
    var fetchedAt: Date

    init(key: String, data: Data, fetchedAt: Date) {
        self.key = key
        self.data = data
        self.fetchedAt = fetchedAt
    }
}
