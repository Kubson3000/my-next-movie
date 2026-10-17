import SwiftUI

private let backdropHeight: CGFloat = 440
private let backdropBlurRadius: CGFloat = 40
private let posterWidthOnBackdrop: CGFloat = 200
private let posterShadowColor = Color.black.opacity(0.35)
private let posterShadowRadius: CGFloat = 20
private let posterShadowOffset: CGFloat = 10

struct MovieDetailView: View {
    let movie: Movie
    @State private var viewModel: MovieDetailViewModel

    init(movie: Movie, loadDetails: @escaping MovieDetailsLoader) {
        self.movie = movie
        _viewModel = State(
            initialValue: MovieDetailViewModel(movieId: movie.id, loadDetails: loadDetails)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacingExtraLarge) {
                MovieBackdrop(movie: movie)
                MovieInfo(movie: movie, details: viewModel.details).padding(.horizontal)
                detailsContent.padding(.horizontal)
            }
            .padding(.bottom, spacingHuge)
        }
        .task { await viewModel.loadIfNeeded() }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The movie from the list stays on screen while the details load and when they fail.
    @ViewBuilder
    private var detailsContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
        case .loaded:
            MovieDetailSections(details: viewModel.details)
        case .failed:
            ErrorView(title: "Could not load details", message: viewModel.errorMessage) {
                Task { await viewModel.load() }
            }
        }
    }
}

/// The poster, sharp, on top of itself stretched to the screen width and blurred.
private struct MovieBackdrop: View {
    let movie: Movie

    var body: some View {
        GeometryReader { geometry in
            BlurredPoster(movie: movie, backdropSize: geometry.size)
        }
        .frame(height: backdropHeight)
        .clipped()
        .overlay { fadeToBackground }
        .overlay(alignment: .bottom) { sharpPoster }
    }

    private var fadeToBackground: some View {
        LinearGradient(
            colors: [.clear, Color(.systemBackground)],
            startPoint: .center,
            endPoint: .bottom
        )
    }

    private var sharpPoster: some View {
        PosterView(movie: movie)
            .frame(width: posterWidthOnBackdrop)
            .shadow(color: posterShadowColor, radius: posterShadowRadius, y: posterShadowOffset)
    }
}

private struct BlurredPoster: View {
    let movie: Movie
    let backdropSize: CGSize

    var body: some View {
        PosterView(movie: movie, cornerRadius: 0)
            .frame(width: backdropSize.width)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: backdropSize.width, height: backdropSize.height)
            .blur(radius: backdropBlurRadius, opaque: true)
    }
}

/// Title, tagline, facts line, genres, overview and directors under the backdrop.
/// The tagline, runtime, age rating and directors show once the details load.
private struct MovieInfo: View {
    let movie: Movie
    let details: MovieDetails

    var body: some View {
        VStack(alignment: .leading, spacing: spacingLarge) {
            heading
            GenreRow(genreIds: knownGenreIds(movie))
            overview
            if !directorNames(details).isEmpty {
                directors
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: spacingSmall) {
            Text(movie.title)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
            if !details.tagline.isEmpty {
                tagline
            }
            Text(movieFactsLine(movie, details, regionCode: watchRegionCode))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var tagline: some View {
        Text(details.tagline)
            .font(.title3)
            .italic()
            .foregroundStyle(.secondary)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: spacingSmall) {
            Text("Overview")
                .font(.headline)
            Text(movie.overview)
                .foregroundStyle(.secondary)
        }
    }

    private var directors: some View {
        VStack(alignment: .leading, spacing: spacingSmall) {
            Text("Directed by")
                .font(.headline)
            Text(directorNames(details))
                .foregroundStyle(.secondary)
        }
    }
}

/// Genre chips in one row that scrolls sideways when they do not fit.
private struct GenreRow: View {
    let genreIds: [Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            chips
        }
        .scrollClipDisabled()
    }

    private var chips: some View {
        HStack(spacing: spacingSmall) {
            ForEach(genreIds, id: \.self) { genreId in
                GenreChip(genreId: genreId)
            }
        }
    }
}

#Preview {
    PopularMoviesPreview { movies in
        NavigationStack {
            MovieDetailView(movie: movies[0], loadDetails: fetchMovieDetails)
        }
    }
}
