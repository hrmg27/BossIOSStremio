import Foundation

/// Holds the installed add-on collection for the signed-in account and resolves
/// streams/subtitles through `AddonClient`. Loaded once after sign-in; views ask
/// it for streams when opening a title.
@MainActor
final class AddonStore: ObservableObject {
    @Published private(set) var addons: [AddonDescriptor] = []
    @Published var errorMessage: String?

    private weak var session: AppSession?
    private let client = AddonClient()

    func attach(session: AppSession) {
        self.session = session
    }

    func load() async {
        guard let session, let authKey = session.authKey else { return }
        do {
            addons = try await session.api.getAddons(authKey: authKey)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func streams(type: String, id: String) async -> [AddonStream] {
        await client.streams(type: type, id: id, from: addons)
    }

    func subtitles(type: String, id: String) async -> [Subtitle] {
        await client.subtitles(type: type, id: id, from: addons)
    }
}
