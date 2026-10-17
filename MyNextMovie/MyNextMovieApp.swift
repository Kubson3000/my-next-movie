import SwiftData
import SwiftUI

@main
struct MyNextMovieApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: storedModelTypes)
    }
}

/// Owns the database context. Wraps the TMDB requests that cache their responses
/// in it, so the view models still get plain `MovieLoader` and `MovieDetailsLoader`.
private struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            Tab("Movies", systemImage: symbolNameMovies) {
                movieListTab
            }
            Tab("Saved", systemImage: symbolNameSaved) {
                savedMoviesTab
            }
            Tab("Search", systemImage: symbolNameSearch, role: .search) {
                searchTab
            }
        }
    }

    private var movieListTab: some View {
        MovieListView(
            viewModel: MovieListViewModel(loadMovies: loadPopularMoviesWithCache),
            loadDetails: loadDetailsWithCache
        )
    }

    private var savedMoviesTab: some View {
        SavedMoviesView(loadDetails: loadDetailsWithCache)
    }

    private var searchTab: some View {
        SearchView(
            viewModel: SearchViewModel(searchMovies: searchTMDBMovies),
            loadDetails: loadDetailsWithCache
        )
    }

    /// Has the type `MovieLoader`.
    private func loadPopularMoviesWithCache() async throws -> [Movie] {
        return try await loadPopularMovies(cache: modelContext)
    }

    /// Has the type `MovieDetailsLoader`.
    private func loadDetailsWithCache(movieId: Int) async throws -> MovieDetails {
        return try await loadTMDBMovieDetails(movieId: movieId, cache: modelContext)
    }
}
