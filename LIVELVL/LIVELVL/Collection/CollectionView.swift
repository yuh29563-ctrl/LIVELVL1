import SwiftData
import SwiftUI

nonisolated enum CollectionCardFocusTarget: Hashable, Sendable {
    case featured(awardKey: String)
    case grid(awardKey: String)

    var awardKey: String {
        switch self {
        case let .featured(awardKey), let .grid(awardKey):
            awardKey
        }
    }
}

nonisolated enum ArchiveAccessibilityFocusRestoration {
    static func target(awardKey: String) -> CollectionCardFocusTarget {
        .grid(awardKey: awardKey)
    }
}

private struct ArchiveArrivalTaskID: Hashable {
    let sequenceID: UUID?
    let isCollectionSelected: Bool
    let isObscured: Bool
    let isSceneActive: Bool
}

private struct TarotDayRefreshTaskID: Hashable {
    let dayIdentifier: String
    let isSceneActive: Bool
    let scheduleRevision: Int
}

struct CollectionSeenVisibilityState: Equatable, Sendable {
    private var centeredAwardKey: String?

    mutating func center(_ awardKey: String?) {
        centeredAwardKey = awardKey
    }

    mutating func appeared(_ target: CollectionCardFocusTarget) {
        centeredAwardKey = target.awardKey
    }

    mutating func disappeared(_ target: CollectionCardFocusTarget) {
        if centeredAwardKey == target.awardKey {
            centeredAwardKey = nil
        }
    }

    func awardKeysToMarkSeen(
        unseenAwardKeys: Set<String>,
        isCollectionSelected: Bool,
        isObscured: Bool
    ) -> Set<String> {
        guard isCollectionSelected,
              !isObscured,
              let centeredAwardKey,
              unseenAwardKeys.contains(centeredAwardKey) else {
            return []
        }
        return [centeredAwardKey]
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

    var needsRetry: Bool { errorMessage != nil }

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

@MainActor
struct CollectionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: [
        SortDescriptor(\OwnedCollectible.acquiredAt, order: .reverse),
        SortDescriptor(\OwnedCollectible.awardKey)
    ])
    private var ownedCollectibles: [OwnedCollectible]
    @Query private var collectionProgress: [CollectionProgress]
    @Query private var tarotDailyStates: [TarotDailyState]

    @State private var archiveState = ArchiveCarouselState()
    @State private var arrivingAwardKey: String?
    @State private var arrivalTraceProgress = 0.0
    @State private var arrivalSequenceID: UUID?
    @State private var seenRetryState = CollectionSeenRetryState()
    @State private var seenVisibility = CollectionSeenVisibilityState()
    @State private var isShowingTarot = false
    @State private var tarotDayClock: TarotDayClock
    @State private var tarotDayScheduleRevision = 0
    @AccessibilityFocusState private var focusedCard: CollectionCardFocusTarget?

    private let isCollectionSelected: Bool
    private let isObscured: Bool
    @Binding private var arrivalState: ArchiveArrivalPresentationState
    private let onMarkedSeen: () -> Void

    init(
        isCollectionSelected: Bool = true,
        isObscured: Bool = false,
        initiallyShowsTarot: Bool = false,
        tarotDayClock: TarotDayClock? = nil,
        arrivalState: Binding<ArchiveArrivalPresentationState> = .constant(
            ArchiveArrivalPresentationState()
        ),
        onMarkedSeen: @escaping () -> Void = {}
    ) {
        self.isCollectionSelected = isCollectionSelected
        self.isObscured = isObscured
        _isShowingTarot = State(initialValue: initiallyShowsTarot)
        _tarotDayClock = State(initialValue: tarotDayClock ?? TarotDayClock())
        _arrivalState = arrivalState
        self.onMarkedSeen = onMarkedSeen
    }

    private var archiveItems: [ArchiveCollectiblePresentation] {
        ownedCollectibles.compactMap { collectible in
            guard let definition = CollectionCatalog.definition(id: collectible.collectibleID) else {
                return nil
            }
            return ArchiveCollectiblePresentation(
                collectible: collectible,
                definition: definition
            )
        }
    }

    private var orderedAwardKeys: [String] {
        archiveItems.map(\.id)
    }

    private var expandedItem: ArchiveCollectiblePresentation? {
        guard let key = archiveState.expandedAwardKey else { return nil }
        return archiveItems.first { $0.id == key }
    }

