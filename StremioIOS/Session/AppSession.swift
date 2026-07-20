import Foundation

/// App-wide session state.
///
/// Owns the auth-key lifecycle (Keychain-backed) and the shared `StremioAPI`
/// client. Views observe this to decide between the login screen and content.
@MainActor
final class AppSession: ObservableObject {
    enum State {
        case loading
        case signedOut
        case signedIn(user: StremioUser)
    }

    @Published private(set) var state: State = .loading
    @Published var errorMessage: String?

    let api = StremioAPI()
    private(set) var authKey: String?

    /// Restore a previously stored session on launch.
    func restore() async {
        do {
            if let key = try KeychainStore.loadAuthKey() {
                authKey = key
                // No cached user object yet; presence of a key means signed in.
                // A lightweight profile fetch can be added later if needed.
                state = .signedIn(user: StremioUser(id: "me", email: nil))
            } else {
                state = .signedOut
            }
        } catch {
            state = .signedOut
        }
    }

    func login(email: String, password: String) async {
        errorMessage = nil
        do {
            let result = try await api.login(email: email, password: password)
            try KeychainStore.saveAuthKey(result.authKey)
            authKey = result.authKey
            state = .signedIn(user: result.user)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
    }

    func logout() {
        try? KeychainStore.deleteAuthKey()
        authKey = nil
        state = .signedOut
    }
}
