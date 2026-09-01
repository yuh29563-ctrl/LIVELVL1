import Foundation
import Testing
@testable import LIVELVL

@MainActor
struct TodayCompanionLevelCardTests {
    @Test func lifeCoreDisplayModeDefaultsExpandedAndTogglesBothWays() {
        var mode = LifeCoreDisplayMode.initial

        #expect(mode == .expanded)
        mode.toggle()
        #expect(mode == .compact)
        mode.toggle()
        #expect(mode == .expanded)
    }

    @Test func lifeCoreToggleArrowMatchesTheActionItWillPerform() {
        #expect(LifeCoreDisplayMode.expanded.toggleSymbolName == "chevron.up")
        #expect(LifeCoreDisplayMode.compact.toggleSymbolName == "chevron.down")
    }

    @Test func compactLifeCoreReservesAnIndependentDockAboveTheField() {
        let regular = LifeCoreDockLayout.metrics(
            displayMode: .compact,
            isAccessibilitySize: false
        )
        let accessibility = LifeCoreDockLayout.metrics(
            displayMode: .compact,
            isAccessibilitySize: true
        )

        #expect(regular.dockHeight == 44)
        #expect(regular.spacing == 28)
        #expect(regular.fieldHeight == 492)
        #expect(regular.fieldOriginY == 72)
        #expect(regular.sectionHeight == 564)
        #expect(accessibility.dockHeight == 64)
        #expect(accessibility.spacing == 36)
        #expect(accessibility.fieldHeight == 590)
        #expect(accessibility.fieldOriginY == 100)
        #expect(accessibility.sectionHeight == 690)
        #expect(LifeCoreCollapseLayout.minimumTapDimension >= 44)
        #expect(LifeCoreCollapseLayout.centerCoreTapDimension >= 44)
        #expect(
            LifeCoreCollapseLayout.collapsedCoreDimension(isAccessibilitySize: false) == 108
        )
        #expect(
            LifeCoreCollapseLayout.collapsedCoreDimension(isAccessibilitySize: true) == 120
        )
    }

    @Test func compactCompositionRendersDockAndClearCenterTargetWithoutArtwork() {
        let composition = LifeCoreDisplayComposition(
            displayMode: .compact,
            artworkState: .fallback
        )

        #expect(composition.showsCompactDock)
        #expect(composition.showsCenterTapTarget)
        #expect(!composition.showsCenterArtwork)
        #expect(!composition.showsExpandedCard)
    }

    @Test func expandedCompositionRendersCardWithoutCompactDockOrCenter() {
        let composition = LifeCoreDisplayComposition(
            displayMode: .expanded,
            artworkState: .fallback
        )

        #expect(!composition.showsCompactDock)
        #expect(!composition.showsCenterTapTarget)
        #expect(!composition.showsCenterArtwork)
        #expect(composition.showsExpandedCard)
    }

    @Test func expandedCardOccludesFieldNodesAndProtectsItsReadingZone() {
        #expect(LifeFieldLayerOrder.controls < LifeFieldLayerOrder.expandedCore)
        #expect(LifeFieldLayerOrder.expandedCore < LifeFieldLayerOrder.coreControl)
        #expect(LifeCoreReadabilityTreatment.textShieldPeakOpacity >= 0.90)
        #expect(LifeCoreReadabilityTreatment.textShieldEdgeOpacity <= 0.10)
    }

    @Test func compactDockNeverOverlapsOrCompressesTheLifeField() {
        let expanded = LifeCoreDockLayout.metrics(
            displayMode: .expanded,
            isAccessibilitySize: false
        )
        let compact = LifeCoreDockLayout.metrics(
            displayMode: .compact,
            isAccessibilitySize: false
        )

        #expect(expanded.dockHeight == 0)
        #expect(expanded.fieldOriginY == 0)
        #expect(expanded.fieldHeight == compact.fieldHeight)
        #expect(expanded.sectionHeight == expanded.fieldHeight)
        #expect(compact.dockRange.upperBound <= compact.fieldRange.lowerBound)
    }

    @Test func compactLifeCoreAnnouncesItsStateAndExpandAction() {
        let presentation = LifeCoreWidgetPresentation(
            definition: CollectionCatalog.ordinary[1],
            stage: .stageTwo,
            level: 2,
            currentXP: 80,
            requiredXP: 2_000,
            remainingXP: 1_920
        )

        #expect(
            presentation.compactAccessibilityLabel
                == "成长卡已折叠，正在陪伴，月兔，成长中，等级 2"
        )
        #expect(presentation.compactAccessibilityHint == "轻点展开成长卡")
        #expect(presentation.compactAccessibilityIdentifier == "today-life-core-expand")
        #expect(presentation.compactTitleText == "月兔 · LV 2")
    }

    @Test func compactDockIsTheOnlyAccessibleExpansionAction() {
        let presentation = makePresentation(
            definition: CollectionCatalog.ordinary[1],
            stage: .stageTwo
        )
        let compact = LifeCoreAccessibilityComposition(
            displayMode: .compact,
            presentation: presentation
        )
        let expanded = LifeCoreAccessibilityComposition(
            displayMode: .expanded,
            presentation: presentation
        )

        #expect(compact.dock?.label == presentation.compactAccessibilityLabel)
        #expect(compact.dock?.value == presentation.accessibilityValue)
        #expect(compact.dock?.hint == presentation.compactAccessibilityHint)
        #expect(compact.dock?.identifier == presentation.compactAccessibilityIdentifier)
        #expect(compact.centerTargetIsAccessibilityHidden)
        #expect([compact.dock != nil, !compact.centerTargetIsAccessibilityHidden].filter(\.self).count == 1)
        #expect(expanded.dock == nil)
        #expect([expanded.dock != nil, !expanded.centerTargetIsAccessibilityHidden].filter(\.self).isEmpty)
    }

    @Test func lifeCoreDescribesTheActiveCompanionInsteadOfAFixedMascot() {
        let presentation = LifeCoreWidgetPresentation(
            definition: CollectionCatalog.ordinary[1],
            stage: .stageTwo,
            level: 2,
            currentXP: 80,
            requiredXP: 2_000,
            remainingXP: 1_920
        )

        #expect(presentation.companionName == "月兔")
        #expect(presentation.stageTitle == "成长中")
        #expect(presentation.accessibilityLabel == "正在陪伴，月兔，成长中，等级 2")
        #expect(presentation.accessibilityValue == "当前 80，共需 2000，还差 1920 XP")
    }

    @Test func lifeCoreRequestsTheCurrentAndNextStageForTheSameCompanion() {
        let definition = CollectionCatalog.ordinary[0]
        let juvenile = makePresentation(definition: definition, stage: .juvenile)
        let stageTwo = makePresentation(definition: definition, stage: .stageTwo)
        let stageThree = makePresentation(definition: definition, stage: .stageThree)
        let mature = makePresentation(definition: definition, stage: .mature)

        #expect(
            juvenile.artworkRequest.current
                == .init(collectibleID: "ordinary.sprout", stage: .juvenile)
        )
        #expect(
            juvenile.artworkRequest.next
                == .init(collectibleID: "ordinary.sprout", stage: .stageTwo)
        )
        #expect(
            stageTwo.artworkRequest.next
                == .init(collectibleID: "ordinary.sprout", stage: .stageThree)
        )
        #expect(
            stageThree.artworkRequest.next
                == .init(collectibleID: "ordinary.sprout", stage: .mature)
        )
        #expect(mature.artworkRequest.next == nil)
    }

    @Test func lifeCoreArtworkIdentityChangesWithoutChangingLevelOrXP() {
        let sprout = makePresentation(
            definition: CollectionCatalog.ordinary[0],
            stage: .stageTwo
        )
        let hare = makePresentation(
            definition: CollectionCatalog.ordinary[1],
            stage: .stageTwo
        )

        #expect(sprout.artworkRequest.current != hare.artworkRequest.current)
        #expect(
            hare.artworkRequest.current
                == .init(collectibleID: "ordinary.hare", stage: .stageTwo)
        )
        #expect(sprout.level == hare.level)
        #expect(sprout.currentXP == hare.currentXP)
        #expect(sprout.requiredXP == hare.requiredXP)
        #expect(sprout.remainingXP == hare.remainingXP)
        #expect(sprout.progress == hare.progress)
    }

    @Test func lifeCoreUsesApprovedWidgetMetricsAndStableProgress() {
        let presentation = LifeCoreWidgetPresentation(
            definition: CollectionCatalog.ordinary[1],
            stage: .stageTwo,
            level: 2,
            currentXP: 80,
            requiredXP: 2_000,
            remainingXP: 1_920
        )

        #expect(presentation.cornerRadius == 26)
        #expect(presentation.progress == 0.04)
        #expect(presentation.levelText == "LV 2")
        #expect(presentation.xpText == "80 / 2000 XP")
        #expect(presentation.remainingText == "下一形态 1920 XP")
    }

    @Test func lifeCoreProvidesAShortRemainingXPLabelWhenLargeTextCannotFit() {
        let presentation = LifeCoreWidgetPresentation(
            definition: CollectionCatalog.ordinary[1],
            stage: .stageTwo,
            level: 2,
            currentXP: 80,
            requiredXP: 2_000,
            remainingXP: 1_920
        )

        #expect(presentation.remainingText == "下一形态 1920 XP")
        #expect(presentation.compactRemainingText == "还差 1920 XP")
    }

    @Test func mainCoreUsesTheApprovedPointCloudOrbWithoutLegacyControls() {
        #expect(!LifeCoreWidgetPresentation.showsMediaControlsOnMainSurface)
        #expect(!LifeCoreWidgetPresentation.allowsOpeningLegacyDetail)
        #expect(LifeCoreWidgetPresentation.artworkStyle == .pointCloudOrb)
        #expect(!TodaySurfaceContract.showsAssessmentControl)
        #expect(!TodaySurfaceContract.showsTaskSectionTitle)
    }

    @Test func coreParticlesDanceNormallyAndFreezeForReduceMotion() {
        let start = LifeCoreParticleGeometry.samples(
            columns: 25,
            rows: 39,
            phase: 0,
            reduceMotion: false
        )
        let moved = LifeCoreParticleGeometry.samples(
            columns: 25,
            rows: 39,
            phase: 0.35,
            reduceMotion: false
        )
        let frozenA = LifeCoreParticleGeometry.samples(
            columns: 25,
            rows: 39,
            phase: 0,
            reduceMotion: true
        )
        let frozenB = LifeCoreParticleGeometry.samples(
            columns: 25,
            rows: 39,
            phase: 0.85,
            reduceMotion: true
        )

        #expect(start.count > 220)
        #expect(start != moved)
        #expect(frozenA == frozenB)
        #expect(start.allSatisfy {
            (0...1).contains($0.position.x)
                && (0...1).contains($0.position.y)
                && $0.diameter > 0
                && (0...1).contains($0.opacity)
        })
    }

    @Test func coreParticleFieldIsDenserNearTheOrbThanAtTheCorners() {
        let samples = LifeCoreParticleGeometry.samples(
            columns: 31,
            rows: 45,
            phase: 0.2,
            reduceMotion: false
        )
        let center = samples.filter {
            abs($0.position.x - 0.5) < 0.18
                && abs($0.position.y - 0.48) < 0.18
        }
        let corners = samples.filter {
            ($0.position.x < 0.18 || $0.position.x > 0.82)
                && ($0.position.y < 0.18 || $0.position.y > 0.82)
        }

        #expect(center.count > corners.count)
        #expect(center.map(\.opacity).reduce(0, +) > corners.map(\.opacity).reduce(0, +))
    }

    @Test func lifeCoreProgressCannotEscapeItsTrack() {
        let definition = CollectionCatalog.ordinary[0]
        let zeroRequirement = LifeCoreWidgetPresentation(
            definition: definition,
            stage: .juvenile,
            level: 1,
            currentXP: 20,
            requiredXP: 0,
            remainingXP: 0
        )
        let overfilled = LifeCoreWidgetPresentation(
            definition: definition,
            stage: .mature,
            level: 4,
            currentXP: 120,
            requiredXP: 100,
            remainingXP: -20
        )

        #expect(zeroRequirement.progress == 0)
        #expect(overfilled.progress == 1)
        #expect(overfilled.remainingText == "下一形态 0 XP")
    }

    @Test func taskRailKeepsRealTaskIdentityAndReward() {
        let item = Item(
            title: "跑步 30 分钟",
            dimension: .health,
            minutes: 30,
            difficulty: 2,
            xp: 20,
            recurrence: .once
        )
        let presentation = TaskRailPresentation(
            item: item,
            completed: true,
            rewardXP: 20
        )

        #expect(presentation.title == "跑步 30 分钟")
        #expect(presentation.dimensionTitle == "健康")
        #expect(presentation.xpText == "+20 XP")
        #expect(presentation.isCompleted)
        #expect(presentation.isRewarding)
    }

    @Test func taskRailDoesNotInventARewardBeforeCompletionFeedback() {
        let item = Item(
            title: "阅读 20 分钟",
            dimension: .learning,
            minutes: 20,
            difficulty: 1,
            xp: 10,
            recurrence: .once
        )
        let presentation = TaskRailPresentation(
            item: item,
            completed: false,
            rewardXP: nil
        )

        #expect(presentation.xpText == nil)
        #expect(!presentation.isRewarding)
        #expect(presentation.completionAccessibilityLabel == "完成 阅读 20 分钟")
        #expect(presentation.editAccessibilityLabel == "编辑 阅读 20 分钟")
        #expect(TaskRailMetrics.minimumActionHitTarget == 44)
    }

    @Test func taskRailAccessibilityIncludesCompletionDimensionAndXP() {
        let item = Item(
            title: "整理房间",
            dimension: .interests,
            minutes: 15,
            difficulty: 1,
            xp: 10,
            recurrence: .once
        )
        let presentation = TaskRailPresentation(
            item: item,
            completed: true,
            rewardXP: nil
        )

        #expect(presentation.accessibilityLabel == "整理房间，兴趣，10 XP，已完成")
        #expect(presentation.completionAccessibilityLabel == "取消完成 整理房间")
        #expect(presentation.editAccessibilityLabel == "编辑 整理房间")
    }

    @Test func taskEditorLocksCompletedTasksUntilTheirCompletionIsRevoked() {
        let item = Item(
            title: "整理房间",
            dimension: .interests,
            minutes: 15,
            difficulty: 1,
            xp: 10,
            recurrence: .once
        )

        let create = TaskEditorPresentation(item: nil, isCompletedToday: false)
        let edit = TaskEditorPresentation(item: item, isCompletedToday: false)
        let completed = TaskEditorPresentation(item: item, isCompletedToday: true)

        #expect(create.navigationTitle == "新任务")
        #expect(create.allowsFieldEditing)
        #expect(!create.showsArchiveAction)
        #expect(edit.navigationTitle == "编辑任务")
        #expect(edit.allowsFieldEditing)
        #expect(edit.showsArchiveAction)
        #expect(!edit.showsRevokeToEditAction)
        #expect(!completed.allowsFieldEditing)
        #expect(completed.showsArchiveAction)
        #expect(completed.showsRevokeToEditAction)
    }

    @Test func taskEditorPrefillsExistingTaskAndUnlocksOnlyAfterSuccessfulRevoke() {
        let item = Item(
            title: "阅读 20 分钟",
            dimension: .learning,
            minutes: 20,
            difficulty: 2,
            xp: 20,
            recurrence: .daily
        )
        let form = TaskEditorFormState(item: item)
        var session = TaskEditorSessionState(isCompletedToday: true)

        #expect(form.title == "阅读 20 分钟")
        #expect(form.dimension == .learning)
        #expect(form.minutes == 20)
        #expect(form.difficulty == 2)
        #expect(form.recurrence == .daily)
        #expect(form.draft.recommendedXP == 20)
        #expect(session.isLocked)

        session.completionWasRevoked()

        #expect(!session.isLocked)
    }

    private func makePresentation(
        definition: CollectibleDefinition,
        stage: CompanionStage
    ) -> LifeCoreWidgetPresentation {
        LifeCoreWidgetPresentation(
            definition: definition,
            stage: stage,
            level: 2,
            currentXP: 80,
            requiredXP: 2_000,
            remainingXP: 1_920
        )
    }

}
