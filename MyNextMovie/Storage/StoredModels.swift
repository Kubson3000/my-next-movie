import Foundation
import SwiftData

/// Every model the app keeps in its SwiftData database.
let storedModelTypes: [any PersistentModel.Type] = [
    SavedMovie.self,
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
    /// Whether the Supabase account has the movie already. Always false until lab 5.
    var isInCloud: Bool = false

    init(movie: Movie, savedAt: Date) {
        movieId = movie.id
        title = movie.title
        overview = movie.overview
        releaseDate = movie.releaseDate
        posterPath = movie.posterPath
        voteAverage = movie.voteAverage
        genreIds = movie.genreIds
        self.savedAt = savedAt
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
