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

/// Owns the database context. Wraps the functions that need it, so the view models
/// still get plain function types: the TMDB requests with a cache, the sync and the clearing.
private struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        AppTabs(
            account: makeAccountViewModel(),
            loadPopularMovies: loadPopularMoviesWithCache,
            loadDetails: loadDetailsWithCache
        )
    }

    private func makeAccountViewModel() -> AccountViewModel {
        let viewModel = AccountViewModel(
            account: supabaseAccountService,
            syncSavedMovies: syncSavedMoviesWithAccount,
            clearSavedMovies: clearSavedMoviesOnDevice
        )
        // Debug builds fill the sign in screen with the test account. Release builds
        // do not contain this code at all.
        #if DEBUG
            viewModel.email = testAccountEmail
            viewModel.password = testAccountPassword
        #endif
        return viewModel
    }

    /// Has the type `MovieLoader`.
    private func loadPopularMoviesWithCache() async throws -> [Movie] {
        return try await loadPopularMovies(cache: modelContext)
    }

    /// Has the type `MovieDetailsLoader`.
    private func loadDetailsWithCache(movieId: Int) async throws -> MovieDetails {
        return try await loadTMDBMovieDetails(movieId: movieId, cache: modelContext)
    }

    private func syncSavedMoviesWithAccount() async throws {
        try await syncSavedMovies(modelContext, cloud: supabaseSavedMoviesCloud)
    }

    private func clearSavedMoviesOnDevice() {
        clearSavedMovies(modelContext)
    }
}

/// The tabs for a signed-in user, the sign in screen otherwise.
/// Also decides when to sync the saved movies with the account.
private struct AppTabs: View {
    @State private var account: AccountViewModel
    private let loadPopularMovies: MovieLoader
    private let loadDetails: MovieDetailsLoader

    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<SavedMovie> { savedMovie in !savedMovie.isInCloud })
    private var moviesNotInCloud: [SavedMovie]
    @Query private var removedMovies: [RemovedSavedMovie]

    init(
        account: AccountViewModel,
        loadPopularMovies: @escaping MovieLoader,
        loadDetails: @escaping MovieDetailsLoader
    ) {
        _account = State(initialValue: account)
        self.loadPopularMovies = loadPopularMovies
        self.loadDetails = loadDetails
    }

    var body: some View {
        content
            .task { await account.syncSavedMovies() }
            .onChange(of: scenePhase) { _, newPhase in syncWhenActive(newPhase) }
            .onChange(of: unsentChangeCount) { oldCount, newCount in
                syncWhenChangesGrow(from: oldCount, to: newCount)
            }
    }

    @ViewBuilder
    private var content: some View {
        if account.isSignedIn {
            tabs
        } else {
            SignInView(viewModel: account)
        }
    }

    private var tabs: some View {
        TabView {
            Tab("Movies", systemImage: symbolNameMovies) {
                movieListTab
            }
            Tab("Saved", systemImage: symbolNameSaved) {
                SavedMoviesView(loadDetails: loadDetails)
            }
            Tab("Account", systemImage: symbolNameAccount) {
                AccountView(viewModel: account)
            }
            Tab("Search", systemImage: symbolNameSearch, role: .search) {
                searchTab
            }
        }
    }

    private var movieListTab: some View {
        MovieListView(
            viewModel: MovieListViewModel(loadMovies: loadPopularMovies),
            loadDetails: loadDetails
        )
    }

    private var searchTab: some View {
        SearchView(
            viewModel: SearchViewModel(searchMovies: searchTMDBMovies),
            loadDetails: loadDetails
        )
    }

    /// Saved movies not sent to the account yet, plus removals not sent yet.
    private var unsentChangeCount: Int {
        moviesNotInCloud.count + removedMovies.count
    }

    /// The user came back to the app, maybe after changes on another device.
    private func syncWhenActive(_ phase: ScenePhase) {
        if phase == .active {
            startSync()
        }
    }

    /// More unsent changes mean the user saved or removed a movie.
    /// Fewer mean a sync sent them, which needs no other sync.
    private func syncWhenChangesGrow(from oldCount: Int, to newCount: Int) {
        if newCount > oldCount {
            startSync()
        }
    }

    private func startSync() {
        Task { await account.syncSavedMovies() }
    }
}
