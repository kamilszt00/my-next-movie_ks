import Testing

@testable import MyNextMovie

@MainActor
struct MovieDetailViewModelTests {
    @Test func startsIdleWithEmptyDetails() {
        let viewModel = MovieDetailViewModel(movieId: 1, loadDetails: { _ in emptyMovieDetails })

        #expect(viewModel.state == .idle)
        #expect(viewModel.details.credits.cast.isEmpty)
    }

    @Test func loadsDetailsOfItsMovie() async {
        var receivedMovieId = 0
        let viewModel = MovieDetailViewModel(
            movieId: 42,
            loadDetails: { movieId in
                receivedMovieId = movieId
                return emptyMovieDetails
            })

        await viewModel.load()

        #expect(receivedMovieId == 42)
        #expect(viewModel.state == .loaded)
    }

    @Test func showsErrorWhenLoadingFails() async {
        let viewModel = MovieDetailViewModel(
            movieId: 1,
            loadDetails: { _ in throw NoConnection() }
        )

        await viewModel.load()

        #expect(viewModel.state == .failed)
        #expect(viewModel.errorMessage == "No connection")
    }

    @Test func loadIfNeededLoadsOnlyOnce() async {
        var loadCallCount = 0
        let viewModel = MovieDetailViewModel(
            movieId: 1,
            loadDetails: { _ in
                loadCallCount += 1
                return emptyMovieDetails
            })

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()

        #expect(loadCallCount == 1)
    }
}
