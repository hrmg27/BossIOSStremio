import Foundation

/// Body for `POST /api/datastoreGet` — reads the library collection.
struct DatastoreGetRequest: Encodable {
    let authKey: String
    let collection: String
    let all: Bool
    let ids: [String]

    init(authKey: String, collection: String = "libraryItem",
         all: Bool = true, ids: [String] = []) {
        self.authKey = authKey
        self.collection = collection
        self.all = all
        self.ids = ids
    }
}

/// Body for `POST /api/datastorePut` — writes changed library items back to the
/// account. This is how playback progress reaches the PC and TV.
struct DatastorePutRequest: Encodable {
    let authKey: String
    let collection: String
    let changes: [LibraryItem]

    init(authKey: String, collection: String = "libraryItem", changes: [LibraryItem]) {
        self.authKey = authKey
        self.collection = collection
        self.changes = changes
    }
}

/// Body for `POST /api/addonCollectionGet` — the installed add-on collection,
/// the source of stream and subtitle providers.
struct AddonCollectionGetRequest: Encodable {
    let authKey: String
    let update: Bool
}