    private var centeredAwardKeyBinding: Binding<String?> {
        Binding(
            get: { archiveState.centeredAwardKey },
            set: { key in
                archiveState.updateScrollPosition(
                    key,
                    orderedAwardKeys: orderedAwardKeys
                )
                seenVisibility.center(archiveState.centeredAwardKey)
            }
        )
    }

    private var showingBackBinding: Binding<Bool> {
        Binding(
            get: { archiveState.isShowingBack },
            set: { archiveState.setShowingBack($0) }
        )
    }

    private var hasUnseenCollectibles: Bool {
        ownedCollectibles.contains(where: \.isUnseen)
    }

    private var unseenAwardKeys: Set<String> {
        Set(ownedCollectibles.lazy.filter(\.isUnseen).map(\.awardKey))
    }

    private var activeCompanion: (CollectibleDefinition, CompanionStage) {
        guard let progress = collectionProgress.first,
              let definition = CollectionCatalog.ordinary(at: progress.activeOrdinaryIndex) else {
            return (CollectionCatalog.ordinary[0], .juvenile)
        }
        return (definition, progress.activeStage)
    }

    private var tarotEntryPresentation: ArchiveTarotEntryPresentation {
        guard let state = tarotDailyStates.first(where: {
            $0.singletonKey == "tarot.daily"
                && $0.dayIdentifier == tarotDayClock.dayIdentifier
        }) else {
            return ArchiveTarotEntryPresentation(status: .ready)
        }
        guard let selectedIndex = state.selectedIndex else {
            return ArchiveTarotEntryPresentation(status: .choosing)
        }
        guard state.candidateCardIDs.indices.contains(selectedIndex),
              state.candidateOrientations.indices.contains(selectedIndex),
              let definition = TarotCatalog.definition(
                id: state.candidateCardIDs[selectedIndex]
              ) else {
            return ArchiveTarotEntryPresentation(status: .choosing)
        }
        return ArchiveTarotEntryPresentation(
            status: .completed(
                cardName: definition.name,
                englishName: definition.englishName,
                orientation: state.candidateOrientations[selectedIndex].title,
                artworkAssetName: definition.artworkAssetName
            )
        )
    }

