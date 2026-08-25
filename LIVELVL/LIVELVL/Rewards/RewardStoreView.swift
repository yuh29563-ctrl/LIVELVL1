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

    @State private var isShowingEditor = false
    @State private var editingProduct: RewardProduct?
    @State private var pendingProduct: RewardProduct?
    @State private var isShowingRedemptionConfirmation = false
    @State private var archivingProduct: RewardProduct?
    @State private var isShowingArchiveConfirmation = false
    @State private var isShowingHistory = false
    @State private var isShowingMessage = false
    @State private var message = ""

    private var activeProducts: [RewardProduct] {
        products.filter { !$0.isArchived }
    }

    private var archivedProducts: [RewardProduct] {
        products.filter(\.isArchived)
    }

    private var balance: Int {
        (try? CoinLedgerService.balance(in: context)) ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    balanceCard

                    VStack(alignment: .leading, spacing: 12) {
                        Text("我的现实奖励")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(TodayVisualTheme.ink)

                        if activeProducts.isEmpty {
                            ContentUnavailableView(
                                "还没有奖励",
                                systemImage: "gift",
                                description: Text("创建一个值得用金币兑换的现实奖励")
                            )
                            .frame(maxWidth: .infinity, minHeight: 180)
                        } else {
                            ForEach(activeProducts) { product in
                                RewardProductCard(
                                    product: product,
                                    balance: balance,
                                    onRedeem: {
                                        pendingProduct = product
                                        isShowingRedemptionConfirmation = true
                                    },
                                    onEdit: {
                                        editingProduct = product
                                        isShowingEditor = true
                                    },
                                    onArchive: {
                                        archivingProduct = product
                                        isShowingArchiveConfirmation = true
                                    }
                                )
                            }
                        }
                    }

                    if !archivedProducts.isEmpty {
                        DisclosureGroup("已归档（\(archivedProducts.count)）") {
                            VStack(spacing: 12) {
                                ForEach(archivedProducts) { product in
                                    RewardProductCard(
                                        product: product,
                                        balance: balance,
                                        onRedeem: {},
                                        onEdit: {
                                            editingProduct = product
                                            isShowingEditor = true
                                        },
                                        onArchive: {}
                                    )
                                    .opacity(0.62)
                                }
                            }
                            .padding(.top, 10)
                        }
                        .font(.headline)
                        .foregroundStyle(TodayVisualTheme.ink)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, RootTabPageLayout.contentTopPadding)
                .padding(.bottom, RootTabPageLayout.contentBottomPadding)
            }
            .background(TodayVisualTheme.pageBackground)
            .navigationTitle("奖励")
            .navigationBarTitleDisplayMode(RootTabPageLayout.navigationTitleMode)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("历史") { isShowingHistory = true }
                        .accessibilityIdentifier("rewards.history")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingProduct = nil
                        isShowingEditor = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("创建现实奖励")
                    .accessibilityIdentifier("rewards.create")
                }
            }
            .sheet(isPresented: $isShowingEditor) {
                RewardProductEditor(product: editingProduct)
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
                    Button("取消", role: .cancel) {}
                }
            } message: {
                if let pendingProduct {
                    Text("将扣除 \(CoinDisplayFormatter.text(forCoinUnits: pendingProduct.priceCoinUnits)) 金币，并记录为待兑现。")
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

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("可用金币", systemImage: "circle.hexagongrid.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(CoinDisplayFormatter.text(forCoinUnits: balance))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(TodayVisualTheme.ink)
            Text("1 XP = 0.1 金币 · 完成任务自动获得")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TodayVisualTheme.cloud, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("可用金币 \(CoinDisplayFormatter.text(forCoinUnits: balance))")
        .accessibilityIdentifier("rewards.balance")
    }

    private func importLegacyXP() {
        guard let progress = progressItems.first else { return }
        _ = try? CoinLedgerService.ensureLegacyXPImported(progress: progress, in: context)
    }

    private func redeem(_ product: RewardProduct) {
        let requestKey = UUID().uuidString
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

private struct RewardProductCard: View {
    let product: RewardProduct
    let balance: Int
    let onRedeem: () -> Void
    let onEdit: () -> Void
    let onArchive: () -> Void

    private var canRedeem: Bool {
        !product.isArchived && balance >= product.priceCoinUnits
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                RewardProductImageView(reference: product.imageReference)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(product.name)
                        .font(.headline)
                        .foregroundStyle(TodayVisualTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("需要 \(CoinDisplayFormatter.text(forCoinUnits: product.priceCoinUnits)) 金币")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(canRedeem ? TodayVisualTheme.reward : .secondary)
                    if !product.note.isEmpty {
                        Text(product.note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                if !product.isArchived {
                    Button("兑换", action: onRedeem)
                        .buttonStyle(.borderedProminent)
                        .tint(TodayVisualTheme.ink)
                        .accessibilityIdentifier("rewards.redeem.\(product.id.uuidString)")
                }
                Button("编辑", action: onEdit)
                    .buttonStyle(.bordered)
                if !product.isArchived {
                    Button("归档", role: .destructive, action: onArchive)
                        .buttonStyle(.borderless)
                }
            }
            .font(.subheadline.weight(.medium))
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(TodayVisualTheme.ink.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
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
                        Label(imageReference == nil ? "选择图片" : "替换图片", systemImage: "photo")
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
    let reference: String?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "gift")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: reference) {
            guard let reference else {
                image = nil
                return
            }
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
