import SwiftData
import SwiftUI

/// How long to wait after the last keystroke before searching.
private let searchDelayAfterTyping = Duration.milliseconds(300)

private let searchInputKeySeparator = "|"

/// The movie-filters function refuses longer text. Counted in Unicode scalars, like there.
private let maxWishLength = 200

/// Shown above the spinner until the AI answers with filters.
private let askingAIText = "Asking AI..."

struct SearchView: View {
    @State private var viewModel: SearchViewModel
    @State private var wishViewModel: WishSearchViewModel
    /// Whether the list shows the movies of "Ask AI" instead of the plain search.
    @State private var isShowingAIResults = false
    private let loadDetails: MovieDetailsLoader

    @Environment(\.modelContext) private var modelContext

    init(
        viewModel: SearchViewModel,
        wishViewModel: WishSearchViewModel,
        loadDetails: @escaping MovieDetailsLoader
    ) {
        _viewModel = State(initialValue: viewModel)
        _wishViewModel = State(initialValue: wishViewModel)
        self.loadDetails = loadDetails
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                genreFilter
                wishBar
                content.frame(maxHeight: .infinity)
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Title or keyword")
            .onSubmit(of: .search, askAI)
            .onChange(of: viewModel.query) {
                isShowingAIResults = false
            }
            .onChange(of: viewModel.selectedGenreId) {
                isShowingAIResults = false
            }
            .navigationDestination(for: Movie.self) { movie in movieDetail(movie) }
            .task(id: searchInputKey(viewModel.query, viewModel.selectedGenreId)) {
                await searchAfterPause()
            }
        }
    }

    private func movieDetail(_ movie: Movie) -> some View {
        MovieDetailView(movie: movie, loadDetails: loadDetails)
    }

    private var genreFilter: some View {
        GenreFilter(selectedGenreId: viewModel.selectedGenreId, toggleGenre: viewModel.toggleGenre)
    }

    /// "Ask AI" while there is text in the field. After asking, a grey line instead:
    /// the filters the AI found, or why the movies come from a title search.
    @ViewBuilder
    private var wishBar: some View {
        if isShowingAIResults {
            wishSummary
        } else if !viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
            askAIButton
        }
    }

    private var askAIButton: some View {
        Button("Ask AI", systemImage: symbolNameWish, action: askAI)
            .buttonStyle(.bordered)
            .disabled(wishViewModel.isSearching)
            .padding(.bottom, spacingSmall)
    }

    private var wishSummary: some View {
        Label(wishSummaryText, systemImage: symbolNameWish)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.bottom, spacingSmall)
    }

    private var wishSummaryText: String {
        if wishViewModel.isPlainSearch {
            return wishViewModel.plainSearchReason
        }
        if wishViewModel.isSearching && !hasAnyFilter(wishViewModel.filters) {
            return askingAIText
        }
        return filtersSummary(wishViewModel.filters)
    }

    @ViewBuilder
    private var content: some View {
        if isShowingAIResults {
            wishResults
        } else {
            plainResults
        }
    }

    @ViewBuilder
    private var plainResults: some View {
        switch viewModel.state {
        case .idle:
            SearchStartView(selectQuery: selectRecentSearch)
        case .loading:
            ProgressView()
        case .loaded:
            SearchResults(movies: viewModel.movies, query: viewModel.query)
        case .failed:
            ErrorView(title: "Search failed", message: viewModel.errorMessage) {
                Task { await viewModel.search() }
            }
        }
    }

    /// Idle only for a moment, before the search task starts.
    @ViewBuilder
    private var wishResults: some View {
        switch wishViewModel.state {
        case .idle, .loading:
            ProgressView()
        case .loaded:
            SearchResults(movies: wishViewModel.movies, query: wishViewModel.wish)
        case .failed:
            ErrorView(title: "AI search failed", message: wishViewModel.errorMessage) {
                Task { await wishViewModel.search() }
            }
        }
    }

    /// The "Ask AI" button and the Search key on the keyboard both run it.
    /// Does nothing while the AI still answers the last wish.
    private func askAI() {
        recordCurrentSearch()
        wishViewModel.wish = String(viewModel.query.unicodeScalars.prefix(maxWishLength))
        if !wishViewModel.canSearch {
            return
        }
        isShowingAIResults = true
        Task { await wishViewModel.search() }
    }

    /// Runs when the user asks AI, with the button or the Search key on the keyboard.
    /// Recording every keystroke would fill the history with "m", "ma", "mat".
    private func recordCurrentSearch() {
        recordSearch(modelContext, query: viewModel.query, now: Date.now)
    }

    /// Puts a recent search into the search field, which starts the search,
    /// and moves it to the top of the history.
    private func selectRecentSearch(_ query: String) {
        viewModel.query = query
        recordSearch(modelContext, query: query, now: Date.now)
    }

    /// Waits until the user stops typing. Every keystroke cancels the previous wait.
    private func searchAfterPause() async {
        try? await Task.sleep(for: searchDelayAfterTyping)
        if Task.isCancelled {
            return
        }
        await viewModel.search()
    }
}