    var body: some View {
        ZStack {
            NavigationStack {
                Group {
                    if ArchiveCarouselLayout.usesVerticalPageScroll(
                        isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
                    ) {
                        ScrollView(.vertical) {
                            archivePageContent
                        }
                        .scrollIndicators(.hidden)
                    } else {
                        archivePageContent
                    }
                }
                .background(LivingOSTheme.canvas)
                .toolbar(.hidden, for: .navigationBar)
            }
            .fullScreenCover(isPresented: $isShowingTarot) {
                TarotDailyView(dayClock: tarotDayClock)
            }
            .accessibilityHidden(expandedItem != nil)

            if arrivingAwardKey != nil, !reduceMotion {
                ArchiveArrivalTrace(progress: arrivalTraceProgress)
                    .transition(.opacity)
                    .zIndex(0.5)
            }

            if let expandedItem {
                ArchiveExpandedView(
                    collectible: expandedItem.collectible,
                    definition: expandedItem.definition,
                    isShowingBack: showingBackBinding,
                    onClose: closeExpanded
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .scale(scale: 0.82).combined(with: .opacity)
                )
                .zIndex(1)
            }
        }
        .onChange(of: orderedAwardKeys, initial: true) { _, keys in
            archiveState.reconcile(orderedAwardKeys: keys)
            seenVisibility.center(archiveState.centeredAwardKey)
            presentPendingArrival()
            markVisibleCollectiblesSeen()
        }
        .onChange(of: archiveState.centeredAwardKey) { _, key in
            seenVisibility.center(key)
            markVisibleCollectiblesSeen()
        }
        .onChange(of: hasUnseenCollectibles, initial: true) { _, hasUnseen in
            seenRetryState.reconcile(hasUnseenCollectibles: hasUnseen)
        }
        .onChange(of: unseenAwardKeys, initial: true) { _, _ in
            markVisibleCollectiblesSeen()
        }
        .onChange(of: isCollectionSelected, initial: true) { _, _ in
            presentPendingArrival()
            markVisibleCollectiblesSeen()
        }
        .onChange(of: isObscured, initial: true) { _, _ in
            presentPendingArrival()
            markVisibleCollectiblesSeen()
        }
        .onChange(of: arrivalState) { _, _ in
            presentPendingArrival()
        }
        .onChange(of: scenePhase) { _, _ in
            presentPendingArrival()
            markVisibleCollectiblesSeen()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshTarotDay(reschedule: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            refreshTarotDay(reschedule: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)) { _ in
            refreshTarotDay(reschedule: true)
        }
        .task(id: TarotDayRefreshTaskID(
            dayIdentifier: tarotDayClock.dayIdentifier,
            isSceneActive: scenePhase == .active,
            scheduleRevision: tarotDayScheduleRevision
        )) {
            guard scenePhase == .active else { return }
            await tarotDayClock.waitUntilNextDay()
        }
        .task(id: ArchiveArrivalTaskID(
            sequenceID: arrivalSequenceID,
            isCollectionSelected: isCollectionSelected,
            isObscured: isObscured,
            isSceneActive: scenePhase == .active
        )) {
            guard arrivalSequenceID != nil,
                  let awardKey = arrivingAwardKey,
                  ArchiveArrivalPresentationActivity.shouldAdvance(
                    isCollectionSelected: isCollectionSelected,
                    isObscured: isObscured,
                    isSceneActive: scenePhase == .active
                  ) else { return }
            do {
                try await Task.sleep(
                    for: reduceMotion ? .milliseconds(240) : .milliseconds(820)
                )
            } catch {
                return
            }
            guard !Task.isCancelled,
                  arrivingAwardKey == awardKey,
                  ArchiveArrivalPresentationActivity.shouldAdvance(
                    isCollectionSelected: isCollectionSelected,
                    isObscured: isObscured,
                    isSceneActive: scenePhase == .active
                  ) else { return }
            arrivalState.markCompleted(awardKey: awardKey)
            withAnimation(.easeOut(duration: 0.16)) {
                arrivingAwardKey = nil
            }
            arrivalTraceProgress = 0
            arrivalSequenceID = nil
            markVisibleCollectiblesSeen()
            presentPendingArrival()
        }
    }

    private var archivePageContent: some View {
        ZStack(alignment: .top) {
            ArchiveSceneLightField()
                .ignoresSafeArea(edges: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                archiveHeader

                if archiveItems.isEmpty {
                    emptyArchiveContent
                } else {
                    ArchiveCarouselView(
                        items: archiveItems,
                        centeredAwardKey: centeredAwardKeyBinding,
                        expandedAwardKey: archiveState.expandedAwardKey,
                        focusedCard: $focusedCard,
                        tarotPresentation: tarotEntryPresentation,
                        onExpand: expand,
                        onOpenTarot: { isShowingTarot = true }
                    )
                    .padding(.top, ArchiveCarouselLayout.pageTopPadding)
                }

                if let errorMessage = seenRetryState.errorMessage {
                    CollectionSeenRetryView(
                        message: errorMessage,
                        isRetrying: seenRetryState.isAttempting,
                        onRetry: { markUnseenCollectiblesSeen() }
                    )
                    .padding(.horizontal, LivingOSMetrics.pageHorizontalInset)
                }

                Spacer(minLength: RootTabPageLayout.contentBottomPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var archiveHeader: some View {
        let displayIndex = ArchiveCarouselPosition.displayIndex(
            awardKey: archiveState.centeredAwardKey,
            awardKeys: orderedAwardKeys
        )

        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Archive")
                    .font(.largeTitle.bold())
                    .tracking(-1.3)
                    .foregroundStyle(LivingOSTheme.ink)
                Text("\(displayIndex) / \(archiveItems.count)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(LivingOSTheme.graphite)
                    .accessibilityLabel("第\(displayIndex)张，共\(archiveItems.count)张")
            }

            Spacer()

            NavigationLink {
                CatalogView()
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.body.weight(.medium))
                    .foregroundStyle(LivingOSTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.64), in: Circle())
            }
            .accessibilityLabel("打开图鉴与筛选")
        }
        .padding(.horizontal, LivingOSMetrics.pageHorizontalInset)
        .padding(.top, 18)
    }

    private var emptyArchive: some View {
        VStack(spacing: 18) {
            ArchiveOrganismArtwork(identifier: activeCompanion.0.id)
                .frame(width: 180, height: 260)
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.86), LivingOSTheme.mist.opacity(0.58)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(
                        cornerRadius: LivingOSMetrics.archiveCardCornerRadius,
                        style: .continuous
                    )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 18, y: 10)

            Text("第一张卡正在成长")
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
            Text("\(activeCompanion.0.name) · \(activeCompanion.1.todayTitle)")
                .font(.footnote)
                .foregroundStyle(LivingOSTheme.graphite)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 34)
        .accessibilityElement(children: .combine)
    }

