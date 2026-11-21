import Foundation
import Observation

/// Sign-in state and the state of syncing saved movies with the account.
@Observable
final class AccountViewModel {
    var email = ""
    var password = ""
    private(set) var signedInEmail = ""
    private(set) var state = LoadState.idle
    private(set) var errorMessage = ""
    private(set) var isWaitingForEmailConfirmation = false
    private(set) var syncState = LoadState.idle
    private(set) var syncErrorMessage = ""

    private let account: AccountService
    private let sync: () async throws -> Void
    private let clearSavedMovies: @MainActor () -> Void

    /// Set when a sync is requested while another one runs, so one more runs after it.
    private var isSyncRequestedAgain = false

    init(
        account: AccountService,
        syncSavedMovies: @escaping () async throws -> Void,
        clearSavedMovies: @escaping @MainActor () -> Void
    ) {
        self.account = account
        self.sync = syncSavedMovies
        self.clearSavedMovies = clearSavedMovies
        // Read the stored session right away, so a signed-in user never sees the sign-in screen.
        self.signedInEmail = account.signedInEmail()
    }

    var isSignedIn: Bool {
        return !signedInEmail.isEmpty
    }

    var canSignIn: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        return !trimmedEmail.isEmpty && !password.isEmpty && state != .loading
    }

    var canSignUp: Bool {
        return canSignIn && password.count >= minimumPasswordLength
    }

    func signIn() async {
        await submit(account.signIn)
    }

    func signUp() async {
        await submit(account.signUp)
    }

    /// Syncs saved movies. A request made during a sync runs once that sync finishes.
    func syncSavedMovies() async {
        if !isSignedIn {
            return
        }
        if syncState == .loading {
            isSyncRequestedAgain = true
            return
        }

        repeat {
            isSyncRequestedAgain = false
            syncState = .loading
            do {
                try await sync()
                syncState = .loaded
            } catch {
                syncErrorMessage = error.localizedDescription
                syncState = .failed
            }
        } while isSyncRequestedAgain && isSignedIn
    }

    /// Sends the last changes, then signs out and removes saved movies from the device.
    func signOut() async {
        await syncSavedMovies()
        try? await account.signOut()
        signedInEmail = ""
        state = .idle
        syncState = .idle
        syncErrorMessage = ""
        clearSavedMovies()
    }

    /// Shared path of signing in and creating an account.
    private func submit(_ request: AccountRequest) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        state = .loading
        isWaitingForEmailConfirmation = false
        do {
            let resultEmail = try await request(trimmedEmail, password)
            email = trimmedEmail
            password = ""
            state = .loaded
            if resultEmail.isEmpty {
                isWaitingForEmailConfirmation = true
                return
            }
            signedInEmail = resultEmail
            await syncSavedMovies()
        } catch {
            errorMessage = error.localizedDescription
            state = .failed
        }
    }
}
