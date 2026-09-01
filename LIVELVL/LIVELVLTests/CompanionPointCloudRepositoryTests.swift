import Foundation
import Testing
@testable import LIVELVL

struct CompanionPointCloudRepositoryTests {
    @Test func transparentRasterPayloadKeepsItsFullResolutionSourceData() async throws {
        let id = artworkID("transparent", stage: .juvenile)
        let source = try await payload(for: id, renderMode: .transparentRaster)
        let provider = CountingArtworkProvider(payloads: [id: source])
        let repository = CompanionPointCloudRepository(provider: provider)

        let descriptor = try #require(try await repository.descriptor(for: id))

        #expect(descriptor.renderMode == .transparentRaster)
        #expect(descriptor.sourceImageData == source.data)
    }

    @Test func repeatedIdentityUsesOneProviderLoad() async throws {
        let id = artworkID("pilot", stage: .juvenile)
        let provider = CountingArtworkProvider(payloads: [id: try await payload(for: id)])
        let repository = CompanionPointCloudRepository(provider: provider)

        _ = try await repository.descriptor(for: id)
        _ = try await repository.descriptor(for: id)

        #expect(await provider.requestCount(for: id) == 1)
    }

    @Test func leastRecentlyUsedDescriptorIsEvictedBeyondTwoEntries() async throws {
        let firstID = artworkID("first", stage: .juvenile)
        let secondID = artworkID("second", stage: .stageTwo)
        let thirdID = artworkID("third", stage: .stageThree)
        let provider = CountingArtworkProvider(payloads: [
            firstID: try await payload(for: firstID),
            secondID: try await payload(for: secondID),
            thirdID: try await payload(for: thirdID)
        ])
        let repository = CompanionPointCloudRepository(provider: provider)

        _ = try await repository.descriptor(for: firstID)
        _ = try await repository.descriptor(for: secondID)
        _ = try await repository.descriptor(for: firstID)
        _ = try await repository.descriptor(for: thirdID)
        _ = try await repository.descriptor(for: secondID)

        #expect(await provider.requestCount(for: firstID) == 1)
        #expect(await provider.requestCount(for: secondID) == 2)
        #expect(await provider.requestCount(for: thirdID) == 1)
    }

    @MainActor
    @Test func loaderPublishesCurrentAndNextDescriptors() async throws {
        let currentID = artworkID("pilot", stage: .stageTwo)
        let nextID = artworkID("pilot", stage: .stageThree)
        let provider = CountingArtworkProvider(payloads: [
            currentID: try await payload(for: currentID),
            nextID: try await payload(for: nextID)
        ])
        let loader = CompanionPointCloudLoader(
            repository: CompanionPointCloudRepository(provider: provider)
        )

        loader.load(.init(current: currentID, next: nextID))

        let didLoad = await waitUntil {
            loader.state.current?.id == currentID && loader.state.next?.id == nextID
        }
        #expect(didLoad)
    }

    @MainActor
    @Test func staleLoadCannotReplaceTheNewestArtwork() async throws {
        let slowID = artworkID("slow", stage: .juvenile)
        let fastID = artworkID("fast", stage: .mature)
        let provider = CountingArtworkProvider(
            payloads: [
                slowID: try await payload(for: slowID),
                fastID: try await payload(for: fastID)
            ],
            suspended: [slowID, fastID]
        )
        let repository = CompanionPointCloudRepository(provider: provider)
        let loader = CompanionPointCloudLoader(repository: repository)

        loader.load(.init(current: slowID, next: nil))
        await provider.waitUntilRequested(slowID)
        loader.load(.init(current: fastID, next: nil))
        await provider.waitUntilRequested(fastID)

        await provider.finish(fastID)
        #expect(await waitUntil { loader.state.current?.id == fastID })

        await provider.finish(slowID)
        for _ in 0..<20 {
            await Task.yield()
        }
        #expect(loader.state.current?.id == fastID)
    }

    @MainActor
    @Test func missingArtworkPublishesFallback() async {
        let missingID = artworkID("missing", stage: .juvenile)
        let provider = CountingArtworkProvider(payloads: [:])
        let loader = CompanionPointCloudLoader(
            repository: CompanionPointCloudRepository(provider: provider)
        )

        loader.load(.init(current: missingID, next: nil))

        #expect(await waitUntil { loader.state == .fallback })
        #expect(await provider.requestCount(for: missingID) == 1)
    }

    @MainActor
    @Test func corruptArtworkPublishesFallback() async {
        let corruptID = artworkID("corrupt", stage: .juvenile)
        let corruptPayload = CompanionArtworkPayload(
            id: corruptID,
            data: Data([0x00, 0x01, 0x02]),
            fingerprint: "corrupt"
        )
        let provider = CountingArtworkProvider(payloads: [corruptID: corruptPayload])
        let loader = CompanionPointCloudLoader(
            repository: CompanionPointCloudRepository(provider: provider)
        )

        loader.load(.init(current: corruptID, next: nil))

        #expect(await waitUntil { loader.state == .fallback })
        #expect(await provider.requestCount(for: corruptID) == 1)
    }
}

private actor CountingArtworkProvider: CompanionArtworkDataProviding {
    private let payloads: [CompanionArtworkID: CompanionArtworkPayload]
    private var suspended: Set<CompanionArtworkID>
    private var requestCounts: [CompanionArtworkID: Int] = [:]
    private var requestWaiters: [CompanionArtworkID: [CheckedContinuation<Void, Never>]] = [:]
    private var payloadWaiters: [CompanionArtworkID: [CheckedContinuation<Void, Never>]] = [:]

    init(
        payloads: [CompanionArtworkID: CompanionArtworkPayload],
        suspended: Set<CompanionArtworkID> = []
    ) {
        self.payloads = payloads
        self.suspended = suspended
    }

    func payload(for id: CompanionArtworkID) async throws -> CompanionArtworkPayload? {
        requestCounts[id, default: 0] += 1
        requestWaiters.removeValue(forKey: id)?.forEach { $0.resume() }

        if suspended.contains(id) {
            await withCheckedContinuation { continuation in
                payloadWaiters[id, default: []].append(continuation)
            }
        }
        return payloads[id]
    }

    func requestCount(for id: CompanionArtworkID) -> Int {
        requestCounts[id, default: 0]
    }

    func waitUntilRequested(_ id: CompanionArtworkID) async {
        guard requestCounts[id, default: 0] == 0 else {
            return
        }
        await withCheckedContinuation { continuation in
            requestWaiters[id, default: []].append(continuation)
        }
    }

    func finish(_ id: CompanionArtworkID) {
        suspended.remove(id)
        payloadWaiters.removeValue(forKey: id)?.forEach { $0.resume() }
    }
}

private func artworkID(_ collectibleID: String, stage: CompanionStage) -> CompanionArtworkID {
    CompanionArtworkID(collectibleID: collectibleID, stage: stage)
}

private func payload(
    for id: CompanionArtworkID,
    renderMode: CompanionArtworkRenderMode = .pointCloud
) async throws -> CompanionArtworkPayload {
    let bundledID = CompanionArtworkID(collectibleID: "ordinary.sprout", stage: .juvenile)
    let provider = try BundledCompanionArtworkProvider(
        bundle: .main,
        subdirectory: "CompanionArtwork"
    )
    let bundledPayload = try #require(try await provider.payload(for: bundledID))
    return CompanionArtworkPayload(
        id: id,
        data: bundledPayload.data,
        fingerprint: "\(id.collectibleID)-\(id.stage.rawValue)",
        renderMode: renderMode
    )
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: @escaping @MainActor () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
        if condition() {
            return true
        }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}
