import Foundation
import SwiftData
import Testing
@testable import LIVELVL

@MainActor
struct LocalDataResetMediaTests {
    @Test func resetDeletesUserCardMediaRecordsAndFiles() throws {
        let schema = Schema([
            PendingCardReward.self,
            OwnedCollectible.self,
            CollectionProgress.self,
            Completion.self,
            Item.self,
            Progress.self,
            StateSnapshot.self,
            DimensionProfile.self,
            UserCardMedia.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: .init(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        context.insert(UserCardMedia(fileName: "background.gif", kind: .gif))
        try context.save()

        let applicationSupportURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let mediaDirectoryURL = applicationSupportURL
            .appending(path: "UserCardMedia", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: mediaDirectoryURL,
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(to: mediaDirectoryURL.appending(path: "background.gif"))
        defer { try? FileManager.default.removeItem(at: applicationSupportURL) }

        try LocalDataResetService.reset(
            context: context,
            fileManager: .default,
            applicationSupportURL: applicationSupportURL
        )

        #expect(try context.fetch(FetchDescriptor<UserCardMedia>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: mediaDirectoryURL.path))
    }
}
