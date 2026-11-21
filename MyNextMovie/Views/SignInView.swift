import SwiftUI

/// First screen of the app, shown until the user signs in.
struct SignInView: View {
    @Bindable var viewModel: AccountViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: spacingExtraLarge) {
                header
                fields
                buttons
                status
            }
            .padding(spacingExtraLarge)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        VStack(spacing: spacingMedium) {
            Image(systemName: symbolNameMovies)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("My Next Movie")
                .font(.largeTitle.bold())
            Text("Sign in to keep your saved movies on every device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, spacingHuge)
    }

    private var fields: some View {
        VStack(spacing: spacingMedium) {
            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .submitLabel(.go)
                .onSubmit(signIn)
        }
        .textFieldStyle(.roundedBorder)
    }

    private var buttons: some View {
        VStack(spacing: spacingMedium) {
            signInButton
            signUpButton
        }
        .controlSize(.large)
    }

    private var signInButton: some View {
        Button(action: signIn) {
            Text("Sign In")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.canSignIn)
    }

    private var signUpButton: some View {
        Button(action: signUp) {
            Text("Create Account")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!viewModel.canSignUp)
    }

    @ViewBuilder
    private var status: some View {
        if viewModel.state == .loading {
            ProgressView()
        } else if viewModel.state == .failed {
            Text(viewModel.errorMessage)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        } else if viewModel.isWaitingForEmailConfirmation {
            Text("Check your email and tap the link to confirm your account, then sign in.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } else {
            Text("A new account needs a password of at least \(minimumPasswordLength) characters.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func signIn() {
        if !viewModel.canSignIn {
            return
        }
        Task { await viewModel.signIn() }
    }

    private func signUp() {
        Task { await viewModel.signUp() }
    }
}

#Preview {
    SignInView(viewModel: previewAccountViewModel(signedInEmail: ""))
}