    private var emptyArchiveContent: some View {
        VStack(spacing: 0) {
            emptyArchive

            Spacer(minLength: 24)

            ArchiveTarotEntry(
                presentation: tarotEntryPresentation,
                action: { isShowingTarot = true }
            )
            .padding(.horizontal, LivingOSMetrics.pageHorizontalInset)
            .padding(.bottom, ArchiveCarouselLayout.drawPreviewBottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func expand(_ awardKey: String) {
        archiveState.center(awardKey)
        focusedCard = nil
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.84)) {
            archiveState.expandCentered()
        }
    }

    private func closeExpanded() {
        let key = archiveState.expandedAwardKey
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.28)) {
            archiveState.closeExpanded()
        }
        guard let key else { return }
        Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            focusedCard = ArchiveAccessibilityFocusRestoration.target(awardKey: key)
            presentPendingArrival()
        }
    }

    private func presentPendingArrival() {
        guard isCollectionSelected,
              !isObscured,
              scenePhase == .active,
              expandedItem == nil,
              arrivingAwardKey == nil,
              let awardKey = arrivalState.takeArrivalIfNeeded(
                validAwardKeys: Set(orderedAwardKeys)
              ) else {
            return
        }

        arrivingAwardKey = awardKey
        arrivalTraceProgress = 0
        arrivalSequenceID = UUID()
        withAnimation(
            ArchiveArrivalMotion.allowsAnimatedCentering(reduceMotion: reduceMotion)
                ? .spring(response: 0.46, dampingFraction: 0.86)
                : nil
        ) {
            archiveState.center(awardKey)
        }
        seenVisibility.center(awardKey)

        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.72)) {
            arrivalTraceProgress = 1
        }
    }

    private func refreshTarotDay(reschedule: Bool) {
        tarotDayClock.refresh()
        if reschedule {
            tarotDayScheduleRevision &+= 1
        }
    }

    private func markVisibleCollectiblesSeen() {
        let awardKeys = seenVisibility.awardKeysToMarkSeen(
            unseenAwardKeys: unseenAwardKeys,
            isCollectionSelected: isCollectionSelected,
            isObscured: isObscured || arrivingAwardKey != nil
        )
        markUnseenCollectiblesSeen(awardKeys: awardKeys)
    }

    private func markUnseenCollectiblesSeen(awardKeys: Set<String>? = nil) {
        let awardKeys = awardKeys ?? seenVisibility.awardKeysToMarkSeen(
            unseenAwardKeys: unseenAwardKeys,
            isCollectionSelected: isCollectionSelected,
            isObscured: isObscured
        )
        guard seenRetryState.beginAttempt(hasUnseenCollectibles: !awardKeys.isEmpty) else {
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

private struct ArchiveArrivalTrace: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    let progress: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: pausesTimeline)) { timeline in
            let phase = reduceMotion
                ? 0
                : timeline.date.timeIntervalSinceReferenceDate / 3.6
            let samples = ArchiveArrivalTraceGeometry.samples(
                progress: progress,
                phase: phase,
                reduceMotion: reduceMotion
            )

            Canvas { context, size in
                for sample in samples {
                    let diameter = sample.diameter
                    let rect = CGRect(
                        x: sample.position.x * size.width - diameter / 2,
                        y: sample.position.y * size.height - diameter / 2,
                        width: diameter,
                        height: diameter
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(LivingOSTheme.ink.opacity(sample.opacity * 0.62))
                    )
                }
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var pausesTimeline: Bool {
        LivingOSAnimationActivity.isPaused(
            reduceMotion: reduceMotion,
            isVisible: isVisible,
            isSceneActive: scenePhase == .active
        )
    }
}

private struct CollectionSeenRetryView: View {
    let message: String
    let isRetrying: Bool
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LivingOSTheme.signal)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(message)
                .font(.footnote)
                .foregroundStyle(LivingOSTheme.graphite)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("重试", action: onRetry)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(LivingOSTheme.ink)
                .disabled(isRetrying)
        }
        .padding(14)
        .background(Color.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }
}

#Preview("Empty Archive") {
    CollectionView()
        .modelContainer(
            for: [CollectionProgress.self, OwnedCollectible.self, TarotDailyState.self],
            inMemory: true
        )
}
