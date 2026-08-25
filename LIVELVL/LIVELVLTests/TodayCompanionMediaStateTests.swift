import Foundation
import SwiftData
import Testing
import UIKit
@testable import LIVELVL

@MainActor
struct TodayCompanionMediaStateTests {
    @Test func loadsStoredMediaAndDecodedFirstFrame() async throws {
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

        let imageData = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
            .pngData { renderer in
                UIColor.systemBlue.setFill()
                renderer.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
            }
        let media = try store.save(
            data: imageData,
            kind: .image,
            replacing: nil,
            in: context
        )
        try context.save()

        let controller = TodayCompanionMediaController(context: context, store: store)
        await controller.load()

        #expect(controller.state.media?.id == media.id)
        #expect(controller.state.decoded?.firstFrame != nil)
        #expect(controller.state.isLoading == false)
        #expect(controller.state.errorMessage == nil)
    }
}
