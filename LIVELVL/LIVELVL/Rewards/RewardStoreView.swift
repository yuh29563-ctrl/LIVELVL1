import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

private enum RewardGuidanceAnchor: Hashable {
    case ledger
    case product(UUID)
}

private struct RewardGuidanceAnchorPreferenceKey: PreferenceKey {
    static let defaultValue: [RewardGuidanceAnchor: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [RewardGuidanceAnchor: Anchor<CGRect>],
        nextValue: () -> [RewardGuidanceAnchor: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

struct RewardStoreView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \RewardProduct.createdAt, order: .reverse)
    private var products: [RewardProduct]
    @Query(sort: \RewardRedemption.redeemedAt, order: .reverse)
    private var redemptions: [RewardRedemption]
    @Query(sort: \CoinTransaction.createdAt, order: .forward)
    private var coinTransactions: [CoinTransaction]
    @Query private var progressItems: [Progress]

    @State private var editorRoute: RewardProductEditorRoute?
    @State private var confirmationSelection = RewardConfirmationSelection()
    @State private var isShowingHistory = false
    @State private var isShowingMessage = false
    @State private var message = ""
    @State private var submissionState = RewardRedemptionSubmissionState()

    private var unavailableProductIDs: Set<UUID> {
        RewardProductVisibility.hiddenProductIDs(
            redemptions: redemptions.map {
                RewardRedemptionVisibility(
                    productID: $0.productID,
                    status: $0.status,
                    isHiddenFromHistory: $0.historyHiddenAt != nil
                )
            }
        )
    }

    private var activeProducts: [RewardProduct] {
        products.filter {
            !$0.isArchived && !unavailableProductIDs.contains($0.id)
        }
    }

    private var archivedProducts: [RewardProduct] {
        products.filter {
            $0.isArchived && !unavailableProductIDs.contains($0.id)
        }
    }

    private var visibleRedemptions: [RewardRedemption] {
        redemptions.filter { $0.historyHiddenAt == nil }
    }

    private var balancePresentation: RewardBalancePresentation {
        _ = coinTransactions.count
        do {
            return .available(try CoinLedgerService.balance(in: context))
        } catch {
            return .unavailable
        }
    }

    private var guidanceTarget: RewardGuidanceTarget? {
        RewardGuidanceTargetResolver.resolve(
            products: products.map {
                RewardGuidanceProduct(
                    id: $0.id,
                    priceCoinUnits: $0.priceCoinUnits,
                    isArchived: $0.isArchived,
                    isRedeemed: unavailableProductIDs.contains($0.id)
                )
            },
            balanceCoinUnits: balancePresentation.coinUnits
        )
    }

    private var pendingRedemptionCount: Int {
        visibleRedemptions.lazy.filter { $0.status == .pending }.count
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        RewardStoreHeader(
                            onHistory: { isShowingHistory = true },
                            onCreate: createProduct
                        )

                        RewardBalanceHero(
                            balance: balancePresentation,
                            pendingCount: pendingRedemptionCount
                        )
                        .padding(.top, RewardStoreLayout.balanceTopSpacing)

                        RewardProductList(
                            products: activeProducts,
                            balance: balancePresentation,
                            guidanceTarget: guidanceTarget,
                            redeemedProductIDs: unavailableProductIDs,
                            isSubmitting: submissionState.isSubmitting,
                            confirmationSelection: $confirmationSelection,
                            onRedeem: redeem,
                            onEdit: edit,
                            onArchive: archive
                        )
                        .padding(.top, RewardStoreLayout.productTopSpacing)

                        if !archivedProducts.isEmpty {
                            DisclosureGroup("已归档  \(archivedProducts.count)") {
                                RewardProductList(
                                    products: archivedProducts,
                                    balance: balancePresentation,
                                    guidanceTarget: nil,
                                    redeemedProductIDs: unavailableProductIDs,
                                    isSubmitting: submissionState.isSubmitting,
                                    confirmationSelection: $confirmationSelection,
                                    onRedeem: { _ in },
                                    onEdit: edit,
                                    onArchive: { _ in }
                                )
                                .opacity(0.5)
                            }
                            .font(.system(.footnote, design: .monospaced, weight: .medium))
                            .foregroundStyle(LivingOSTheme.graphite)
                            .padding(.top, 28)
                        }
                    }
                    .overlayPreferenceValue(RewardGuidanceAnchorPreferenceKey.self) { anchors in
                        GeometryReader { geometry in
                            if let guidanceTarget,
                               let sourceAnchor = anchors[.ledger],
                               let targetAnchor = anchors[.product(guidanceTarget.productID)] {
                                RewardGuidanceParticleTrail(
                                    start: CGPoint(
                                        x: geometry[sourceAnchor].midX,
                                        y: geometry[sourceAnchor].midY
                                    ),
                                    end: CGPoint(
                                        x: geometry[targetAnchor].midX,
                                        y: geometry[targetAnchor].midY
                                    ),
                                    status: guidanceTarget.status,
                                    onActivate: {
                                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.32)) {
                                            scrollProxy.scrollTo(
                                                guidanceTarget.productID,
                                                anchor: .center
                                            )
                                        }
                                    }
                                )
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height,
                                    alignment: .topLeading
                                )
                            }
                        }
                    }
                    .padding(.horizontal, LivingOSMetrics.pageHorizontalInset)
                    .padding(.top, RewardStoreLayout.pageTopPadding)
                    .padding(.bottom, RootTabPageLayout.contentBottomPadding)
                }
                .background(LivingOSTheme.canvas)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editorRoute) { route in
                RewardProductEditor(product: route.product)
            }
            .sheet(isPresented: $isShowingHistory) {
                RewardRedemptionHistoryView(redemptions: visibleRedemptions)
            }
            .alert("奖励状态", isPresented: $isShowingMessage) {
                Button("好的") {}
            } message: {
                Text(message)
            }
            .onAppear(perform: importLegacyXP)
        }
    }

    private func createProduct() {
        editorRoute = .create
    }

    private func edit(_ product: RewardProduct) {
        editorRoute = .edit(product)
    }

    private func importLegacyXP() {
        guard let progress = progressItems.first else { return }
        _ = try? CoinLedgerService.ensureLegacyXPImported(progress: progress, in: context)
    }

    private func redeem(_ product: RewardProduct) {
        guard balancePresentation.allowsRedemption else {
            message = "金币余额暂时无法读取，请稍后重试。"
            isShowingMessage = true
            return
        }
        guard let requestKey = submissionState.begin(productID: product.id) else {
            return
        }
        defer { submissionState.finish() }
        do {
            _ = try RewardStoreService.redeem(
                product,
                requestKey: requestKey,
                in: context
            )
            message = RewardRedemptionFeedback.successMessage
        } catch RewardRedemptionError.insufficientBalance {
            message = "金币余额不足，还需要更多 XP 才能兑换。"
        } catch RewardRedemptionError.productArchived {
            message = "这个奖励已归档。"
        } catch {
            message = "兑换失败，请重试。"
        }
        isShowingMessage = true
    }

    private func archive(_ product: RewardProduct) {
        do {
            try RewardStoreService.archive(product, in: context)
            message = "已归档“\(product.name)”"
        } catch {
            message = "归档失败，请重试。"
        }
        isShowingMessage = true
    }
}

