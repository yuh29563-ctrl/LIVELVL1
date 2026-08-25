import Combine
import Foundation
import SwiftData

struct TodayCompanionMediaState {
    var media: UserCardMedia?
    var decoded: DecodedMedia?
    var isLoading = false
    var errorMessage: String?
}

@MainActor
final class TodayCompanionMediaController: ObservableObject {
    @Published private(set) var state = TodayCompanionMediaState(media: nil, decoded: nil)

    private var context: ModelContext?
    private var store: UserCardMediaStore?

    init(context: ModelContext? = nil, store: UserCardMediaStore? = nil) {
        self.context = context
        self.store = store
    }

    func configure(context: ModelContext) {
        self.context = context
        guard store == nil else { return }
        let rootURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appending(path: "UserCardMedia", directoryHint: .isDirectory)
        store = UserCardMediaStore(rootURL: rootURL)
    }

    func load() async {
        guard let context, let store else { return }
        state.isLoading = true
        defer { state.isLoading = false }

        do {
            let media = try context.fetch(FetchDescriptor<UserCardMedia>()).first
            guard let media else {
                state = TodayCompanionMediaState(media: nil, decoded: nil)
                return
            }
            let decoded = try AnimatedMediaDecoder.decode(
                data: store.load(media),
                maxPixelSize: 720,
                allowsAnimation: true
            )
            state = TodayCompanionMediaState(media: media, decoded: decoded)
        } catch {
            state.errorMessage = "陪伴卡背景图片无法读取"
        }
    }

    func importMedia(data: Data) async {
        guard let context, let store else { return }
        state.isLoading = true
        defer { state.isLoading = false }

        do {
            let decoded = try AnimatedMediaDecoder.decode(
                data: data,
                maxPixelSize: 720,
                allowsAnimation: true
            )
            let media = try store.save(
                data: data,
                kind: decoded.kind,
                replacing: state.media,
                now: .now,
                in: context
            )
            try context.save()
            state = TodayCompanionMediaState(media: media, decoded: decoded)
        } catch {
            state.errorMessage = "背景图片导入失败，请重试"
        }
    }

    func removeMedia() throws {
        guard let context, let store, let media = state.media else { return }
        try store.delete(media, from: context)
        try context.save()
        state = TodayCompanionMediaState(media: nil, decoded: nil)
    }
}
