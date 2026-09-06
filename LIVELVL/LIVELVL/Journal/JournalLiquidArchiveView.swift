import SwiftData
import SwiftUI
import UIKit

private enum JournalFocusField: Hashable {
    case title
    case body
}

private struct JournalDraftSnapshot: Hashable {
    let title: String
    let body: String

    static let empty = JournalDraftSnapshot(title: "", body: "")
}

private enum JournalSaveState: Equatable {
    case idle
    case saving
    case saved
    case failed

    var headline: String {
        switch self {
        case .idle: "AUTO SAVE"
        case .saving: "SAVING"
        case .saved: "AUTO SAVED"
        case .failed: "SAVE FAILED"
        }
    }

    var detail: String {
        switch self {
        case .idle: "无需手动保存 · ✓ 完成并返回"
        case .saving: "正在自动保存…"
        case .saved: "已自动保存 · ✓ 完成并返回"
        case .failed: "自动保存失败 · 轻触重试"
        }
    }
}

private enum JournalPendingExit: Equatable {
    case close
    case complete
}

struct JournalLiquidArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \JournalEntry.dayStart, order: .reverse) private var entries: [JournalEntry]

    let onClose: () -> Void

    @FocusState private var focusedField: JournalFocusField?
    @State private var title = ""
    @State private var entryBody = ""
    @State private var entryState: JournalEntryState = .draft
    @State private var saveState: JournalSaveState = .idle
    @State private var lastSavedSnapshot = JournalDraftSnapshot.empty
    @State private var hasLoadedEntry = false
    @State private var isShowingSaveError = false
    @State private var pendingExit: JournalPendingExit?
    @State private var isShowingArchive = false
    @State private var isEntranceExpanded = false
    @State private var isShowingEntrance = true
    @State private var isShowingPhotoNote = false

    private let journalDate: Date
    private let stamp: JournalDateStamp

    init(date: Date = .now, onClose: @escaping () -> Void) {
        journalDate = date
        stamp = JournalDateStamp(date: date)
        self.onClose = onClose
    }

    private var draftSnapshot: JournalDraftSnapshot {
        JournalDraftSnapshot(title: title, body: entryBody)
    }

    private var isEditorFocused: Bool { focusedField != nil }
    private var activeEntries: [JournalEntry] { entries.filter { $0.deletedAt == nil } }

    var body: some View {
        ZStack {
            JournalOpticalField(reduceMotion: reduceMotion)
                .ignoresSafeArea()

            editorScreen
                .accessibilityHidden(isShowingArchive)

            if isShowingArchive {
                JournalArchiveOverlay(
                    entries: activeEntries,
                    onClose: closeArchive
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(10)
            }

            if isShowingPhotoNote {
                JournalNotice(text: "照片将在日记数据层完成后接入")
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
            }

            if isShowingEntrance {
                JournalBookEntrance(isExpanded: isEntranceExpanded)
                    .accessibilityHidden(true)
                    .zIndex(30)
            }
        }
        .foregroundStyle(JournalLiquidPalette.ink)
        .preferredColorScheme(.light)
        .onAppear(perform: playEntrance)
        .task { loadTodayEntry() }
        .task(id: draftSnapshot, priority: .utility) {
            await autosaveAfterDebounce()
        }
        .onChange(of: focusedField) { _, field in
            guard field != nil, isShowingArchive else { return }
            closeArchive()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active, hasLoadedEntry, draftSnapshot != lastSavedSnapshot else { return }
            _ = persistCurrentEntry()
        }
        .alert("未能自动保存", isPresented: $isShowingSaveError) {
            Button("重试") { retrySave() }
            Button("复制内容") { copyDraft() }
            Button("继续编辑", role: .cancel) { pendingExit = nil }
        } message: {
            Text("内容仍保留在当前页面。请重试，或先复制文字后继续。")
        }
    }

    private var editorScreen: some View {
        VStack(spacing: 0) {
            JournalTopBar(
                stamp: stamp,
                isReceded: isEditorFocused,
                onClose: requestClose,
                onHistory: openArchive
            )

            JournalHero(
                stamp: stamp,
                isFocused: isEditorFocused,
                usesCompactType: dynamicTypeSize.isAccessibilitySize
            )
            .frame(height: isEditorFocused ? 38 : (dynamicTypeSize.isAccessibilitySize ? 152 : 136))

            JournalWritingSurface(
                title: $title,
                text: Binding(
                    get: { entryBody },
                    set: { entryBody = String($0.prefix(JournalEntryStore.maximumBodyLength)) }
                ),
                stamp: stamp,
                focusedField: $focusedField
            )

            JournalPrivacyLine()
                .opacity(isEditorFocused ? 0.34 : 1)
                .padding(.horizontal, 25)
                .padding(.bottom, 8)

            JournalBottomDock(
                isFocused: isEditorFocused,
                isCompleted: entryState == .completed,
                saveState: saveState,
                onPhoto: showPhotoNote,
                onRetry: retrySave,
                onComplete: completeAndClose
            )
            .padding(.horizontal, isEditorFocused ? 30 : 17)
            .padding(.bottom, 10)
        }
        .animation(focusAnimation, value: isEditorFocused)
    }

    private var focusAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.16)
            : .spring(response: 0.72, dampingFraction: 0.88)
    }

    private func playEntrance() {
        guard isShowingEntrance else { return }

        if reduceMotion {
            withAnimation(.easeOut(duration: 0.18)) {
                isShowingEntrance = false
            }
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.spring(response: 0.82, dampingFraction: 0.88)) {
                isEntranceExpanded = true
            }
            try? await Task.sleep(for: .milliseconds(680))
            withAnimation(.easeOut(duration: 0.28)) {
                isShowingEntrance = false
            }
        }
    }

    private func openArchive() {
        focusedField = nil
        guard persistCurrentEntry() else { return }
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.7, dampingFraction: 0.9)) {
            isShowingArchive = true
        }
    }

    private func closeArchive() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.64, dampingFraction: 0.92)) {
            isShowingArchive = false
        }
    }

    private func loadTodayEntry() {
        guard !hasLoadedEntry else { return }
        do {
            if let entry = try JournalEntryStore.entry(
                for: journalDate,
                timeZone: .current,
                in: modelContext
            ) {
                title = entry.title
                entryBody = entry.body
                entryState = entry.state
                lastSavedSnapshot = JournalDraftSnapshot(title: entry.title, body: entry.body)
                saveState = .saved
            }
            hasLoadedEntry = true
        } catch {
            hasLoadedEntry = true
            saveState = .failed
            isShowingSaveError = true
        }
    }

    private func autosaveAfterDebounce() async {
        guard hasLoadedEntry, draftSnapshot != lastSavedSnapshot else { return }
        saveState = .saving
        do {
            try await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            _ = persistCurrentEntry()
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }

    @discardableResult
    private func persistCurrentEntry(as requestedState: JournalEntryState? = nil) -> Bool {
        guard hasLoadedEntry else { return false }
        if let requestedState {
            entryState = requestedState
        }
        saveState = .saving
        do {
            let entry = try JournalEntryStore.save(
                title: title,
                body: entryBody,
                state: entryState,
                for: journalDate,
                timeZone: .current,
                in: modelContext
            )
            entryBody = String(entryBody.prefix(JournalEntryStore.maximumBodyLength))
            lastSavedSnapshot = draftSnapshot
            saveState = entry == nil ? .idle : .saved
            return true
        } catch {
            saveState = .failed
            isShowingSaveError = true
            return false
        }
    }

    private func requestClose() {
        focusedField = nil
        pendingExit = .close
        guard persistCurrentEntry() else { return }
        pendingExit = nil
        onClose()
    }

    private func completeAndClose() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.14) : .spring(response: 0.36, dampingFraction: 0.68)) {
            focusedField = nil
            entryState = .completed
        }
        pendingExit = .complete
        guard persistCurrentEntry(as: .completed) else { return }
        pendingExit = nil
        onClose()
    }

    private func retrySave() {
        let exit = pendingExit
        let requestedState: JournalEntryState? = exit == .complete ? .completed : nil
        guard persistCurrentEntry(as: requestedState) else { return }
        pendingExit = nil
        if exit != nil {
            onClose()
        }
    }

    private func copyDraft() {
        let separator = title.isEmpty || entryBody.isEmpty ? "" : "\n\n"
        UIPasteboard.general.string = title + separator + entryBody
    }

    private func showPhotoNote() {
        withAnimation(.easeOut(duration: 0.2)) {
            isShowingPhotoNote = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeIn(duration: 0.2)) {
                isShowingPhotoNote = false
            }
        }
    }
}

