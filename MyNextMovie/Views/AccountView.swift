import SwiftUI

/// The Account tab: who is signed in, whether the saved movies are in sync, and Sign Out.
struct AccountView: View {
    let viewModel: AccountViewModel

    var body: some View {
        NavigationStack {
            Form {
                signedInSection
                savedMoviesSection
                signOutSection
            }
            .navigationTitle("Account")
        }
    }

    private var signedInSection: some View {
        Section("Signed in as") {
            Text(viewModel.signedInEmail)
        }
    }

    private var savedMoviesSection: some View {
        Section("Saved movies") {
            syncStatus
        }
    }

    @ViewBuilder
    private var syncStatus: some View {
        switch viewModel.syncState {
        case .idle, .loading:
            Label {
                Text("Syncing with your account")
            } icon: {
                ProgressView()
            }
        case .loaded:
            Label("In sync with your account", systemImage: symbolNameInSync)
        case .failed:
            syncError
        }
    }

    private var syncError: some View {
        VStack(alignment: .leading, spacing: spacingSmall) {
            Label(viewModel.syncErrorMessage, systemImage: symbolNameError)
                .foregroundStyle(.red)
            Button("Try again") {
                Task { await viewModel.syncSavedMovies() }
            }
        }
    }

    private var signOutSection: some View {
        Section {
            Button("Sign Out", role: .destructive) {
                Task { await viewModel.signOut() }
            }
        } footer: {
            Text("Your saved movies stay in your account and are removed from this device.")
        }
    }
}

/// A view model for previews, without Supabase: any email and password sign in,
/// and syncing does nothing.
func previewAccountViewModel(signedInEmail: String) -> AccountViewModel {
    let previewAccount = AccountService(
        signedInEmail: { signedInEmail },
        signIn: { email, _ in email },
        signUp: { email, _ in email },
        signOut: {}
    )
    return AccountViewModel(account: previewAccount, syncSavedMovies: {}, clearSavedMovies: {})
}

#Preview {
    AccountView(viewModel: previewAccountViewModel(signedInEmail: testAccountEmail))
}
