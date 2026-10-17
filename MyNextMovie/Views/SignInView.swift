import SwiftUI

private let headerSymbolSize: CGFloat = 56
private let signInFormMaxWidth: CGFloat = 420

/// The first screen of the app: sign in, or create an account.
struct SignInView: View {
    /// `@Bindable`, because the text fields need bindings to the view model's fields.
    @Bindable var viewModel: AccountViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: spacingExtraLarge) {
                header
                fields
                buttons
                status
            }
            .padding()
            .padding(.top, spacingHuge)
            .frame(maxWidth: signInFormMaxWidth)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(spacing: spacingSmall) {
            Image(systemName: symbolNameMovies)
                .font(.system(size: headerSymbolSize))
                .foregroundStyle(.tint)
            Text("My Next Movie")
                .font(.system(.largeTitle, design: .serif, weight: .bold))
            Text("Sign in to keep your saved movies on every device.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var fields: some View {
        VStack(spacing: spacingMedium) {
            TextField("Email", text: $viewModel.email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .submitLabel(.go)
                .onSubmit { signIn() }
        }
        .textFieldStyle(.roundedBorder)
    }

    private var buttons: some View {
        VStack(spacing: spacingMedium) {
            Button {
                signIn()
            } label: {
                Text("Sign In").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSignIn)
            Button {
                signUp()
            } label: {
                Text("Create Account").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canSignUp)
        }
        .controlSize(.large)
    }

    /// Progress, the error, a request to confirm the email, or the password rule.
    @ViewBuilder
    private var status: some View {
        if viewModel.state == .loading {
            ProgressView()
        } else if viewModel.state == .failed {
            Text(viewModel.errorMessage)
                .foregroundStyle(.red)
        } else if viewModel.isWaitingForEmailConfirmation {
            Text("Check your email and tap the link in it, then sign in.")
        } else {
            Text("A new account needs a password of at least \(minimumPasswordLength) characters.")
                .foregroundStyle(.secondary)
        }
    }

    /// Return in the password field signs in too, so it checks `canSignIn` like the button.
    private func signIn() {
        if viewModel.canSignIn {
            Task { await viewModel.signIn() }
        }
    }

    private func signUp() {
        Task { await viewModel.signUp() }
    }
}

#Preview {
    SignInView(viewModel: previewAccountViewModel(signedInEmail: ""))
}
