/// Any function that signs in or creates an account and returns the email of the signed-in
/// user. An empty email means the new account waits for the user to confirm their email.
typealias AccountRequest = (_ email: String, _ password: String) async throws -> String

/// The user account as functions, like `MovieLoader` for movies.
/// The view model knows nothing about Supabase: the app passes Supabase, tests pass closures.
struct AccountService {
    /// "" when nobody is signed in.
    let signedInEmail: @MainActor () -> String
    let signIn: AccountRequest
    let signUp: AccountRequest
    let signOut: () async throws -> Void
}

/// The saved movies table of the signed-in account as functions.
/// The sync gets it as a parameter, so tests can pass an array instead of Supabase.
struct SavedMoviesCloud {
    /// Newest first.
    let fetchMovies: () async throws -> [CloudSavedMovie]
    /// Adds the movies. Movies the account has already stay as they are.
    let uploadMovies: (_ cloudMovies: [CloudSavedMovie]) async throws -> Void
    let removeMovie: (_ movieId: Int) async throws -> Void
}
