import Testing

@testable import MyNextMovie

/// Pretends to be the account, without Supabase and without the network.
private final class TestAccount {
    var signedInEmail = ""
    var isOffline = false
    var needsEmailConfirmation = false
    var syncCount = 0
    var clearCount = 0
    /// `syncCount` when the device was cleared, to check that the sync came first.
    var syncCountWhenCleared = 0

    func signIn(email: String) throws -> String {
        if isOffline {
            throw NoConnection()
        }
        signedInEmail = email
        return email
    }

    func signUp(email: String) throws -> String {
        if isOffline {
            throw NoConnection()
        }
        if needsEmailConfirmation {
            return ""
        }
        signedInEmail = email
        return email
    }

    func sync() throws {
        syncCount += 1
        if isOffline {
            throw NoConnection()
        }
    }

    func clear() {
        clearCount += 1
        syncCountWhenCleared = syncCount
    }
}

private let shortPassword = "test"
private let longEnoughPassword = "secret"

@MainActor
struct AccountViewModelTests {
    @Test func startsSignedOut() {
        let viewModel = makeViewModel(TestAccount())

        #expect(!viewModel.isSignedIn)
    }

    @Test func newAccountNeedsLongEnoughPassword() {
        let viewModel = makeViewModel(TestAccount())
        viewModel.email = testAccountEmail

        viewModel.password = shortPassword
        #expect(viewModel.canSignIn)
        #expect(!viewModel.canSignUp)

        viewModel.password = longEnoughPassword
        #expect(viewModel.canSignUp)
    }

    @Test func signInTrimsEmailClearsPasswordAndSyncs() async {
        let account = TestAccount()
        let viewModel = makeViewModel(account)
        viewModel.email = "  " + testAccountEmail + " "
        viewModel.password = shortPassword

        await viewModel.signIn()

        #expect(viewModel.signedInEmail == testAccountEmail)
        #expect(viewModel.password.isEmpty)
        #expect(account.syncCount == 1)
    }

    @Test func showsErrorWhenSignInFails() async {
        let account = TestAccount()
        account.isOffline = true
        let viewModel = makeViewModel(account)
        viewModel.email = testAccountEmail
        viewModel.password = shortPassword

        await viewModel.signIn()

        #expect(viewModel.state == .failed)
        #expect(viewModel.errorMessage == "No connection")
        #expect(!viewModel.isSignedIn)
    }

    @Test func signUpSignsInWhenNoConfirmationIsNeeded() async {
        let account = TestAccount()
        let viewModel = makeViewModel(account)
        viewModel.email = testAccountEmail
        viewModel.password = longEnoughPassword

        await viewModel.signUp()

        #expect(viewModel.isSignedIn)
        #expect(account.syncCount == 1)
    }

    @Test func signUpWaitsForEmailConfirmation() async {
        let account = TestAccount()
        account.needsEmailConfirmation = true
        let viewModel = makeViewModel(account)
        viewModel.email = testAccountEmail
        viewModel.password = longEnoughPassword

        await viewModel.signUp()

        #expect(viewModel.isWaitingForEmailConfirmation)
        #expect(!viewModel.isSignedIn)
    }

    @Test func userFromLastTimeIsSignedInAtOnce() {
        let account = TestAccount()
        account.signedInEmail = testAccountEmail

        let viewModel = makeViewModel(account)

        #expect(viewModel.isSignedIn)
        #expect(viewModel.signedInEmail == testAccountEmail)
    }

    @Test func doesNotSyncWhenSignedOut() async {
        let account = TestAccount()
        let viewModel = makeViewModel(account)

        await viewModel.syncSavedMovies()

        #expect(account.syncCount == 0)
        #expect(viewModel.syncState == .idle)
    }

    @Test func showsErrorWhenSyncFails() async {
        let account = TestAccount()
        account.signedInEmail = testAccountEmail
        account.isOffline = true
        let viewModel = makeViewModel(account)

        await viewModel.syncSavedMovies()

        #expect(viewModel.syncState == .failed)
        #expect(viewModel.syncErrorMessage == "No connection")
    }

    @Test func syncWorksAgainAfterFailure() async {
        let account = TestAccount()
        account.signedInEmail = testAccountEmail
        account.isOffline = true
        let viewModel = makeViewModel(account)
        await viewModel.syncSavedMovies()

        account.isOffline = false
        await viewModel.syncSavedMovies()

        #expect(viewModel.syncState == .loaded)
        #expect(account.syncCount == 2)
    }

    @Test func signOutSyncsThenClearsDevice() async {
        let account = TestAccount()
        account.signedInEmail = testAccountEmail
        let viewModel = makeViewModel(account)

        await viewModel.signOut()

        #expect(account.syncCountWhenCleared == 1)
        #expect(account.clearCount == 1)
        #expect(!viewModel.isSignedIn)
        #expect(account.signedInEmail.isEmpty)
    }
}

/// A view model whose account, sync and clearing read and change `account`.
@MainActor
private func makeViewModel(_ account: TestAccount) -> AccountViewModel {
    let accountService = AccountService(
        signedInEmail: { account.signedInEmail },
        signIn: { email, _ in try account.signIn(email: email) },
        signUp: { email, _ in try account.signUp(email: email) },
        signOut: { account.signedInEmail = "" }
    )
    return AccountViewModel(
        account: accountService,
        syncSavedMovies: { try account.sync() },
        clearSavedMovies: { account.clear() }
    )
}
