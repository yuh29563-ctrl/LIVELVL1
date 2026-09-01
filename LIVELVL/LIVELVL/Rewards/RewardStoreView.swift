import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct RewardStoreView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RewardProduct.createdAt, order: .reverse)
    private var products: [RewardProduct]
    @Query(sort: \RewardRedemption.redeemedAt, order: .reverse)
    private var redemptions: [RewardRedemption]
    @Query private var progressItems: [Progress]

    @State private var editorRoute: RewardProductEditorRoute?
    @State private var pendingProduct: RewardProduct?
    @State private var isShowingRedemptionConfirmation = false
    @State private var archivingProduct: RewardProduct?
    @State private var isShowingArchiveConfirmation = false
    @State private var isShowingHistory = false
    @State private var isShowingMessage = false
    @State private var message = ""
    @State private var submissionState = RewardRedemptionSubmissionState()

    private var activeProducts: [RewardProduct] {
        products.filter { !$0.isArchived }
    }

    private var archivedProducts: [RewardProduct] {
        products.filter(\.isArchived)
    }

    private var balancePresentation: RewardBalancePresentation {
        do {
            return .available(try CoinLedgerService.balance(in: context))
        } catch {
            return .unavailable
        }
    }

    private var pendingRedemptionCount: Int {
        redemptions.lazy.filter { $0.status == .pending }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ZStack(alignment: .top) {
                    RewardPageParticleTrail()

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
                            isSubmitting: submissionState.isSubmitting,
                            onRedeem: requestRedemption,
                            onEdit: edit,
                            onArchive: requestArchive
                        )
                        .padding(.top, RewardStoreLayout.productTopSpacing)

                        if !archivedProducts.isEmpty {
                            DisclosureGroup("已归档  \(archivedProducts.count)") {
                                RewardProductList(
                                    products: archivedProducts,
                                    balance: balancePresentation,
                                    isSubmitting: submissionState.isSubmitting,
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
                }
                .padding(.horizontal, LivingOSMetrics.pageHorizontalInset)
                .padding(.top, RewardStoreLayout.pageTopPadding)
                .padding(.bottom, RootTabPageLayout.contentBottomPadding)
            }
            .background(LivingOSTheme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editorRoute) { route in
                RewardProductEditor(product: route.product)
            }
            .sheet(isPresented: $isShowingHistory) {
                RewardRedemptionHistoryView(redemptions: redemptions)
            }
            .confirmationDialog(
                "确认兑换？",
                isPresented: $isShowingRedemptionConfirmation
            ) {
                if let pendingProduct {
                    Button("确认兑换") { redeem(pendingProduct) }
                        .disabled(submissionState.isSubmitting)
                    Button("取消", role: .cancel) {}
                }
            } message: {
                if let pendingProduct {
                    let postBalance = max(
                        0,
                        (balancePresentation.coinUnits ?? 0) - pendingProduct.priceCoinUnits
                    )
                    Text("\(pendingProduct.name) · 扣除 \(CoinDisplayFormatter.text(forCoinUnits: pendingProduct.priceCoinUnits)) 金币 · 兑换后余额 \(CoinDisplayFormatter.text(forCoinUnits: postBalance))。兑换记录将保存为待兑现。")
                }
            }
            .confirmationDialog(
                "归档这个奖励？",
                isPresented: $isShowingArchiveConfirmation
            ) {
                Button("归档", role: .destructive) {
                    if let archivingProduct { archive(archivingProduct) }
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("历史兑换记录会保留，归档后不能再次兑换。")
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

    private func requestRedemption(_ product: RewardProduct) {
        guard balancePresentation.allowsRedemption,
              !submissionState.isSubmitting else { return }
        pendingProduct = product
        isShowingRedemptionConfirmation = true
    }

    private func requestArchive(_ product: RewardProduct) {
        archivingProduct = product
        isShowingArchiveConfirmation = true
    }

    private func importLegacyXP() {
        guard let progress = progressItems.first else { return }
        _ = try? CoinLedgerService.ensureLegacyXPImported(progress: progress, in: context)
    }

    private func redeem(_ product: RewardProduct) {
        guard balancePresentation.allowsRedemption else {
            message = "金币余额暂时无法读取，请稍后重试。"
            isShowingMessage = true
            pendingProduct = nil
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
            message = "已兑换，记得兑现“\(product.name)”"
        } catch RewardRedemptionError.insufficientBalance {
            message = "金币余额不足，还需要更多 XP 才能兑换。"
        } catch RewardRedemptionError.productArchived {
            message = "这个奖励已归档。"
        } catch {
            message = "兑换失败，请重试。"
        }
        isShowingMessage = true
        pendingProduct = nil
    }

    private func archive(_ product: RewardProduct) {
        do {
            try RewardStoreService.archive(product, in: context)
            message = "已归档“\(product.name)”"
        } catch {
            message = "归档失败，请重试。"
        }
        isShowingMessage = true
        archivingProduct = nil
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
        RewardLedgerStrip(balanceCoinUnits: balance.coinUnits ?? 0)
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}

private struct RewardLedgerStrip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    let balanceCoinUnits: Int

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: pausesTimeline)) { timeline in
            let samples = RewardLedgerGeometry.samples(
                columns: 24,
                rows: 6,
                balanceCoinUnits: balanceCoinUnits,
                phase: timeline.date.timeIntervalSinceReferenceDate / 9,
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

private struct RewardPageParticleTrail: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: pausesTimeline)) { timeline in
            let samples = RewardPageTrailGeometry.samples(
                count: 54,
                phase: timeline.date.timeIntervalSinceReferenceDate / 7.5,
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
                    let color = sample.usesLightInk ? Color.white : LivingOSTheme.graphite
                    if sample.usesLightInk {
                        context.fill(
                            Path(ellipseIn: rect.insetBy(dx: -1.1, dy: -1.1)),
                            with: .color(LivingOSTheme.graphite.opacity(0.08))
                        )
                    }
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(color.opacity(sample.opacity))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 500)
        .offset(y: RewardStoreLayout.particleTrailTopOffset)
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

private struct RewardProductList: View {
    let products: [RewardProduct]
    let balance: RewardBalancePresentation
    let isSubmitting: Bool
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
                        isSubmitting: isSubmitting,
                        onRedeem: { onRedeem(product) },
                        onEdit: { onEdit(product) },
                        onArchive: { onArchive(product) }
                    )
                }
            }
        }
    }
}

