import Foundation
import Supabase

// Requests to Supabase: the user account (Auth) and the `saved_movies` table.
// The table and its Row Level Security rules are in supabase/migrations.

private let savedMoviesTable = "saved_movies"
private let columnMovieId = "id"
private let columnSavedAt = "saved_at"

/// Primary key of `saved_movies`. An upsert of a row with the same pair adds nothing.
private let savedMoviesPrimaryKey = "user_id,id"

/// Supabase Auth rejects shorter passwords for new accounts (supabase/config.toml).
let minimumPasswordLength = 6

/// Test account from supabase/seed.sql. Debug builds fill the sign in screen with it.
let testAccountEmail = "test@test.test"
let testAccountPassword = "test"

private let missingKeysMessage = "Missing Supabase keys. Add them to Config/Secrets.xcconfig."

/// A Supabase request that failed. `error.localizedDescription` shows the message on screen.
struct SupabaseError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

/// One row of `saved_movies`: the fields of `Movie` and when the user saved it.
/// No `user_id`, the database fills it with the signed-in user.
nonisolated struct CloudSavedMovie: Codable, Equatable {
    let id: Int
    let title: String
    let overview: String
    let releaseDate: String
    let posterPath: String?
    let voteAverage: Double
    let genreIds: [Int]
    let savedAt: Date

    /// Column names are snake_case. A case without a string has the same name as its column.
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

/// `AccountService` with the Supabase functions below.
let supabaseAccountService = AccountService(
    signedInEmail: supabaseSignedInEmail,
    signIn: signInToSupabase,
    signUp: signUpToSupabase,
    signOut: signOutOfSupabase
)

/// `SavedMoviesCloud` with the Supabase functions below.
let supabaseSavedMoviesCloud = SavedMoviesCloud(
    fetchMovies: fetchCloudSavedMovies,
    uploadMovies: uploadCloudSavedMovies,
    removeMovie: removeCloudSavedMovie
)

/// The one client of the app, made by the first request. It keeps the session in the keychain,
/// so the user stays signed in after a restart, also without internet.
private var supabaseClient: SupabaseClient?

private func requireSupabaseClient() throws -> SupabaseClient {
    if let supabaseClient {
        return supabaseClient
    }
    let anonKey = supabaseAnonKey()
    guard let projectURL = URL(string: supabaseURL()), projectURL.host() != nil, !anonKey.isEmpty
    else {
        throw SupabaseError(message: missingKeysMessage)
    }
    let client = SupabaseClient(supabaseURL: projectURL, supabaseKey: anonKey)
    supabaseClient = client
    return client
}

/// "" when nobody is signed in or the keys are missing.
func supabaseSignedInEmail() -> String {
    let client = try? requireSupabaseClient()
    return client?.auth.currentUser?.email ?? ""
}

/// Has the type `AccountRequest`.
func signInToSupabase(email: String, password: String) async throws -> String {
    let client = try requireSupabaseClient()
    let session = try await client.auth.signIn(email: email, password: password)
    return session.user.email ?? email
}

/// Has the type `AccountRequest`. "" when the account waits for email confirmation,
/// because then Supabase gives no session.
func signUpToSupabase(email: String, password: String) async throws -> String {
    let client = try requireSupabaseClient()
    let response = try await client.auth.signUp(email: email, password: password)
    guard let session = response.session else {
        return ""
    }
    return session.user.email ?? email
}

/// Signs out on the device even without internet, so a server error is skipped.
func signOutOfSupabase() async throws {
    let client = try requireSupabaseClient()
    try? await client.auth.signOut()
}

/// Rows of the signed-in user, newest first. No filter on the user is needed,
/// Row Level Security returns only their rows.
func fetchCloudSavedMovies() async throws -> [CloudSavedMovie] {
    let client = try requireSupabaseClient()
    let newestFirst = client.from(savedMoviesTable).select().order(columnSavedAt, ascending: false)
    // `value` decodes the JSON into the type on the left.
    let cloudMovies: [CloudSavedMovie] = try await newestFirst.execute().value
    return cloudMovies
}

/// Adds the rows. A movie the account has already stays as it is. An empty list sends nothing.
func uploadCloudSavedMovies(_ cloudMovies: [CloudSavedMovie]) async throws {
    if cloudMovies.isEmpty {
        return
    }
    let client = try requireSupabaseClient()
    try await client
        .from(savedMoviesTable)
        .upsert(
            cloudMovies,
            onConflict: savedMoviesPrimaryKey,
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
        .eq(columnMovieId, value: movieId)
        .execute()
}
