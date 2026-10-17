import SwiftUI

@main
struct MyNextMovieApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

private struct RootView: View {
    var body: some View {
        TabView {
            Tab("Movies", systemImage: symbolNameMovies) {
                movieListTab
            }
            Tab("Search", systemImage: symbolNameSearch, role: .search) {
                searchTab
            }
        }
    }

    private var movieListTab: some View {
        MovieListView(
            viewModel: MovieListViewModel(loadMovies: fetchPopularMovies),
            loadDetails: fetchMovieDetails
        )
    }

    private var searchTab: some View {
        SearchView(
            viewModel: SearchViewModel(searchMovies: searchTMDBMovies),
            loadDetails: fetchMovieDetails
        )
    }
}
