typealias AccountRequest = (_ email: String, _ password: String) async throws -> String

struct AccountService {
    var signedInEmail: @MainActor () -> String
    var signIn: AccountRequest
    var signUp: AccountRequest
    var signOut: () async throws -> Void
}

/// The account's saved movies table. The app passes Supabase functions, tests pass closures.
struct SavedMoviesCloud {
    var fetchMovies: () async throws -> [CloudSavedMovie]
    var uploadMovies: (_ cloudMovies: [CloudSavedMovie]) async throws -> Void
    var removeMovie: (_ movieId: Int) async throws -> Void
}