private struct RewardStoreHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: LivingOSTypography.rewardsHero) private var titleSize: CGFloat = 52
    let onHistory: () -> Void
    let onCreate: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    title
                    actions
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    title
                    Spacer(minLength: 8)
                    actions
                }
            }
        }
    }

    private var title: some View {
        Text("Rewards")
            .font(.system(size: titleSize, weight: .bold))
            .tracking(-2.4)
            .foregroundStyle(LivingOSTheme.ink)
            .lineLimit(1)
            .minimumScaleFactor(RewardStoreLayout.heroMinimumScale)
            .allowsTightening(true)
    }

    private var actions: some View {
        HStack(alignment: .center, spacing: 18) {
            Button("历史", action: onHistory)
                .font(.body)
                .foregroundStyle(LivingOSTheme.graphite)
                .accessibilityIdentifier("rewards.history")

            Rectangle()
                .fill(LivingOSTheme.mist)
                .frame(width: 0.5, height: 25)

            Button(action: onCreate) {
                Image(systemName: "plus")
                    .font(.title2.weight(.light))
                    .frame(width: 34, height: 44)
            }
            .foregroundStyle(LivingOSTheme.ink)
            .accessibilityLabel("创建现实奖励")
            .accessibilityIdentifier("rewards.create")
        }
    }
}

