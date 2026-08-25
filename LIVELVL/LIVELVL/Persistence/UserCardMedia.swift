import Foundation
import SwiftData

enum UserCardMediaKind: String, Codable, Sendable {
    case image
    case gif
    case apng

    var fileExtension: String {
        switch self {
        case .image: "img"
        case .gif: "gif"
        case .apng: "png"
        }
    }
}

@Model
final class UserCardMedia {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var kindRaw: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        fileName: String,
        kind: UserCardMediaKind,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.fileName = fileName
        kindRaw = kind.rawValue
        self.updatedAt = updatedAt
    }

    var kind: UserCardMediaKind {
        UserCardMediaKind(rawValue: kindRaw) ?? .image
    }
}

struct UserCardMediaStore {
    let rootURL: URL
    let fileManager: FileManager

    init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
    }

    func url(for media: UserCardMedia) -> URL {
        rootURL.appending(path: media.fileName)
    }

    @discardableResult
    func save(
        data: Data,
        kind: UserCardMediaKind,
        replacing oldMedia: UserCardMedia?,
        now: Date = .now,
        in context: ModelContext
    ) throws -> UserCardMedia {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let media = UserCardMedia(
            fileName: "\(UUID().uuidString).\(kind.fileExtension)",
            kind: kind,
            updatedAt: now
        )
        let destinationURL = url(for: media)
        let temporaryURL = rootURL.appending(path: ".\(media.id.uuidString).tmp")

        try data.write(to: temporaryURL, options: .atomic)
        do {
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }

        context.insert(media)
        if let oldMedia {
            context.delete(oldMedia)
            try? fileManager.removeItem(at: url(for: oldMedia))
        }
        return media
    }

    func load(_ media: UserCardMedia) throws -> Data {
        try Data(contentsOf: url(for: media))
    }

    func delete(_ media: UserCardMedia, from context: ModelContext) throws {
        try fileManager.removeItem(at: url(for: media))
        context.delete(media)
    }
}
