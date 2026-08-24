import Foundation
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct UserCardMediaStoreTests {
    @Test func savesLoadsReplacesAndDeletesMediaAtomically() throws {
        let schema = Schema([UserCardMedia.self])
        let container = try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let rootURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let store = UserCardMediaStore(rootURL: rootURL)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let firstData = Data([0x01, 0x02, 0x03])
        let first = try store.save(
            data: firstData,
            kind: .image,
            replacing: nil,
            now: Date(timeIntervalSince1970: 100),
            in: context
        )
        try context.save()

        #expect(try store.load(first) == firstData)
        #expect(first.kind == .image)

        let secondData = Data([0x04, 0x05])
        let second = try store.save(
            data: secondData,
            kind: .gif,
            replacing: first,
            now: Date(timeIntervalSince1970: 200),
            in: context
        )
        try context.save()

        #expect(try store.load(second) == secondData)
        #expect(!FileManager.default.fileExists(atPath: store.url(for: first).path))
        #expect(try context.fetch(FetchDescriptor<UserCardMedia>()).count == 1)

        try store.delete(second, from: context)
        try context.save()

        #expect(!FileManager.default.fileExists(atPath: store.url(for: second).path))
        #expect(try context.fetch(FetchDescriptor<UserCardMedia>()).isEmpty)
    }
}
