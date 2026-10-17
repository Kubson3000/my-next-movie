import Testing

@testable import MyNextMovie

private let matrixMovieId = 603

@MainActor
struct MovieDetailViewModelTests {
    @Test func startsIdleWithEmptyDetails() {
        let viewModel = MovieDetailViewModel(
            movieId: matrixMovieId,
            loadDetails: { _ in testMovieDetails }
        )

        #expect(viewModel.state == .idle)
        #expect(viewModel.details.credits.cast.isEmpty)
    }

    @Test func loadsDetailsOfItsMovie() async {
        var requestedMovieId = 0
        let loadDetails: MovieDetailsLoader = { movieId in
            requestedMovieId = movieId
            return testMovieDetails
        }
        let viewModel = MovieDetailViewModel(movieId: matrixMovieId, loadDetails: loadDetails)

        await viewModel.load()

        #expect(requestedMovieId == matrixMovieId)
        #expect(viewModel.state == .loaded)
        #expect(viewModel.details.tagline == testMovieDetails.tagline)
    }

    @Test func showsErrorWhenLoadingFails() async {
        let viewModel = MovieDetailViewModel(
            movieId: matrixMovieId,
            loadDetails: { _ in throw NoConnection() }
        )

        await viewModel.load()

        #expect(viewModel.state == .failed)
        #expect(viewModel.errorMessage == "No connection")
    }

    @Test func loadIfNeededLoadsOnlyOnce() async {
        var loadCount = 0
        let loadDetails: MovieDetailsLoader = { _ in
            loadCount += 1
            return testMovieDetails
        }
        let viewModel = MovieDetailViewModel(movieId: matrixMovieId, loadDetails: loadDetails)

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()

        #expect(loadCount == 1)
    }
}