private struct RewardBalanceHero: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: LivingOSTypography.rewardsHero) private var balanceSize: CGFloat = 62
    let balance: RewardBalancePresentation
    let pendingCount: Int

    private var displayText: String {
        guard let coinUnits = balance.coinUnits else { return "—" }
        return CoinDisplayFormatter.text(forCoinUnits: coinUnits)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RewardStoreLayout.balanceInternalSpacing) {
            Text("可用金币")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(LivingOSTheme.graphite)

            if RewardStoreLayout.usesVerticalBalanceLayout(
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    balanceNumber
                    ledgerStrip(height: 42)
                }
            } else {
                HStack(alignment: .bottom, spacing: 18) {
                    balanceNumber
                    ledgerStrip(height: 62)
                        .padding(.bottom, 4)
                }
            }

            Group {
                if RewardStoreLayout.usesVerticalBalanceLayout(
                    isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        pendingRedemptionCount
                        conversionRate
                    }
                } else {
                    HStack(spacing: 9) {
                        pendingRedemptionCount
                        Spacer()
                        conversionRate
                    }
                }
            }
            .font(.subheadline)
            .padding(.top, 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("可用金币 \(displayText)，待兑现 \(pendingCount)")
        .accessibilityIdentifier("rewards.balance")
    }

    private var balanceNumber: some View {
        Text(displayText)
            .font(.system(size: balanceSize, weight: .light, design: .rounded))
            .tracking(-2)
            .monospacedDigit()
            .foregroundStyle(LivingOSTheme.ink)
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(RewardStoreLayout.heroMinimumScale)
            .allowsTightening(true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pendingRedemptionCount: some View {
        HStack(spacing: 9) {
            Text("待兑现")
                .foregroundStyle(LivingOSTheme.graphite)
            Text(pendingCount, format: .number)
                .foregroundStyle(LivingOSTheme.ink)
                .contentTransition(.numericText())
        }
    }

    private var conversionRate: some View {
        Text("1 XP = 0.1 金币")
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(LivingOSTheme.graphite)
    }

    private func ledgerStrip(height: CGFloat) -> some View {
        let balanceCoinUnits = balance.coinUnits ?? 0
        let overflowText = RewardLedgerGeometry.fill(
            columns: 24,
            rows: 6,
            balanceCoinUnits: balanceCoinUnits
        ).overflowText

        return HStack(alignment: .center, spacing: 8) {
            RewardLedgerStrip(balanceCoinUnits: balanceCoinUnits)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .anchorPreference(
                    key: RewardGuidanceAnchorPreferenceKey.self,
                    value: .bounds
                ) { [.ledger: $0] }

            if let overflowText {
                Text(overflowText)
                    .font(.system(.caption2, design: .monospaced, weight: .medium))
                    .foregroundStyle(LivingOSTheme.graphite)
                    .monospacedDigit()
            }
        }
        .accessibilityHidden(true)
    }
}

private struct RewardLedgerStrip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    let balanceCoinUnits: Int

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: pausesTimeline)) { timeline in
            RewardLedgerCanvas(
                displayedBalanceCoinUnits: Double(balanceCoinUnits),
                phase: timeline.date.timeIntervalSinceReferenceDate / 9,
                reduceMotion: reduceMotion
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.48),
                value: balanceCoinUnits
            )
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

private struct RewardLedgerCanvas: View, Animatable {
    var displayedBalanceCoinUnits: Double
    let phase: Double
    let reduceMotion: Bool

    var animatableData: Double {
        get { displayedBalanceCoinUnits }
        set { displayedBalanceCoinUnits = newValue }
    }

    var body: some View {
        let samples = RewardLedgerGeometry.samples(
            columns: 24,
            rows: 6,
            displayedBalanceCoinUnits: displayedBalanceCoinUnits,
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
                    with: .color(LivingOSTheme.ink.opacity(sample.opacity))
                )
            }
        }
    }
}

