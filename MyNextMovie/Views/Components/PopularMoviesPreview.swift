import SwiftUI

/// Loads popular movies from TMDB for a SwiftUI preview, then shows `content` with them.
/// Like the app, previews need the TMDB key in `Config/Secrets.xcconfig`.
///
///     #Preview {
///         PopularMoviesPreview { movies in
///             MovieCardView(movie: movies[0])
///         }
///     }
struct PopularMoviesPreview<Content: View>: View {
    @ViewBuilder let content: ([Movie]) -> Content

    @State private var state = LoadState.idle
    @State private var movies: [Movie] = []
    @State private var errorMessage = ""

    var body: some View {
        loadedContent
            .task { await loadMovies() }
    }

    @ViewBuilder
    private var loadedContent: some View {
        switch state {
        case .idle, .loading:
            ProgressView()
        case .loaded:
            content(movies)
        case .failed:
            Text(errorMessage)
        }
    }

    private func loadMovies() async {
        state = .loading
        do {
            movies = try await fetchPopularMovies()
            state = .loaded
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
        }
    }
}
