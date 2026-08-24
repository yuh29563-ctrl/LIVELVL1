import SwiftData
import SwiftUI

enum CollectionCardFocusTarget: Hashable, Sendable {
    case featured(awardKey: String)
    case grid(awardKey: String)

    var awardKey: String {
        switch self {
        case let .featured(awardKey), let .grid(awardKey):
            awardKey
        }
    }
}

struct CollectionSeenVisibilityState: Equatable, Sendable {
    private var visibleTargets: Set<CollectionCardFocusTarget> = []

    mutating func appeared(_ target: CollectionCardFocusTarget) {
        visibleTargets.insert(target)
    }

    mutating func disappeared(_ target: CollectionCardFocusTarget) {
        visibleTargets.remove(target)
    }

    func awardKeysToMarkSeen(
        unseenAwardKeys: Set<String>,
        isCollectionSelected: Bool,
        isObscured: Bool
    ) -> Set<String> {
        guard isCollectionSelected, !isObscured else { return [] }
        return Set(visibleTargets.map(\.awardKey)).intersection(unseenAwardKeys)
    }
}

struct CollectionSelectionState: Equatable {
    private(set) var selectedAwardKey: String?
    private(set) var isShowingBack = false
    private var initiatingFocusTarget: CollectionCardFocusTarget?

    mutating func select(focusTarget: CollectionCardFocusTarget) {
        selectedAwardKey = focusTarget.awardKey
        initiatingFocusTarget = focusTarget
        isShowingBack = false
    }

    mutating func setShowingBack(_ isShowingBack: Bool) {
        self.isShowingBack = isShowingBack
    }

    @discardableResult
    mutating func close() -> CollectionCardFocusTarget? {
        let focusTarget = initiatingFocusTarget
        selectedAwardKey = nil
        initiatingFocusTarget = nil
        isShowingBack = false
        return focusTarget
    }

    mutating func reconcile(validAwardKeys: Set<String>) {
        guard let selectedAwardKey,
              !validAwardKeys.contains(selectedAwardKey) else {
            return
        }
        close()
    }
}

struct CollectionSeenRetryState: Equatable {
    private(set) var isAttempting = false
    private(set) var errorMessage: String?

    var needsRetry: Bool {
        errorMessage != nil
    }

    mutating func beginAttempt(hasUnseenCollectibles: Bool) -> Bool {
        guard hasUnseenCollectibles, !isAttempting else { return false }
        isAttempting = true
        return true
    }

    mutating func finishAttempt(_ result: Result<Void, Error>) -> Bool {
        guard isAttempting else { return false }
        isAttempting = false

        switch result {
        case .success:
            errorMessage = nil
            return true
        case .failure:
            errorMessage = "未能更新查看状态"
            return false
        }
    }

    mutating func reconcile(hasUnseenCollectibles: Bool) {
        guard !hasUnseenCollectibles else { return }
        isAttempting = false
        errorMessage = nil
    }
}

private struct SelectedCollectiblePresentation {
    let collectible: OwnedCollectible
    let definition: CollectibleDefinition
}

