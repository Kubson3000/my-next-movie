/// Any function that returns movies.
/// View models take one as a parameter, so tests can pass their own movies
/// while the app passes a TMDB request.
typealias MovieLoader = () async throws -> [Movie]

/// Any function that searches movies by text and genre id. `noGenreId` means any genre.
typealias MovieSearch = (_ query: String, _ genreId: Int) async throws -> [Movie]

/// Any function that returns the details of the movie with the id.
typealias MovieDetailsLoader = (_ movieId: Int) async throws -> MovieDetails

/// Any function that turns one sentence into movie filters, e.g. with a language model.
typealias MovieWishParser =
    (_ wish: String) async throws -> MovieFilters

/// Any function that finds movies that match the filters.
typealias FilteredMovieSearch =
    (_ filters: MovieFilters) async throws -> [Movie]