/// Changes whenever the search input changes, which restarts the search task.
private func searchInputKey(_ query: String, _ selectedGenreId: Int) -> String {
    return String(selectedGenreId) + searchInputKeySeparator + query
}

/// Every genre from `genreTable` as a chip in one row that scrolls sideways.
/// Tapping a chip selects its genre, tapping it again clears the selection.
private struct GenreFilter: View {
    let selectedGenreId: Int
    let toggleGenre: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            chips
        }
    }

    private var chips: some View {
        HStack(spacing: spacingSmall) {
            ForEach(genreTable) { genre in
                genreFilterChip(genre.id)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, spacingSmall)
    }

    private func genreFilterChip(_ genreId: Int) -> some View {
        Button {
            toggleGenre(genreId)
        } label: {
            GenreChip(genreId: genreId, isSelected: genreId == selectedGenreId)
        }
        .buttonStyle(.plain)
    }
}

/// What the tab shows before a search: recent searches, or a hint when there are none.
private struct SearchStartView: View {
    let selectQuery: (String) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SearchHistoryEntry.searchedAt, order: .reverse)
    private var searchHistory: [SearchHistoryEntry]

    @ViewBuilder
    var body: some View {
        if searchHistory.isEmpty {
            ContentUnavailableView(
                "Find a movie",
                systemImage: symbolNameSearch,
                description: Text("Search by title or keyword, or pick a genre.")
            )
        } else {
            recentSearchList
        }
    }

    private var recentSearchList: some View {
        List {
            Section {
                recentSearchRows
            } header: {
                recentSearchesHeader
            }
        }
        .listStyle(.plain)
    }

    private var recentSearchRows: some View {
        ForEach(searchHistory.prefix(maxSearchHistoryCount)) { entry in
            RecentSearchRow(query: entry.query, selectQuery: selectQuery)
        }
    }

    private var recentSearchesHeader: some View {
        HStack {
            Text("Recent Searches")
            Spacer()
            Button("Clear") {
                clearSearchHistory(modelContext)
            }
        }
    }
}

/// One recent search. Tapping it searches for it again.
private struct RecentSearchRow: View {
    let query: String
    let selectQuery: (String) -> Void

    var body: some View {
        Button {
            selectQuery(query)
        } label: {
            Label(query, systemImage: symbolNameRecentSearch)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    SearchView(
        viewModel: SearchViewModel(searchMovies: searchTMDBMovies),
        wishViewModel: WishSearchViewModel(
            parseWish: parseWishWithAI,
            searchByFilters: searchTMDBMoviesByFilters,
            searchByText: searchTMDBMovies),
        loadDetails: fetchMovieDetails
    )
    .modelContainer(for: storedModelTypes, inMemory: true)
}