private struct RewardGuidanceParticleTrail: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    let start: CGPoint
    let end: CGPoint
    let status: RewardGuidanceStatus
    let onActivate: () -> Void

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: pausesTimeline)) { timeline in
            let samples = RewardGuidanceTrailGeometry.samples(
                count: 58,
                phase: timeline.date.timeIntervalSinceReferenceDate / 8.5,
                reduceMotion: reduceMotion,
                start: start,
                end: end,
                status: status
            )

            Canvas { context, _ in
                for sample in samples {
                    let diameter = sample.diameter
                    let rect = CGRect(
                        x: sample.position.x - diameter / 2,
                        y: sample.position.y - diameter / 2,
                        width: diameter,
                        height: diameter
                    )
                    context.fill(
                        Path(ellipseIn: rect.insetBy(dx: -0.8, dy: -0.8)),
                        with: .color(LivingOSTheme.ink.opacity(sample.opacity * 0.16))
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(LivingOSTheme.ink.opacity(sample.opacity))
                    )
                }
            }
            .contentShape(
                RewardGuidanceTrailHitShape(start: start, end: end)
            )
            .onTapGesture(perform: onActivate)
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(accessibilityLabel)
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    private var accessibilityLabel: String {
        switch status {
        case .affordable:
            "定位到可兑换奖励"
        case .progress:
            "定位到最近可兑换奖励"
        }
    }

    private var pausesTimeline: Bool {
        LivingOSAnimationActivity.isPaused(
            reduceMotion: reduceMotion,
            isVisible: isVisible,
            isSceneActive: scenePhase == .active
        )
    }
}

private struct RewardGuidanceTrailHitShape: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        let controls = RewardGuidanceTrailGeometry.controlPoints(
            start: start,
            end: end
        )
        var curve = Path()
        curve.move(to: start)
        curve.addCurve(
            to: end,
            control1: controls.first,
            control2: controls.second
        )
        return curve.trimmedPath(from: 0, to: 0.82).strokedPath(
            StrokeStyle(lineWidth: 32, lineCap: .round, lineJoin: .round)
        )
    }
}

private struct RewardProductList: View {
    let products: [RewardProduct]
    let balance: RewardBalancePresentation
    let guidanceTarget: RewardGuidanceTarget?
    let redeemedProductIDs: Set<UUID>
    let isSubmitting: Bool
    @Binding var confirmationSelection: RewardConfirmationSelection
    let onRedeem: (RewardProduct) -> Void
    let onEdit: (RewardProduct) -> Void
    let onArchive: (RewardProduct) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(LivingOSTheme.mist)
                .frame(height: 0.5)

            if products.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("还没有现实奖励")
                        .font(.title2.weight(.medium))
                    Text("点击右上角 +，创建一个值得兑换的现实目标。")
                        .font(.subheadline)
                        .foregroundStyle(LivingOSTheme.graphite)
                }
                .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            } else {
                ForEach(products) { product in
                    RewardProductRail(
                        product: product,
                        balance: balance,
                        guidanceStatus: guidanceTarget?.productID == product.id
                            ? guidanceTarget?.status
                            : nil,
                        isRedeemed: redeemedProductIDs.contains(product.id),
                        isSubmitting: isSubmitting,
                        confirmationSelection: $confirmationSelection,
                        onRedeem: { onRedeem(product) },
                        onEdit: { onEdit(product) },
                        onArchive: { onArchive(product) }
                    )
                    .id(product.id)
                }
            }
        }
    }
}

private struct RewardProductRail: View {
    let product: RewardProduct
    let balance: RewardBalancePresentation
    let guidanceStatus: RewardGuidanceStatus?
    let isRedeemed: Bool
    let isSubmitting: Bool
    @Binding var confirmationSelection: RewardConfirmationSelection
    let onRedeem: () -> Void
    let onEdit: () -> Void
    let onArchive: () -> Void

    private var presentation: RewardProductRailPresentation {
        RewardProductRailPresentation(
            name: product.name,
            priceCoinUnits: product.priceCoinUnits,
            note: product.note,
            imageReference: product.imageReference,
            balanceCoinUnits: balance.coinUnits,
            isArchived: product.isArchived,
            isRedeemed: isRedeemed
        )
    }

    private var canRedeem: Bool {
        balance.allowsRedemption && presentation.canRedeem && !isSubmitting
    }