private enum JournalLiquidPalette {
    static let ink = Color(red: 9 / 255, green: 10 / 255, blue: 11 / 255)
    static let graphite = Color(red: 112 / 255, green: 116 / 255, blue: 123 / 255)
    static let hairline = Color.black.opacity(0.10)
    static let silver = Color(red: 232 / 255, green: 234 / 255, blue: 237 / 255)
}

private struct JournalDateStamp: Equatable {
    let day: String
    let month: String
    let weekday: String
    let time: String
    let year: String

    init(date: Date, calendar: Calendar = .current) {
        day = String(format: "%02d", calendar.component(.day, from: date))
        year = String(calendar.component(.year, from: date))
        month = date.formatted(
            Date.FormatStyle().month(.abbreviated).locale(Locale(identifier: "en_US"))
        ).uppercased()
        weekday = date.formatted(
            Date.FormatStyle().weekday(.wide).locale(Locale(identifier: "en_US"))
        ).uppercased()
        time = date.formatted(
            Date.FormatStyle().hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)
                .locale(Locale(identifier: "en_GB"))
        )
    }

    var longDate: String { "\(day) · \(month) · \(weekday)" }
}

private struct JournalOpticalField: View {
    let reduceMotion: Bool
    @State private var isDrifting = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 246 / 255, green: 247 / 255, blue: 248 / 255),
                    JournalLiquidPalette.silver,
                    Color(red: 216 / 255, green: 219 / 255, blue: 223 / 255),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.78))
                .frame(width: 330, height: 330)
                .blur(radius: 54)
                .offset(x: isDrifting ? 152 : 86, y: isDrifting ? -234 : -286)

            Circle()
                .fill(Color(red: 126 / 255, green: 132 / 255, blue: 142 / 255).opacity(0.10))
                .frame(width: 410, height: 410)
                .blur(radius: 76)
                .offset(x: isDrifting ? -188 : -152, y: isDrifting ? 254 : 286)
        }
        .drawingGroup()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                isDrifting = true
            }
        }
        .accessibilityHidden(true)
    }
}

