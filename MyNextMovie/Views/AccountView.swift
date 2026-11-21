import SwiftUI

/// The Account tab: who is signed in, sync state and signing out.
struct AccountView: View {
    let viewModel: AccountViewModel

    var body: some View {
        NavigationStack {
            form
                .navigationTitle("Account")
        }
    }

    private var form: some View {
        Form {
            Section("Signed in as") {
                Text(viewModel.signedInEmail)
            }
            Section("Saved movies") {
                syncStatus
            }
            Section {
                Button("Sign Out", role: .destructive, action: signOut)
            } footer: {
                Text("Your saved movies stay in your account and are removed from this device.")
            }
        }
    }

    @ViewBuilder
    private var syncStatus: some View {
        switch viewModel.syncState {
        case .idle:
            Text("Not synced yet")
                .foregroundStyle(.secondary)
        case .loading:
            HStack(spacing: spacingSmall) {
                ProgressView()
                Text("Syncing with your account")
            }
        case .loaded:
            Label("In sync with your account", systemImage: symbolNameInSync)
        case .failed:
            Label(viewModel.syncErrorMessage, systemImage: symbolNameError)
                .foregroundStyle(.red)
            Button("Try again", action: retrySync)
        }
    }

    private func signOut() {
        Task { await viewModel.signOut() }
    }

    private func retrySync() {
        Task { await viewModel.syncSavedMovies() }
    }
}

/// A view model without Supabase for previews. Any email and password work.
func previewAccountViewModel(signedInEmail: String) -> AccountViewModel {
    let account = AccountService(
        signedInEmail: { signedInEmail },
        signIn: { email, _ in email },
        signUp: { email, _ in email },
        signOut: {}
    )
    return AccountViewModel(account: account, syncSavedMovies: {}, clearSavedMovies: {})
}

#Preview {
    AccountView(viewModel: previewAccountViewModel(signedInEmail: testAccountEmail))
}
