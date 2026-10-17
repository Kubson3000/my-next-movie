import SwiftData
import SwiftUI

/// The Saved tab: movies saved for later, the newest first.
struct SavedMoviesView: View {
    @Query(sort: \SavedMovie.savedAt, order: .reverse) private var savedMovies: [SavedMovie]
    private let loadDetails: MovieDetailsLoader

    init(loadDetails: @escaping MovieDetailsLoader) {
        self.loadDetails = loadDetails
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Saved")
                .navigationDestination(for: Movie.self) { movie in movieDetail(movie) }
        }
    }

    private func movieDetail(_ movie: Movie) -> some View {
        MovieDetailView(movie: movie, loadDetails: loadDetails)
    }

    @ViewBuilder
    private var content: some View {
        if savedMovies.isEmpty {
            ContentUnavailableView(
                "No saved movies",
                systemImage: symbolNameSaved,
                description: Text("Tap the bookmark on a movie's details to watch it later.")
            )
        } else {
            MovieGrid(title: "Watch Later", movies: moviesFromSaved(savedMovies))
        }
    }
}

/// Bookmark on the movie details bar. Saves the movie, or removes it when it is saved.
struct SaveMovieButton: View {
    let movie: Movie

    @Environment(\.modelContext) private var modelContext
    @Query private var savedCopies: [SavedMovie]

    init(movie: Movie) {
        self.movie = movie
        let movieId = movie.id
        _savedCopies = Query(filter: #Predicate { savedMovie in savedMovie.movieId == movieId })
    }

    var body: some View {
        Button {
            toggleSavedMovie(modelContext, movie, now: Date.now)
        } label: {
            label
        }
    }

    @ViewBuilder
    private var label: some View {
        if savedCopies.isEmpty {
            Label("Save", systemImage: symbolNameSaved)
        } else {
            Label("Remove from Saved", systemImage: symbolNameSavedMovie)
        }
    }
}

#Preview {
    SavedMoviesView(loadDetails: fetchMovieDetails)
        .modelContainer(for: storedModelTypes, inMemory: true)
}
