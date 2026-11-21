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

private struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var account: AccountViewModel?

    var body: some View {
        if let account {
            AppTabs(
                account: account,
                loadPopularMovies: loadPopularMoviesWithCache,
                loadDetails: loadDetailsWithCache
            )
        } else {
            // The view model needs the model context, which is ready only once the view appears.
            Color.clear
                .onAppear(perform: makeAccountViewModel)
        }
    }

    private func makeAccountViewModel() {
        let viewModel = AccountViewModel(
            account: supabaseAccountService,
            syncSavedMovies: syncWithAccount,
            clearSavedMovies: clearDevice
        )
        #if DEBUG
            viewModel.email = testAccountEmail
            viewModel.password = testAccountPassword
        #endif
        account = viewModel
    }

    private func syncWithAccount() async throws {
        try await syncSavedMovies(modelContext, cloud: supabaseSavedMoviesCloud)
    }

    private func clearDevice() {
        clearSavedMovies(modelContext)
    }

    private func loadPopularMoviesWithCache() async throws -> [Movie] {
        return try await loadPopularMovies(cache: modelContext)
    }

    private func loadDetailsWithCache(movieId: Int) async throws -> MovieDetails {
        return try await loadTMDBMovieDetails(movieId: movieId, cache: modelContext)
    }
}

/// The tabs for a signed-in user, the sign-in screen otherwise.
private struct AppTabs: View {
    let account: AccountViewModel
    let loadPopularMovies: MovieLoader
    let loadDetails: MovieDetailsLoader

    @Environment(\.scenePhase) private var scenePhase
    @Query(filter: #Predicate<SavedMovie> { saved in !saved.isInCloud })
    private var moviesNotInCloud: [SavedMovie]
    @Query private var removedMovies: [RemovedSavedMovie]

    var body: some View {
        if account.isSignedIn {
            tabs
                .task { await account.syncSavedMovies() }
                .onChange(of: scenePhase, syncWhenActive)
                .onChange(of: unsentChangeCount, syncWhenChangesGrow)
        } else {
            SignInView(viewModel: account)
        }
    }

    /// Saved and removed movies the account does not know about yet.
    private var unsentChangeCount: Int {
        return moviesNotInCloud.count + removedMovies.count
    }

    private func syncWhenActive(_ oldPhase: ScenePhase, _ newPhase: ScenePhase) {
        if newPhase == .active {
            Task { await account.syncSavedMovies() }
        }
    }

    /// A drop is the result of a sync and needs no other one.
    private func syncWhenChangesGrow(_ oldCount: Int, _ newCount: Int) {
        if newCount > oldCount {
            Task { await account.syncSavedMovies() }
        }
    }

    private var tabs: some View {
        TabView {
            Tab("Movies", systemImage: symbolNameMovies) {
                moviesTab
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

    private var moviesTab: some View {
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
}
