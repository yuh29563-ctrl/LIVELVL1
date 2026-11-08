import SwiftData
import SwiftUI

@MainActor
struct CatalogView: View {
    @Query private var ownedCollectibles: [OwnedCollectible]

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var unlockedIDs: Set<String> {
        let catalogIDs = Set(CollectionCatalog.all.map(\.id))
        return Set(ownedCollectibles.map(\.collectibleID)).intersection(catalogIDs)
    }

    private var visibleDefinitions: [CollectibleDefinition] {
        CollectionCatalog.visibleDefinitions(ownedIDs: unlockedIDs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    Text("发现进度")
                        .font(.headline)
                        .foregroundStyle(TodayVisualTheme.ink)

                    Spacer()

                    Text("\(unlockedIDs.count) / \(visibleDefinitions.count)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(TodayVisualTheme.ink)
                        .accessibilityLabel(
                            "已发现 \(unlockedIDs.count) 个，共 \(visibleDefinitions.count) 个"
                        )
                }

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(visibleDefinitions) { definition in
                        CatalogCardView(
                            definition: definition,
                            isUnlocked: unlockedIDs.contains(definition.id)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(TodayVisualTheme.pageBackground)
        .navigationTitle("卡库")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CatalogCardView: View {
    let definition: CollectibleDefinition
    let isUnlocked: Bool

    private var displayName: String {
        if !isUnlocked, definition.kind == .hidden {
            return "隐藏物种"
        }
        return definition.name
    }

    private var stateLabel: String {
        isUnlocked ? "已发现" : "尚未发现"
    }

    var body: some View {
        VStack(spacing: 12) {
            PixelSpeciesArtwork(
                definition: definition,
                stage: .mature,
                isSilhouette: !isUnlocked
            )
            .frame(maxHeight: .infinity)

            VStack(spacing: 4) {
                Text(displayName)
                    .font(.headline)
                    .foregroundStyle(isUnlocked ? TodayVisualTheme.ink : TodayVisualTheme.graphite)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(stateLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(TodayVisualTheme.graphite)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .background(
            Color.white,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(TodayVisualTheme.mist.opacity(0.75), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(displayName)，\(stateLabel)")
    }
}

#Preview("Catalog") {
    NavigationStack {
        CatalogView()
    }
    .modelContainer(for: OwnedCollectible.self, inMemory: true)
}
