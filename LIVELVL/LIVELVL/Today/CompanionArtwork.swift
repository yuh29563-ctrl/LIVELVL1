import CryptoKit
import Foundation

nonisolated struct CompanionArtworkID: Hashable, Codable, Sendable {
    let collectibleID: String
    let stage: CompanionStage
}

nonisolated enum CompanionArtworkRenderMode: String, Codable, Equatable, Sendable {
    case pointCloud
    case transparentRaster
}

nonisolated struct CompanionArtworkResource: Equatable, Sendable {
    let name: String
    let fileExtension: String
    let renderMode: CompanionArtworkRenderMode
}

nonisolated struct CompanionArtworkPayload: Equatable, Sendable {
    let id: CompanionArtworkID
    let data: Data
    let fingerprint: String
    let renderMode: CompanionArtworkRenderMode

    init(
        id: CompanionArtworkID,
        data: Data,
        fingerprint: String,
        renderMode: CompanionArtworkRenderMode = .pointCloud
    ) {
        self.id = id
        self.data = data
        self.fingerprint = fingerprint
        self.renderMode = renderMode
    }
}

protocol CompanionArtworkDataProviding: Sendable {
    func payload(for id: CompanionArtworkID) async throws -> CompanionArtworkPayload?
}

nonisolated enum CompanionArtworkManifestError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
    case unknownStage(String)
    case duplicateIdentity(CompanionArtworkID)
}

nonisolated struct CompanionArtworkManifest: Sendable {
    fileprivate let resources: [CompanionArtworkID: CompanionArtworkResource]

    static func decode(data: Data) throws -> Self {
        let decoded = try JSONDecoder().decode(DecodedManifest.self, from: data)
        guard decoded.version == 1 else {
            throw CompanionArtworkManifestError.unsupportedVersion(decoded.version)
        }

        var resources: [CompanionArtworkID: CompanionArtworkResource] = [:]
        for entry in decoded.entries {
            guard let stage = CompanionStage(manifestName: entry.stage) else {
                throw CompanionArtworkManifestError.unknownStage(entry.stage)
            }

            let id = CompanionArtworkID(collectibleID: entry.collectibleID, stage: stage)
            guard resources[id] == nil else {
                throw CompanionArtworkManifestError.duplicateIdentity(id)
            }
            resources[id] = CompanionArtworkResource(
                name: entry.resourceName,
                fileExtension: entry.fileExtension,
                renderMode: entry.renderMode ?? .pointCloud
            )
        }

        return Self(resources: resources)
    }

    func resource(for id: CompanionArtworkID) -> CompanionArtworkResource? {
        resources[id]
    }
}

nonisolated struct BundledCompanionArtworkProvider: CompanionArtworkDataProviding {
    private let resourceURLs: [CompanionArtworkID: URL]
    private let renderModes: [CompanionArtworkID: CompanionArtworkRenderMode]

    init(bundle: Bundle = .main, subdirectory: String = "CompanionArtwork") throws {
        guard let manifestURL = bundledResourceURL(
            named: "manifest",
            withExtension: "json",
            in: bundle,
            subdirectory: subdirectory
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let manifest = try CompanionArtworkManifest.decode(data: Data(contentsOf: manifestURL))
        var resourceURLs: [CompanionArtworkID: URL] = [:]
        var renderModes: [CompanionArtworkID: CompanionArtworkRenderMode] = [:]
        for (id, resource) in manifest.resources {
            guard let resourceURL = bundledResourceURL(
                named: resource.name,
                withExtension: resource.fileExtension,
                in: bundle,
                subdirectory: subdirectory
            ) else {
                throw CocoaError(.fileNoSuchFile)
            }
            resourceURLs[id] = resourceURL
            renderModes[id] = resource.renderMode
        }
        self.resourceURLs = resourceURLs
        self.renderModes = renderModes
    }

    func payload(for id: CompanionArtworkID) async throws -> CompanionArtworkPayload? {
        guard let resourceURL = resourceURLs[id] else {
            return nil
        }

        let data = try Data(contentsOf: resourceURL)
        let fingerprint = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return CompanionArtworkPayload(
            id: id,
            data: data,
            fingerprint: fingerprint,
            renderMode: renderModes[id] ?? .pointCloud
        )
    }
}

private extension CompanionStage {
    nonisolated init?(manifestName: String) {
        switch manifestName {
        case "juvenile": self = .juvenile
        case "stageTwo": self = .stageTwo
        case "stageThree": self = .stageThree
        case "mature": self = .mature
        default: return nil
        }
    }
}

private nonisolated struct DecodedManifest: Decodable {
    let version: Int
    let entries: [DecodedManifestEntry]
}

private nonisolated struct DecodedManifestEntry: Decodable {
    let collectibleID: String
    let stage: String
    let resourceName: String
    let fileExtension: String
    let renderMode: CompanionArtworkRenderMode?
}

private nonisolated func bundledResourceURL(
    named name: String,
    withExtension fileExtension: String,
    in bundle: Bundle,
    subdirectory: String
) -> URL? {
    bundle.url(forResource: name, withExtension: fileExtension, subdirectory: subdirectory)
        ?? bundle.url(forResource: name, withExtension: fileExtension)
}