    private var resolvedStatusText: String {
        guidanceStatus?.displayText ?? presentation.statusText
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Button(action: onEdit) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(presentation.name)
                            .font(.title2.weight(.medium))
                            .foregroundStyle(canRedeem ? LivingOSTheme.ink : LivingOSTheme.graphite)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(CoinDisplayFormatter.text(forCoinUnits: presentation.priceCoinUnits))
                            .font(.system(.title3, design: .rounded, weight: .regular))
                            .monospacedDigit()
                            .foregroundStyle(canRedeem ? LivingOSTheme.ink : LivingOSTheme.graphite)

                        Text(presentation.note.isEmpty ? resolvedStatusText : presentation.note)
                            .font(.footnote)
                            .foregroundStyle(LivingOSTheme.graphite)
                            .lineLimit(2)

                        if !presentation.note.isEmpty, !presentation.canRedeem {
                            Text(resolvedStatusText)
                                .font(.system(.caption2, design: .monospaced, weight: .medium))
                                .foregroundStyle(LivingOSTheme.graphite)
                        }
                    }

                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("编辑 \(presentation.name)")

            trailingAccessory
        }
        .padding(.vertical, 22)
        .contentShape(Rectangle())
        .contextMenu {
            Button("编辑", action: onEdit)
            if !product.isArchived {
                Button("归档", role: .destructive) {
                    confirmationSelection.present(.archive(product.id))
                }
            }
        }
        .rewardConfirmationPopover(
            isPresented: confirmationBinding(for: .archive(product.id)),
            message: "历史兑换记录会保留，归档后不能再次兑换。",
            actionTitle: "归档",
            role: .destructive
        ) {
            onArchive()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(guidanceStatus?.displayText ?? "")
        .accessibilityActions {
            Button("编辑", action: onEdit)
            if presentation.canArchive {
                Button("归档", action: onArchive)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LivingOSTheme.mist)
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        Group {
            if let imageReference = product.imageReference {
                redeemButton(disabledOpacity: 0.58) {
                    RewardProductImageView(reference: imageReference)
                        .frame(width: 70, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            if presentation.canRedeem {
                                Circle()
                                    .fill(LivingOSTheme.signal)
                                    .frame(width: 6, height: 6)
                                    .padding(8)
                                    .accessibilityHidden(true)
                            }
                        }
                }
            } else if !product.isArchived {
                redeemButton(disabledOpacity: 0.48) {
                    HStack(spacing: 8) {
                        Text(presentation.canRedeem ? "兑换" : resolvedStatusText)
                        if presentation.canRedeem {
                            Circle()
                                .fill(LivingOSTheme.signal)
                                .frame(width: 6, height: 6)
                                .accessibilityHidden(true)
                        }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(LivingOSTheme.ink)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .overlay {
                        Capsule()
                            .stroke(LivingOSTheme.graphite.opacity(0.42), lineWidth: 0.8)
                    }
                }
            }
        }
        .anchorPreference(
            key: RewardGuidanceAnchorPreferenceKey.self,
            value: .bounds
        ) { anchor in
            guidanceStatus == nil ? [:] : [.product(product.id): anchor]
        }
    }

    private func redeemButton<Label: View>(
        disabledOpacity: Double,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            confirmationSelection.present(.redeem(product.id))
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .disabled(!canRedeem)
        .opacity(canRedeem ? 1 : disabledOpacity)
        .accessibilityLabel(
            isRedeemed
                ? "\(presentation.name)，已兑换"
                : "兑换 \(presentation.name)"
        )
        .accessibilityIdentifier("rewards.redeem.\(product.id.uuidString)")
        .rewardConfirmationPopover(
            isPresented: confirmationBinding(for: .redeem(product.id)),
            message: redemptionConfirmationMessage,
            actionTitle: "确认兑换",
            isActionDisabled: isSubmitting,
            action: onRedeem
        )
    }

    private var redemptionConfirmationMessage: String {
        let postBalance = max(
            0,
            (balance.coinUnits ?? 0) - product.priceCoinUnits
        )
        return "\(product.name) · 扣除 \(CoinDisplayFormatter.text(forCoinUnits: product.priceCoinUnits)) 金币 · 兑换后余额 \(CoinDisplayFormatter.text(forCoinUnits: postBalance))。兑换记录将保存为待兑现。"
    }

    private func confirmationBinding(
        for target: RewardConfirmationTarget
    ) -> Binding<Bool> {
        Binding(
            get: { confirmationSelection.isPresented(for: target) },
            set: { confirmationSelection.setPresented($0, for: target) }
        )
    }
}

private struct RewardProductEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let product: RewardProduct?
    @State private var name = ""
    @State private var price = ""
    @State private var note = ""
    @State private var imageReference: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("奖励信息") {
                    TextField("名称", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("reward-editor.name")
                    TextField("价格（金币，例如 12.3）", text: $price)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("reward-editor.price")
                    TextField("备注（可选）", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                        .accessibilityIdentifier("reward-editor.note")
                }

                Section("图片") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Text(imageReference == nil ? "添加图片" : "替换图片")
                    }
                    if imageReference != nil {
                        Button("移除图片", role: .destructive) {
                            imageReference = nil
                            selectedPhoto = nil
                        }
                    }
                    Text("图片只保存在本机；历史兑换会保留当时的图片引用。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if product != nil {
                    Section {
                        Button("删除奖励", role: .destructive) {
                            isShowingDeleteConfirmation = true
                        }
                        .accessibilityIdentifier("reward-editor.delete")
                        .rewardConfirmationPopover(
                            isPresented: $isShowingDeleteConfirmation,
                            message: "奖励会从主界面移除；已有兑换历史和金币流水保持不变。",
                            actionTitle: "删除奖励",
                            role: .destructive,
                            action: deleteProduct
                        )
                    } footer: {
                        Text("删除奖励不会删除已有的兑换快照。")
                    }
                }
            }
            .navigationTitle(product == nil ? "新建奖励" : "编辑奖励")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("reward-editor.save")
                }
            }
            .onAppear(perform: loadProduct)
        }
    }

    private func loadProduct() {
        guard let product else { return }
        name = product.name
        price = CoinDisplayFormatter.text(forCoinUnits: product.priceCoinUnits)
        note = product.note
        imageReference = product.imageReference
    }

    private func save() {
        do {
            let units = try CoinDisplayFormatter.coinUnits(fromDisplayText: price)
            try RewardProduct.validate(name: name, priceCoinUnits: units)
            Task { @MainActor in
                do {
                    var savedImageReference = imageReference
                    if let selectedPhoto,
                       let data = try await selectedPhoto.loadTransferable(type: Data.self) {
                        savedImageReference = try RewardProductImageStore.save(
                            data,
                            applicationSupportURL: applicationSupportURL()
                        )
                    }
                    if let product {
                        try RewardStoreService.updateProduct(
                            product,
                            name: name,
                            priceCoinUnits: units,
                            note: note,
                            imageReference: savedImageReference,
                            in: context
                        )
                    } else {
                        _ = try RewardStoreService.createProduct(
                            name: name,
                            priceCoinUnits: units,
                            note: note,
                            imageReference: savedImageReference,
                            in: context
                        )
                    }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        dismiss()
                    }
                } catch {
                    errorMessage = "保存失败，请检查图片或稍后重试。"
                }
            }
        } catch RewardValidationError.emptyName {
            errorMessage = "请输入奖励名称。"
        } catch RewardValidationError.invalidPrice {
            errorMessage = "价格必须是大于 0 且最多一位小数的金币数。"
        } catch {
            errorMessage = "价格格式无效。"
        }
    }

    private func deleteProduct() {
        guard let product else { return }
        let deletedImageReference = product.imageReference
        do {
            try RewardStoreService.deleteProduct(product, in: context)
            if let deletedImageReference,
               try !RewardStoreService.imageReferenceIsInUse(
                    deletedImageReference,
                    in: context
               ) {
                try? RewardProductImageStore.remove(
                    reference: deletedImageReference,
                    applicationSupportURL: applicationSupportURL()
                )
            }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                dismiss()
            }
        } catch {
            errorMessage = "删除失败，请稍后重试。"
        }
    }

    private func applicationSupportURL() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }
}

