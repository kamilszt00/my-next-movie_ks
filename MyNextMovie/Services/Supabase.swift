import Foundation
import Supabase

private let savedMoviesTable = "saved_movies"
private let savedMovieIdColumn = "id"
private let savedMovieSavedAtColumn = "saved_at"
private let savedMovieConflictKey = "user_id,id"

let minimumPasswordLength = 6
let testAccountEmail = "test@test.test"
let testAccountPassword = "test"

nonisolated struct SupabaseError: LocalizedError {
    let message: String
    var errorDescription: String? { return message }
}

private var supabaseClient: SupabaseClient?

private func requireSupabaseClient() throws -> SupabaseClient {
    if let supabaseClient {
        return supabaseClient
    }
    let key = supabaseAnonKey()
    guard let url = URL(string: supabaseURL()), url.host != nil, !key.isEmpty else {
        throw SupabaseError(message: "Missing Supabase keys. Add them to Config/Secrets.xcconfig.")
    }
    let client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    supabaseClient = client
    return client
}

func supabaseSignedInEmail() -> String {
    guard let client = try? requireSupabaseClient() else { return "" }
    return client.auth.currentUser?.email ?? ""
}

func signInToSupabase(email: String, password: String) async throws -> String {
    let client = try requireSupabaseClient()
    let session = try await client.auth.signIn(email: email, password: password)
    return session.user.email ?? email
}

func signUpToSupabase(email: String, password: String) async throws -> String {
    let client = try requireSupabaseClient()
    let response = try await client.auth.signUp(email: email, password: password)
    guard let session = response.session else { return "" }
    return session.user.email ?? email
}

func signOutOfSupabase() async throws {
    guard let client = try? requireSupabaseClient() else { return }
    try? await client.auth.signOut()
}

let supabaseAccountService = AccountService(
    signedInEmail: supabaseSignedInEmail,
    signIn: signInToSupabase,
    signUp: signUpToSupabase,
    signOut: signOutOfSupabase
)

/// One row of `saved_movies`. The database fills `user_id` itself.
nonisolated struct CloudSavedMovie: Codable, Equatable {
    let id: Int
    let title: String
    let overview: String
    let releaseDate: String
    let posterPath: String?
    let voteAverage: Double
    let genreIds: [Int]
    let savedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case voteAverage = "vote_average"
        case genreIds = "genre_ids"
        case savedAt = "saved_at"
    }
}

/// The user's rows, newest first. RLS returns only rows of the signed-in user.
func fetchCloudSavedMovies() async throws -> [CloudSavedMovie] {
    let client = try requireSupabaseClient()
    let cloudMovies: [CloudSavedMovie] =
        try await client
        .from(savedMoviesTable)
        .select()
        .order(savedMovieSavedAtColumn, ascending: false)
        .execute()
        .value
    return cloudMovies
}

/// Adds the rows. Rows the account already has stay as they are.
func uploadCloudSavedMovies(_ cloudMovies: [CloudSavedMovie]) async throws {
    if cloudMovies.isEmpty {
        return
    }
    let client = try requireSupabaseClient()
    try await client
        .from(savedMoviesTable)
        .upsert(
            cloudMovies,
            onConflict: savedMovieConflictKey,
            returning: .minimal,
            ignoreDuplicates: true
        )
        .execute()
}

func removeCloudSavedMovie(movieId: Int) async throws {
    let client = try requireSupabaseClient()
    try await client
        .from(savedMoviesTable)
        .delete(returning: .minimal)
        .eq(savedMovieIdColumn, value: movieId)
        .execute()
}

let supabaseSavedMoviesCloud = SavedMoviesCloud(
    fetchMovies: fetchCloudSavedMovies,
    uploadMovies: uploadCloudSavedMovies,
    removeMovie: removeCloudSavedMovie
)
