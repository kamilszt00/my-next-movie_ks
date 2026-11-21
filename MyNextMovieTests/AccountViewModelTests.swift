import Testing

@testable import MyNextMovie

/// Pretends to be the account backend, so tests run without Supabase or network.
private final class TestAccount {
    var signedInEmail = ""
    var isOffline = false
    var needsEmailConfirmation = false
    var syncCallCount = 0
    var clearCallCount = 0
    var isSyncFailing = false
    /// Order of sync and clear calls, to check that sign out syncs first.
    var calls: [String] = []
}

@MainActor
private func makeViewModel(_ testAccount: TestAccount) -> AccountViewModel {
    let request: AccountRequest = { email, _ in
        if testAccount.isOffline {
            throw NoConnection()
        }
        if testAccount.needsEmailConfirmation {
            return ""
        }
        testAccount.signedInEmail = email
        return email
    }
    let account = AccountService(
        signedInEmail: { testAccount.signedInEmail },
        signIn: request,
        signUp: request,
        signOut: { testAccount.signedInEmail = "" }
    )
    return AccountViewModel(
        account: account,
        syncSavedMovies: {
            testAccount.syncCallCount += 1
            testAccount.calls.append("sync")
            if testAccount.isSyncFailing {
                throw NoConnection()
            }
        },
        clearSavedMovies: {
            testAccount.clearCallCount += 1
            testAccount.calls.append("clear")
        }
    )
}

@MainActor
struct AccountViewModelTests {
    @Test func startsSignedOut() {
        let viewModel = makeViewModel(TestAccount())

        #expect(!viewModel.isSignedIn)
    }

    @Test func newAccountNeedsLongEnoughPassword() {
        let viewModel = makeViewModel(TestAccount())
        viewModel.email = testAccountEmail
        viewModel.password = "abc"

        #expect(viewModel.canSignIn)
        #expect(!viewModel.canSignUp)

        viewModel.password = "abcdef"

        #expect(viewModel.canSignUp)
    }

    @Test func signInTrimsEmailClearsPasswordAndSyncs() async {
        let testAccount = TestAccount()
        let viewModel = makeViewModel(testAccount)
        viewModel.email = "  \(testAccountEmail)  "
        viewModel.password = testAccountPassword

        await viewModel.signIn()

        #expect(viewModel.isSignedIn)
        #expect(viewModel.signedInEmail == testAccountEmail)
        #expect(viewModel.password.isEmpty)
        #expect(testAccount.syncCallCount == 1)
    }

    @Test func showsErrorWhenSignInFails() async {
        let testAccount = TestAccount()
        testAccount.isOffline = true
        let viewModel = makeViewModel(testAccount)
        viewModel.email = testAccountEmail
        viewModel.password = testAccountPassword

        await viewModel.signIn()

        #expect(viewModel.state == .failed)
        #expect(viewModel.errorMessage == "No connection")
        #expect(!viewModel.isSignedIn)
    }

    @Test func signUpSignsInWhenNoConfirmationIsNeeded() async {
        let viewModel = makeViewModel(TestAccount())
        viewModel.email = "new@test.test"
        viewModel.password = "password"

        await viewModel.signUp()

        #expect(viewModel.isSignedIn)
        #expect(viewModel.signedInEmail == "new@test.test")
        #expect(!viewModel.isWaitingForEmailConfirmation)
    }

    @Test func signUpWaitsForEmailConfirmation() async {
        let testAccount = TestAccount()
        testAccount.needsEmailConfirmation = true
        let viewModel = makeViewModel(testAccount)
        viewModel.email = "new@test.test"
        viewModel.password = "password"

        await viewModel.signUp()

        #expect(viewModel.isWaitingForEmailConfirmation)
        #expect(!viewModel.isSignedIn)
    }

    @Test func userFromLastTimeIsSignedInAtOnce() {
        let testAccount = TestAccount()
        testAccount.signedInEmail = testAccountEmail

        let viewModel = makeViewModel(testAccount)

        #expect(viewModel.isSignedIn)
        #expect(viewModel.signedInEmail == testAccountEmail)
    }

    @Test func doesNotSyncWhenSignedOut() async {
        let testAccount = TestAccount()
        let viewModel = makeViewModel(testAccount)

        await viewModel.syncSavedMovies()

        #expect(testAccount.syncCallCount == 0)
        #expect(viewModel.syncState == .idle)
    }

    @Test func showsErrorWhenSyncFails() async {
        let testAccount = TestAccount()
        testAccount.signedInEmail = testAccountEmail
        testAccount.isSyncFailing = true
        let viewModel = makeViewModel(testAccount)

        await viewModel.syncSavedMovies()

        #expect(viewModel.syncState == .failed)
        #expect(viewModel.syncErrorMessage == "No connection")
    }

    @Test func syncWorksAgainAfterFailure() async {
        let testAccount = TestAccount()
        testAccount.signedInEmail = testAccountEmail
        testAccount.isSyncFailing = true
        let viewModel = makeViewModel(testAccount)
        await viewModel.syncSavedMovies()

        testAccount.isSyncFailing = false
        await viewModel.syncSavedMovies()

        #expect(viewModel.syncState == .loaded)
    }

    @Test func signOutSyncsThenClearsDevice() async {
        let testAccount = TestAccount()
        testAccount.signedInEmail = testAccountEmail
        let viewModel = makeViewModel(testAccount)

        await viewModel.signOut()

        #expect(testAccount.calls == ["sync", "clear"])
        #expect(!viewModel.isSignedIn)
        #expect(testAccount.signedInEmail.isEmpty)
    }
}