private struct RewardRedemptionHistoryView: View {
    @Environment(\.modelContext) private var context
    let redemptions: [RewardRedemption]
    @State private var confirmationSelection = RewardConfirmationSelection()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if redemptions.isEmpty {
                    ContentUnavailableView(
                        "还没有兑换记录",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("兑换现实奖励后会出现在这里")
                    )
                } else {
                    ForEach(redemptions) { redemption in
                        let presentation = RewardRedemptionHistoryPresentation(
                            status: redemption.status
                        )
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(redemption.productNameSnapshot)
                                    .font(.headline)
                                Spacer()
                                Text(presentation.statusText)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(
                                        redemption.status == .pending
                                            ? TodayVisualTheme.reward
                                            : .secondary
                                    )
                            }
                            Text("\(CoinDisplayFormatter.text(forCoinUnits: redemption.priceCoinUnitsSnapshot)) 金币 · \(redemption.redeemedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                            if !redemption.noteSnapshot.isEmpty {
                                Text(redemption.noteSnapshot)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 18) {
                                if presentation.canFulfill {
                                    Button("标记为已兑现") {
                                        fulfill(redemption)
                                    }
                                    .font(.subheadline.weight(.medium))
                                }
                                if presentation.canCancel {
                                    Button("取消兑换", role: .destructive) {
                                        confirmationSelection.present(
                                            .cancelRedemption(redemption.id)
                                        )
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .rewardConfirmationPopover(
                                        isPresented: confirmationBinding(
                                            for: .cancelRedemption(redemption.id)
                                        ),
                                        message: "将退回 \(CoinDisplayFormatter.text(forCoinUnits: redemption.priceCoinUnitsSnapshot)) 金币，奖励会重新回到主界面。",
                                        actionTitle: "取消兑换并退币",
                                        role: .destructive
                                    ) {
                                        cancel(redemption)
                                    }
                                }
                                Spacer(minLength: 0)
                                Button("删除记录", role: .destructive) {
                                    confirmationSelection.present(
                                        .deleteRedemption(redemption.id)
                                    )
                                }
                                .font(.subheadline.weight(.medium))
                                .rewardConfirmationPopover(
                                    isPresented: confirmationBinding(
                                        for: .deleteRedemption(redemption.id)
                                    ),
                                    message: "记录会从历史中消失，但不会退回金币，也不会让奖励重新出现。",
                                    actionTitle: "删除记录",
                                    role: .destructive
                                ) {
                                    hide(redemption)
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "\(redemption.productNameSnapshot)，\(presentation.statusText)"
                        )
                    }
                }
            }
            .navigationTitle("兑换历史")
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                "操作失败",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("好的") {}
            } message: {
                Text(errorMessage ?? "请稍后重试。")
            }
        }
    }

    private func fulfill(_ redemption: RewardRedemption) {
        do {
            try RewardStoreService.fulfill(redemption, in: context)
        } catch {
            errorMessage = "无法更新兑现状态，请稍后重试。"
        }
    }

    private func cancel(_ redemption: RewardRedemption) {
        do {
            try RewardStoreService.cancel(redemption, in: context)
        } catch RewardRedemptionError.redemptionAlreadyFulfilled {
            errorMessage = "这个奖励已经兑现，不能取消兑换。"
        } catch {
            errorMessage = "取消兑换失败，请稍后重试。"
        }
    }

    private func hide(_ redemption: RewardRedemption) {
        do {
            try RewardStoreService.hideFromHistory(redemption, in: context)
        } catch {
            errorMessage = "删除记录失败，请稍后重试。"
        }
    }

    private func confirmationBinding(
        for target: RewardConfirmationTarget
    ) -> Binding<Bool> {
        Binding(
            get: { confirmationSelection.isPresented(for: target) },
            set: { confirmationSelection.setPresented($0, for: target) }
        )
    }
}

