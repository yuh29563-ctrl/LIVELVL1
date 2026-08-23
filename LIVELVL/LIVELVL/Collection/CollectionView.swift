import SwiftData
import SwiftUI

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
    @State private var selectedAwardKey: String?
    @State private var isShowingBack = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var selectedCollectible: OwnedCollectible? {
        guard let selectedAwardKey else { return nil }
        return ownedCollectibles.first { $0.awardKey == selectedAwardKey }
    }

    private var activeCompanion: (CollectibleDefinition, CompanionStage) {
        guard let progress = collectionProgress.first,
              let definition = CollectionCatalog.ordinary(at: progress.activeOrdinaryIndex) else {
            return (CollectionCatalog.ordinary[0], .juvenile)
        }
        return (definition, progress.activeStage)
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        featuredContent

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
            .accessibilityHidden(selectedAwardKey != nil)

            if let collectible = selectedCollectible,
               let definition = CollectionCatalog.definition(id: collectible.collectibleID) {
                ExpandedCollectibleCardOverlay(
                    collectible: collectible,
                    definition: definition,
                    isShowingBack: $isShowingBack,
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
        isShowingBack = false
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.34)) {
            selectedAwardKey = collectible.awardKey
        }
    }

    private func closeSelection() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.22)) {
            selectedAwardKey = nil
            isShowingBack = false
        }
    }

    private func markVisibleCollectiblesSeen(_ collectible: OwnedCollectible) {
        guard collectible.isUnseen else { return }
        try? CardRewardService.markAllSeen(in: context)
    }
}

#Preview("Empty Collection") {
    CollectionView()
        .modelContainer(for: [CollectionProgress.self, OwnedCollectible.self], inMemory: true)
}
