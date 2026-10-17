import Foundation
import Observation

/// Signing in, signing out and syncing the saved movies with the account.
/// A class only because SwiftUI's @Observable requires one.
@Observable
final class AccountViewModel {
    var email = ""
    var password = ""
    /// "" when nobody is signed in.
    private(set) var signedInEmail: String
    private(set) var state = LoadState.idle
    private(set) var errorMessage = ""
    private(set) var isWaitingForEmailConfirmation = false
    private(set) var syncState = LoadState.idle
    private(set) var syncErrorMessage = ""

    private let account: AccountService
    private let syncWithAccount: () async throws -> Void
    private let clearSavedMovies: @MainActor () -> Void

    /// The sync that is running, nil when none is.
    private var runningSync: Task<Void, Never>?
    /// Whether a sync was asked for while another one was running.
    private var isSyncRequestedAgain = false

    /// Reads the session at once, so a signed-in user never sees the sign in screen.
    init(
        account: AccountService,
        syncSavedMovies: @escaping () async throws -> Void,
        clearSavedMovies: @escaping @MainActor () -> Void
    ) {
        self.account = account
        self.syncWithAccount = syncSavedMovies
        self.clearSavedMovies = clearSavedMovies
        signedInEmail = account.signedInEmail()
    }

    var isSignedIn: Bool { !signedInEmail.isEmpty }

    var canSignIn: Bool {
        return !trimmedEmail.isEmpty && !password.isEmpty && state != .loading
    }

    var canSignUp: Bool {
        return canSignIn && password.count >= minimumPasswordLength
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespaces)
    }

    func signIn() async {
        await submit(account.signIn)
    }

    func signUp() async {
        await submit(account.signUp)
    }

    /// Sends changes to the account and gets the account's changes. Does nothing when nobody
    /// is signed in. Two syncs never run at once: a sync asked for during another one waits,
    /// and runs once more when that one ends.
    func syncSavedMovies() async {
        if !isSignedIn {
            return
        }
        if let runningSync {
            isSyncRequestedAgain = true
            await runningSync.value
            return
        }
        let sync = Task {
            await syncUntilNothingIsAsked()
            runningSync = nil
        }
        runningSync = sync
        await sync.value
    }

    /// Sends the last changes first, then signs out and clears the device.
    /// The account keeps its movies.
    func signOut() async {
        await syncSavedMovies()
        // Signing out works without internet too, so an error changes nothing here.
        try? await account.signOut()
        signedInEmail = ""
        state = .idle
        syncState = .idle
        clearSavedMovies()
    }

    /// Signing in and creating an account are the same path with a different request.
    private func submit(_ request: AccountRequest) async {
        state = .loading
        isWaitingForEmailConfirmation = false
        do {
            let accountEmail = try await request(trimmedEmail, password)
            state = .loaded
            if accountEmail.isEmpty {
                isWaitingForEmailConfirmation = true
                return
            }
            signedInEmail = accountEmail
            password = ""
            await syncSavedMovies()
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
        }
    }

    private func syncUntilNothingIsAsked() async {
        repeat {
            isSyncRequestedAgain = false
            await syncOnce()
        } while isSyncRequestedAgain && isSignedIn
    }

    private func syncOnce() async {
        syncState = .loading
        do {
            try await syncWithAccount()
            syncState = .loaded
        } catch {
            syncErrorMessage = error.localizedDescription
            syncState = .failed
        }
    }
}