private extension View {
    func rewardConfirmationPopover(
        isPresented: Binding<Bool>,
        message: String,
        actionTitle: String,
        role: ButtonRole? = nil,
        isActionDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        popover(
            isPresented: isPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .bottom
        ) {
            VStack(alignment: .leading, spacing: 20) {
                Text(message)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                Button(role: role) {
                    isPresented.wrappedValue = false
                    action()
                } label: {
                    Text(actionTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isActionDisabled)
                .foregroundStyle(role == .destructive ? Color.red : LivingOSTheme.ink)
                .background(LivingOSTheme.mist.opacity(0.9), in: Capsule())
            }
            .padding(20)
            .frame(width: 270)
            .presentationCompactAdaptation(.popover)
        }
    }
}

private struct RewardProductImageView: View {
    let reference: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.34))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                LivingOSTheme.graphite.opacity(0.28),
                                style: StrokeStyle(lineWidth: 0.8, dash: [4, 4])
                            )
                    }
            }
        }
        .task(id: reference) {
            image = try? loadImage(reference: reference)
        }
        .accessibilityHidden(true)
    }

    private func loadImage(reference: String) throws -> UIImage? {
        let applicationSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let data = try RewardProductImageStore.load(
            reference: reference,
            applicationSupportURL: applicationSupportURL
        )
        return UIImage(data: data)
    }
}