private struct JournalTopBar: View {
    let stamp: JournalDateStamp
    let isReceded: Bool
    let onClose: () -> Void
    let onHistory: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 18) {
                    content
                }
            } else {
                content
            }
        }
        .padding(.horizontal, 17)
        .padding(.top, 6)
        .frame(height: 62)
        .opacity(isReceded ? 0.25 : 1)
        .blur(radius: isReceded ? 2.4 : 0)
        .offset(y: isReceded ? -10 : 0)
    }

    private var content: some View {
        HStack {
            JournalGlassCircleButton(symbol: "xmark", accessibilityLabel: "关闭日记", action: onClose)
            Spacer()
            Text(stamp.longDate)
                .font(.system(size: 10, weight: .bold))
                .tracking(2.0)
                .foregroundStyle(JournalLiquidPalette.graphite)
                .accessibilityLabel("\(stamp.month) \(stamp.day)，\(stamp.weekday)")
            Spacer()
            JournalGlassCircleButton(symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90", accessibilityLabel: "日记历史", action: onHistory)
                .accessibilityIdentifier("journal-history-button")
        }
    }
}

private struct JournalGlassCircleButton: View {
    let symbol: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(JournalInteractiveGlassModifier())
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct JournalInteractiveGlassModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.72), lineWidth: 0.7))
                .shadow(color: .black.opacity(0.07), radius: 12, y: 7)
        }
    }
}

private struct JournalGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            let rectangle = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            content
                .background(.ultraThinMaterial, in: rectangle)
                .overlay(rectangle.stroke(.white.opacity(0.72), lineWidth: 0.7))
                .shadow(color: .black.opacity(0.07), radius: 12, y: 7)
        }
    }
}

private struct JournalHero: View {
    let stamp: JournalDateStamp
    let isFocused: Bool
    let usesCompactType: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(stamp.day)
                .font(.system(size: usesCompactType ? 62 : 86, weight: .medium))
                .tracking(-6)
                .foregroundStyle(.black.opacity(0.045))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                Text("A PRIVATE TRACE OF TODAY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2.1)
                    .foregroundStyle(JournalLiquidPalette.graphite)
                Text("TODAY")
                    .font(.system(size: usesCompactType ? 40 : 49, weight: .bold))
                    .tracking(-2.8)
                Text("此刻之后，它只属于你。")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(JournalLiquidPalette.graphite)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, usesCompactType ? 12 : 25)
        }
        .padding(.horizontal, 24)
        .opacity(isFocused ? 0.12 : 1)
        .blur(radius: isFocused ? 3 : 0)
        .offset(y: isFocused ? -22 : 0)
        .clipped()
        .accessibilityHidden(isFocused)
    }
}

private struct JournalWritingSurface: View {
    @Binding var title: String
    @Binding var text: String
    let stamp: JournalDateStamp
    let focusedField: FocusState<JournalFocusField?>.Binding