@MainActor
struct CollectionView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [
        SortDescriptor(\OwnedCollectible.acquiredAt, order: .reverse),
        SortDescriptor(\OwnedCollectible.awardKey)
    ])
    private var ownedCollectibles: [OwnedCollectible]
    @Query private var collectionProgress: [CollectionProgress]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection = CollectionSelectionState()
    @State private var seenRetryState = CollectionSeenRetryState()
    @State private var seenVisibility = CollectionSeenVisibilityState()
    @AccessibilityFocusState private var focusedCard: CollectionCardFocusTarget?

    private let isCollectionSelected: Bool
    private let isObscured: Bool
    private let onMarkedSeen: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    init(
        isCollectionSelected: Bool = true,
        isObscured: Bool = false,
        onMarkedSeen: @escaping () -> Void = {}
    ) {
        self.isCollectionSelected = isCollectionSelected
        self.isObscured = isObscured
        self.onMarkedSeen = onMarkedSeen
    }

    private var validatedSelection: SelectedCollectiblePresentation? {
        guard let selectedAwardKey = selection.selectedAwardKey,
              let collectible = ownedCollectibles.first(where: {
                  $0.awardKey == selectedAwardKey
              }),
              let definition = CollectionCatalog.definition(id: collectible.collectibleID) else {
            return nil
        }
        return SelectedCollectiblePresentation(
            collectible: collectible,
            definition: definition
        )
    }

    private var selectableAwardKeys: Set<String> {
        Set(ownedCollectibles.compactMap { collectible in
            CollectionCatalog.definition(id: collectible.collectibleID) == nil
                ? nil
                : collectible.awardKey
        })
    }

    private var hasUnseenCollectibles: Bool {
        ownedCollectibles.contains(where: \.isUnseen)
    }

    private var unseenAwardKeys: Set<String> {
        Set(ownedCollectibles.lazy.filter(\.isUnseen).map(\.awardKey))
    }

    private var showingBackBinding: Binding<Bool> {
        Binding(
            get: { selection.isShowingBack },
            set: { selection.setShowingBack($0) }
        )
    }

    private var activeCompanion: (CollectibleDefinition, CompanionStage) {
        guard let progress = collectionProgress.first,
              let definition = CollectionCatalog.ordinary(at: progress.activeOrdinaryIndex) else {
            return (CollectionCatalog.ordinary[0], .juvenile)
        }
        return (definition, progress.activeStage)
    }

    var body: some View {
        let validatedSelection = validatedSelection

        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        featuredContent

                        if let errorMessage = seenRetryState.errorMessage {
                            CollectionSeenRetryView(
                                message: errorMessage,
                                isRetrying: seenRetryState.isAttempting,
                                onRetry: { markUnseenCollectiblesSeen() }
                            )
                        }

                        if !ownedCollectibles.isEmpty {
                            Text("收藏卡片")
                                .font(.headline)
                                .foregroundStyle(TodayVisualTheme.ink)
                                .accessibilityAddTraits(.isHeader)

                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(ownedCollectibles, id: \.awardKey) { collectible in
                                    if let definition = CollectionCatalog.definition(
                                        id: collectible.collectibleID
                                    ) {
                                        let focusTarget = CollectionCardFocusTarget.grid(
                                            awardKey: collectible.awardKey
                                        )
                                        Button {
                                            select(focusTarget: focusTarget)
                                        } label: {
                                            CollectibleCardView(
                                                collectible: collectible,
                                                definition: definition
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityFocused(
                                            $focusedCard,
                                            equals: focusTarget
                                        )
                                        .onAppear {
                                            visibleCardAppeared(focusTarget)
                                        }
                                        .onDisappear {
                                            visibleCardDisappeared(focusTarget)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .background(TodayVisualTheme.pageBackground)
                .navigationTitle("收集")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            CatalogView()
                        } label: {
                            Image(systemName: "books.vertical.fill")
                        }
                        .accessibilityLabel("打开图鉴")
                    }
                }
            }
            .accessibilityHidden(validatedSelection != nil)

            if let validatedSelection {
                ExpandedCollectibleCardOverlay(
                    collectible: validatedSelection.collectible,
                    definition: validatedSelection.definition,
                    isShowingBack: showingBackBinding,
                    onClose: closeSelection
                )
                .transition(
                    reduceMotion
                        ? .opacity
                        : .scale(scale: 0.94).combined(with: .opacity)
                )
                .zIndex(1)
            }
        }
        .onChange(of: selectableAwardKeys, initial: true) { _, validAwardKeys in
            selection.reconcile(validAwardKeys: validAwardKeys)
        }
        .onChange(of: hasUnseenCollectibles, initial: true) { _, hasUnseen in
            seenRetryState.reconcile(hasUnseenCollectibles: hasUnseen)
        }
        .onChange(of: unseenAwardKeys, initial: true) { _, _ in
            markVisibleCollectiblesSeen()
        }
        .onChange(of: isCollectionSelected, initial: true) { _, _ in
            markVisibleCollectiblesSeen()
        }
        .onChange(of: isObscured, initial: true) { _, _ in
            markVisibleCollectiblesSeen()
        }
    }

    @ViewBuilder
    private var featuredContent: some View {
        if let collectible = ownedCollectibles.first,
           let definition = CollectionCatalog.definition(id: collectible.collectibleID) {
            let focusTarget = CollectionCardFocusTarget.featured(
                awardKey: collectible.awardKey
            )
            Button {
                select(focusTarget: focusTarget)
            } label: {
                FeaturedCollectibleCardView(
                    collectible: collectible,
                    definition: definition
                )
            }
            .buttonStyle(.plain)
            .accessibilityFocused($focusedCard, equals: focusTarget)
            .onAppear {
                visibleCardAppeared(focusTarget)
            }
            .onDisappear {
                visibleCardDisappeared(focusTarget)
            }
        } else {
            CompanionCardView(
                definition: activeCompanion.0,
                stage: activeCompanion.1
            )
        }
    }

    private func select(focusTarget: CollectionCardFocusTarget) {
        focusedCard = nil
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.34)) {
            selection.select(focusTarget: focusTarget)
        }
    }

    private func closeSelection() {
        let focusTarget = withAnimation(
            reduceMotion ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.22)
        ) {
            selection.close()
        }
        guard let focusTarget else { return }
        Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            focusedCard = focusTarget
        }
    }

    private func visibleCardAppeared(_ focusTarget: CollectionCardFocusTarget) {
        seenVisibility.appeared(focusTarget)
        markVisibleCollectiblesSeen()
    }

    private func visibleCardDisappeared(_ focusTarget: CollectionCardFocusTarget) {
        seenVisibility.disappeared(focusTarget)
    }

    private func markVisibleCollectiblesSeen() {
        let awardKeys = seenVisibility.awardKeysToMarkSeen(
            unseenAwardKeys: unseenAwardKeys,
            isCollectionSelected: isCollectionSelected,
            isObscured: isObscured
        )
        markUnseenCollectiblesSeen(awardKeys: awardKeys)
    }

    private func markUnseenCollectiblesSeen(awardKeys: Set<String>? = nil) {
        let awardKeys = awardKeys ?? seenVisibility.awardKeysToMarkSeen(
            unseenAwardKeys: unseenAwardKeys,
            isCollectionSelected: isCollectionSelected,
            isObscured: isObscured
        )
        guard seenRetryState.beginAttempt(
            hasUnseenCollectibles: !awardKeys.isEmpty
        ) else {
            return
        }

        let result: Result<Void, Error>
        do {
            try CardRewardService.markSeen(awardKeys: awardKeys, in: context)
            result = .success(())
        } catch {
            result = .failure(error)
        }

        if seenRetryState.finishAttempt(result) {
            onMarkedSeen()
        }
    }
}

private struct CollectionSeenRetryView: View {
    let message: String
    let isRetrying: Bool
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(TodayVisualTheme.graphite)
                .accessibilityHidden(true)

            Text(message)
                .font(.footnote)
                .foregroundStyle(TodayVisualTheme.graphite)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("重试", action: onRetry)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(TodayVisualTheme.ink)
                .disabled(isRetrying)
        }
        .padding(14)
        .background(
            TodayVisualTheme.cloud,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }
}

#Preview("Empty Collection") {
    CollectionView()
        .modelContainer(for: [CollectionProgress.self, OwnedCollectible.self], inMemory: true)
}
