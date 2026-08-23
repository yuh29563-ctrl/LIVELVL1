import SwiftData
import SwiftUI

struct CollectionSelectionState: Equatable {
    private(set) var selectedAwardKey: String?
    private(set) var isShowingBack = false

    mutating func select(awardKey: String) {
        selectedAwardKey = awardKey
        isShowingBack = false
    }

    mutating func setShowingBack(_ isShowingBack: Bool) {
        self.isShowingBack = isShowingBack
    }

    mutating func close() {
        selectedAwardKey = nil
        isShowingBack = false
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

    private let onMarkedSeen: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    init(onMarkedSeen: @escaping () -> Void = {}) {
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
                                onRetry: markUnseenCollectiblesSeen
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
                                        Button {
                                            select(collectible)
                                        } label: {
                                            CollectibleCardView(
                                                collectible: collectible,
                                                definition: definition
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .onAppear {
                                            markVisibleCollectiblesSeen(collectible)
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
    }

    @ViewBuilder
    private var featuredContent: some View {
        if let collectible = ownedCollectibles.first,
           let definition = CollectionCatalog.definition(id: collectible.collectibleID) {
            Button {
                select(collectible)
            } label: {
                FeaturedCollectibleCardView(
                    collectible: collectible,
                    definition: definition
                )
            }
            .buttonStyle(.plain)
            .onAppear {
                markVisibleCollectiblesSeen(collectible)
            }
        } else {
            CompanionCardView(
                definition: activeCompanion.0,
                stage: activeCompanion.1
            )
        }
    }

    private func select(_ collectible: OwnedCollectible) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.34)) {
            selection.select(awardKey: collectible.awardKey)
        }
    }

    private func closeSelection() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.22)) {
            selection.close()
        }
    }

    private func markVisibleCollectiblesSeen(_ collectible: OwnedCollectible) {
        guard collectible.isUnseen else { return }
        markUnseenCollectiblesSeen()
    }

    private func markUnseenCollectiblesSeen() {
        guard seenRetryState.beginAttempt(
            hasUnseenCollectibles: hasUnseenCollectibles
        ) else {
            return
        }

        let result: Result<Void, Error>
        do {
            try CardRewardService.markAllSeen(in: context)
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