    private var isFocused: Bool { focusedField.wrappedValue != nil }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 0) {
                Circle()
                    .fill(LivingOSTheme.signal)
                    .frame(width: 8, height: 8)
                    .shadow(color: LivingOSTheme.signal.opacity(0.22), radius: 0, x: 0, y: 0)
                    .background {
                        Circle()
                            .fill(LivingOSTheme.signal.opacity(0.10))
                            .frame(width: 20, height: 20)
                    }
                Rectangle()
                    .fill(LinearGradient(
                        colors: [JournalLiquidPalette.graphite.opacity(0.6), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 0.7)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(stamp.time)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(JournalLiquidPalette.graphite)

                TextField("给今天一个标题", text: $title)
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-0.8)
                    .foregroundStyle(JournalLiquidPalette.ink.opacity(0.94))
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.next)
                    .focused(focusedField, equals: .title)
                    .onSubmit { focusedField.wrappedValue = .body }
                    .padding(.top, 7)
                    .accessibilityLabel("今日日记标题")
                    .accessibilityIdentifier("journal-title-field")

                Rectangle()
                    .fill(JournalLiquidPalette.hairline)
                    .frame(height: 0.5)
                    .padding(.vertical, 8)

                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(isFocused ? "从此刻开始……" : "今天，想留下什么？")
                            .font(.system(size: 20, weight: .regular, design: .serif))
                            .foregroundStyle(JournalLiquidPalette.ink.opacity(0.24))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $text)
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .lineSpacing(8)
                        .foregroundStyle(JournalLiquidPalette.ink.opacity(0.92))
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .focused(focusedField, equals: .body)
                        .accessibilityLabel("今日日记正文")
                        .accessibilityIdentifier("journal-editor")
                }
            }
        }
        .padding(.horizontal, 25)
        .frame(maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("收起键盘") {
                    focusedField.wrappedValue = nil
                }
            }
        }
    }
}

private struct JournalPrivacyLine: View {
    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(JournalLiquidPalette.graphite)
                .frame(width: 5, height: 5)
            Text("ON THIS DEVICE · PRIVATE")
                .font(.system(size: 9, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(JournalLiquidPalette.graphite)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("仅保留在此设备，私密自动保存")
    }
}

private struct JournalBottomDock: View {
    let isFocused: Bool
    let isCompleted: Bool
    let saveState: JournalSaveState
    let onPhoto: () -> Void
    let onRetry: () -> Void
    let onComplete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if !isFocused {
                Button(action: onPhoto) {
                    Image(systemName: "photo")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加照片")
                .accessibilityHint("照片功能将在日记数据层完成后开放")
            }

            Button(action: { if saveState == .failed { onRetry() } }) {
                VStack(spacing: 3) {
                    HStack(spacing: 6) {
                        if saveState == .saving {
                            ProgressView()
                                .controlSize(.mini)
                        }
                        Text(saveState.headline)
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.6)
                    }
                    Text(saveState.detail)
                        .font(.system(size: 9))
                        .foregroundStyle(saveState == .failed ? LivingOSTheme.signal : JournalLiquidPalette.graphite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(saveState.detail)

            Button(action: onComplete) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(JournalLiquidPalette.ink, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .scaleEffect(isCompleted ? 1.04 : 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCompleted ? "保存并返回今天" : "完成今日日记并返回")
            .accessibilityHint("标题和正文会自动保存")
            .accessibilityIdentifier("journal-complete-button")
        }
        .padding(5)
        .frame(height: isFocused ? 52 : 64)
        .modifier(JournalGlassSurfaceModifier(cornerRadius: isFocused ? 24 : 26))
    }
}

private struct JournalBookEntrance: View {
    let isExpanded: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: isExpanded ? 54 : 18, style: .continuous)
                    .fill(Color(red: 10 / 255, green: 11 / 255, blue: 12 / 255))
                    .frame(
                        width: isExpanded ? geometry.size.width * 1.34 : 142,
                        height: isExpanded ? geometry.size.height * 1.18 : 208
                    )
                    .shadow(color: .black.opacity(isExpanded ? 0 : 0.28), radius: 28, y: 18)
                Text("THE NOTE")
                    .font(.system(size: isExpanded ? 28 : 13, weight: .medium))
                    .tracking(isExpanded ? 4 : 2)
                    .foregroundStyle(.white.opacity(isExpanded ? 0 : 0.78))
            }
            .rotationEffect(.degrees(isExpanded ? 0 : -7))
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .opacity(isExpanded ? 0 : 1)
        }
        .ignoresSafeArea()
    }
}

private struct JournalArchiveOverlay: View {
    let entries: [JournalEntry]
    let onClose: () -> Void
    @State private var selectedEntry: JournalEntry?

