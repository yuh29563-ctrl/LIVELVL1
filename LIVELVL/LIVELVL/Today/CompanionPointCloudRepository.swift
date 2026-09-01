import Combine
import Foundation

nonisolated struct CompanionPointCloudRequest: Equatable, Sendable {
    let current: CompanionArtworkID
    let next: CompanionArtworkID?
}

nonisolated struct CompanionPointCloudPair: Equatable, Sendable {
    let current: CompanionPointCloudDescriptor
    let next: CompanionPointCloudDescriptor?
}

actor CompanionPointCloudRepository {
    private static let rendererVersion = 1
    private static let maximumCacheCount = 2

    private let provider: any CompanionArtworkDataProviding
    private let configuration: CompanionPointCloudExtractionConfiguration
    private var descriptors: [CacheKey: CompanionPointCloudDescriptor] = [:]
    private var cacheKeyByArtworkID: [CompanionArtworkID: CacheKey] = [:]
    private var leastRecentlyUsedKeys: [CacheKey] = []

    init(
        provider: any CompanionArtworkDataProviding,
        configuration: CompanionPointCloudExtractionConfiguration = .pilot
    ) {
        self.provider = provider
        self.configuration = configuration
    }

    func descriptor(for id: CompanionArtworkID) async throws -> CompanionPointCloudDescriptor? {
        try Task.checkCancellation()
        if let cacheKey = cacheKeyByArtworkID[id], let descriptor = descriptors[cacheKey] {
            markRecentlyUsed(cacheKey)
            return descriptor
        }

        guard let payload = try await provider.payload(for: id) else {
            return nil
        }
        try Task.checkCancellation()
        guard payload.id == id else {
            throw RepositoryError.mismatchedArtworkIdentity
        }

        let cacheKey = CacheKey(
            artworkID: id,
            fingerprint: payload.fingerprint,
            rendererVersion: Self.rendererVersion
        )
        if let descriptor = descriptors[cacheKey] {
            cacheKeyByArtworkID[id] = cacheKey
            markRecentlyUsed(cacheKey)
            return descriptor
        }

        guard let raster = CompanionArtworkRasterizer.raster(
            data: payload.data,
            maxDimension: configuration.maxRasterDimension
        ) else {
            throw RepositoryError.corruptArtwork
        }
        try Task.checkCancellation()

        let extracted = CompanionPointCloudExtractor.extract(
            id: id,
            raster: raster,
            configuration: configuration
        )
        let descriptor = CompanionPointCloudDescriptor(
            id: extracted.id,
            points: extracted.points,
            occupiedBounds: extracted.occupiedBounds,
            renderMode: payload.renderMode,
            sourceImageData: payload.renderMode == .transparentRaster ? payload.data : nil
        )
        try Task.checkCancellation()
        insert(descriptor, for: cacheKey)
        return descriptor
    }

    private func insert(_ descriptor: CompanionPointCloudDescriptor, for cacheKey: CacheKey) {
        if let previousKey = cacheKeyByArtworkID[cacheKey.artworkID], previousKey != cacheKey {
            descriptors.removeValue(forKey: previousKey)
            leastRecentlyUsedKeys.removeAll { $0 == previousKey }
        }

        descriptors[cacheKey] = descriptor
        cacheKeyByArtworkID[cacheKey.artworkID] = cacheKey
        markRecentlyUsed(cacheKey)

        while descriptors.count > Self.maximumCacheCount {
            let evictedKey = leastRecentlyUsedKeys.removeFirst()
            descriptors.removeValue(forKey: evictedKey)
            if cacheKeyByArtworkID[evictedKey.artworkID] == evictedKey {
                cacheKeyByArtworkID.removeValue(forKey: evictedKey.artworkID)
            }
        }
    }

    private func markRecentlyUsed(_ cacheKey: CacheKey) {
        leastRecentlyUsedKeys.removeAll { $0 == cacheKey }
        leastRecentlyUsedKeys.append(cacheKey)
    }
}

@MainActor
final class CompanionPointCloudLoader: ObservableObject {
    nonisolated enum State: Equatable, Sendable {
        case loading
        case loaded(CompanionPointCloudPair)
        case fallback

        var current: CompanionPointCloudDescriptor? {
            guard case let .loaded(pair) = self else {
                return nil
            }
            return pair.current
        }

        var next: CompanionPointCloudDescriptor? {
            guard case let .loaded(pair) = self else {
                return nil
            }
            return pair.next
        }
    }

    @Published private(set) var state: State = .fallback

    private let repository: CompanionPointCloudRepository
    private var latestRequest: CompanionPointCloudRequest?
    private var loadTask: Task<Void, Never>?

    init(repository: CompanionPointCloudRepository) {
        self.repository = repository
    }

    func load(_ request: CompanionPointCloudRequest) {
        loadTask?.cancel()
        latestRequest = request
        state = .loading

        loadTask = Task { [weak self, repository] in
            do {
                guard let current = try await repository.descriptor(for: request.current) else {
                    self?.publish(.fallback, for: request)
                    return
                }
                try Task.checkCancellation()

                let next: CompanionPointCloudDescriptor?
                if let nextID = request.next {
                    guard let nextDescriptor = try await repository.descriptor(for: nextID) else {
                        self?.publish(.fallback, for: request)
                        return
                    }
                    next = nextDescriptor
                } else {
                    next = nil
                }
                try Task.checkCancellation()

                self?.publish(
                    .loaded(CompanionPointCloudPair(current: current, next: next)),
                    for: request
                )
            } catch {
                self?.publish(.fallback, for: request)
            }
        }
    }

    private func publish(_ newState: State, for request: CompanionPointCloudRequest) {
        guard !Task.isCancelled, latestRequest == request else {
            return
        }
        state = newState
    }

    deinit {
        loadTask?.cancel()
    }
}

private nonisolated struct CacheKey: Hashable, Sendable {
    let artworkID: CompanionArtworkID
    let fingerprint: String
    let rendererVersion: Int
}

private nonisolated enum RepositoryError: Error, Sendable {
    case mismatchedArtworkIdentity
    case corruptArtwork
}