private struct RewardProductRail: View {
    let product: RewardProduct
    let balance: RewardBalancePresentation
    let isSubmitting: Bool
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
            isArchived: product.isArchived
        )
    }

    private var canRedeem: Bool {
        balance.allowsRedemption && presentation.canRedeem && !isSubmitting
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(presentation.name)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(canRedeem ? LivingOSTheme.ink : LivingOSTheme.graphite)
                    .fixedSize(horizontal: false, vertical: true)

                Text(CoinDisplayFormatter.text(forCoinUnits: presentation.priceCoinUnits))
                    .font(.system(.title3, design: .rounded, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(canRedeem ? LivingOSTheme.ink : LivingOSTheme.graphite)

                Text(presentation.note.isEmpty ? presentation.statusText : presentation.note)
                    .font(.footnote)
                    .foregroundStyle(LivingOSTheme.graphite)
                    .lineLimit(2)

                if !presentation.note.isEmpty, !presentation.canRedeem {
                    Text(presentation.statusText)
                        .font(.system(.caption2, design: .monospaced, weight: .medium))
                        .foregroundStyle(LivingOSTheme.graphite)
                }
            }

            Spacer(minLength: 8)

            if let imageReference = product.imageReference {
                Button(action: onRedeem) {
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
                .buttonStyle(.plain)
                .disabled(!canRedeem)
                .opacity(canRedeem ? 1 : 0.58)
                .accessibilityLabel("兑换 \(presentation.name)")
                .accessibilityIdentifier("rewards.redeem.\(product.id.uuidString)")
            } else if !product.isArchived {
                Button(action: onRedeem) {
                    HStack(spacing: 8) {
                        Text(presentation.canRedeem ? "兑换" : presentation.statusText)
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
                .buttonStyle(.plain)
                .disabled(!canRedeem)
                .opacity(canRedeem ? 1 : 0.48)
                .accessibilityIdentifier("rewards.redeem.\(product.id.uuidString)")
            }
        }
        .padding(.vertical, 22)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onEdit)
        .contextMenu {
            Button("编辑", action: onEdit)
            if !product.isArchived {
                Button("归档", role: .destructive, action: onArchive)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(presentation.accessibilityLabel)
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
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(redemption.productNameSnapshot)
                                    .font(.headline)
                                Spacer()
                                Text(redemption.status == .fulfilled ? "已兑现" : "待兑现")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(redemption.status == .fulfilled ? .secondary : TodayVisualTheme.reward)
                            }
                            Text("\(CoinDisplayFormatter.text(forCoinUnits: redemption.priceCoinUnitsSnapshot)) 金币 · \(redemption.redeemedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                            if !redemption.noteSnapshot.isEmpty {
                                Text(redemption.noteSnapshot)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if redemption.status == .pending {
                                Button("标记为已兑现") {
                                    try? RewardStoreService.fulfill(redemption, in: context)
                                }
                                .font(.subheadline.weight(.medium))
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(redemption.productNameSnapshot)，\(redemption.status == .fulfilled ? "已兑现" : "待兑现")")
                    }
                }
            }
            .navigationTitle("兑换历史")
            .navigationBarTitleDisplayMode(.inline)
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