    var body: some View {
        ZStack {
            JournalLiquidPalette.silver.opacity(0.88)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text("Archive")
                        .font(.system(size: 44, weight: .bold))
                        .tracking(-2.8)
                    Spacer()
                    JournalGlassCircleButton(symbol: "xmark", accessibilityLabel: "关闭日记历史", action: onClose)
                }
                .padding(.top, 10)

                Text("\(entries.count) 篇记录 · 从新到旧")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.0)
                    .foregroundStyle(JournalLiquidPalette.graphite)
                    .padding(.top, 45)
                    .padding(.bottom, 10)

                Rectangle()
                    .fill(JournalLiquidPalette.hairline)
                    .frame(height: 0.5)

                if entries.isEmpty {
                    Text("还没有留下记录")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(JournalLiquidPalette.graphite)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(entries) { entry in
                                Button {
                                    selectedEntry = entry
                                } label: {
                                    HStack(spacing: 10) {
                                        JournalArchiveRow(
                                            day: String(entry.archiveDate.suffix(2)),
                                            weekday: entry.archiveDate,
                                            state: entry.state == .completed ? "COMPLETED" : "DRAFT",
                                            metadata: "\(entry.body.count) CH"
                                        )
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(JournalLiquidPalette.graphite)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(entry.archiveDate)，\(entry.state == .completed ? "已完成" : "草稿")，\(entry.body.count) 字符")
                                .accessibilityHint("打开阅读日记")
                                .accessibilityIdentifier("journal-archive-entry-\(entry.dayKey)")
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                Spacer()

                Text("轻触记录阅读全文 · 列表不展示私人内容")
                    .font(.system(size: 10))
                    .foregroundStyle(JournalLiquidPalette.graphite)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 18)
            }
            .padding(.horizontal, 22)
        }
        .accessibilityIdentifier("journal-archive")
        .sheet(item: $selectedEntry) { entry in
            JournalArchiveReader(entry: entry)
                .presentationDragIndicator(.visible)
        }
    }
}

private extension JournalEntry {
    // The stored day key preserves the original journal date when travelling.
    var archiveDate: String { String(dayKey.prefix(10)) }
}

private struct JournalArchiveReader: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let entry: JournalEntry

    var body: some View {
        ZStack {
            JournalOpticalField(reduceMotion: reduceMotion)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text(entry.archiveDate)
                        .font(.subheadline.monospaced())
                        .foregroundStyle(JournalLiquidPalette.graphite)
                    Spacer()
                    JournalGlassCircleButton(
                        symbol: "xmark",
                        accessibilityLabel: "返回日记历史",
                        action: { dismiss() }
                    )
                    .accessibilityIdentifier("journal-reader-close")
                }
                .padding(.top, 24)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未命名日记" : entry.title)
                            .font(.largeTitle.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("journal-reader-title")

                        HStack(spacing: 8) {
                            Circle().fill(LivingOSTheme.signal).frame(width: 6, height: 6)
                            Text("\(entry.state == .completed ? "已完成" : "草稿") · \(entry.body.count) 字符")
                                .font(.caption)
                                .foregroundStyle(JournalLiquidPalette.graphite)
                        }

                        Rectangle().fill(JournalLiquidPalette.hairline).frame(height: 0.5)

                        Text(entry.body.isEmpty ? "这一天还没有正文。" : entry.body)
                            .font(.system(.title3, design: .serif))
                            .lineSpacing(8)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("journal-reader-body")
                    }
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 24)
        }
        .foregroundStyle(JournalLiquidPalette.ink)
        .preferredColorScheme(.light)
        .accessibilityIdentifier("journal-archive-reader")
    }
}

private struct JournalArchiveRow: View {
    let day: String
    let weekday: String
    let state: String
    let metadata: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                rowDay
                rowDescription
                Spacer()
                metadataText
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    rowDay
                    rowDescription
                }
                metadataText
            }
        }
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            Rectangle().fill(JournalLiquidPalette.hairline).frame(height: 0.5)
        }
    }

    private var rowDay: some View {
        Text(day)
            .font(.system(size: 29, weight: .bold))
            .tracking(-1.4)
            .frame(width: 44, alignment: .leading)
    }

    private var rowDescription: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(weekday)
                .font(.system(size: 12, weight: .semibold))
            Text(state)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.7)
                .foregroundStyle(JournalLiquidPalette.graphite)
        }
    }

    private var metadataText: some View {
        Text(metadata)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(JournalLiquidPalette.graphite)
    }
}

private struct JournalNotice: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .modifier(JournalGlassSurfaceModifier(cornerRadius: 22))
            .padding(.bottom, 92)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    JournalLiquidArchiveView(onClose: {})
        .modelContainer(for: JournalEntry.self, inMemory: true)
}
