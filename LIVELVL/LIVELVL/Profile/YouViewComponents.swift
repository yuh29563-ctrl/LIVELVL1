import SwiftUI

struct YouPageTitle: View {
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 72

    var body: some View {
        Text("You")
            .font(.system(size: titleSize, weight: .bold))
            .tracking(-4)
            .foregroundStyle(LivingOSTheme.ink)
            .minimumScaleFactor(0.76)
            .accessibilityAddTraits(.isHeader)
    }
}
struct YouIdentityHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let level: Int

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    brand
                    identity
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    brand
                    Spacer()
                    identity
                }
            }
        }
        .foregroundStyle(LivingOSTheme.ink)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("LIVELVL，YOU，等级 \(level)")
    }

    private var brand: some View {
        Text("LIVELVL")
            .font(.system(.caption, design: .monospaced).weight(.semibold))
            .tracking(4.2)
    }

    private var identity: some View {
        Text("YOU / LEVEL \(level)")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(LivingOSTheme.graphite)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }
}

struct YouStateHeadline: View {
    let score: Int
    @ScaledMetric(relativeTo: .title) private var stateSize: CGFloat = 32
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 36

    private var stateWord: String {
        switch score {
        case ..<40: "重整"
        case ..<70: "调整"
        case ..<90: "稳定"
        default: "高能"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("系统状态")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(LivingOSTheme.graphite)
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                Text(stateWord)
                    .font(.system(size: stateSize, weight: .semibold))
                Text(score, format: .number)
                    .font(.system(size: scoreSize, weight: .light, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(LivingOSTheme.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("系统状态 \(stateWord)，\(score) 分")
    }
}

struct YouStateField: View {
    let nodes: [LifeFieldNodePresentation]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                YouParticleCloud()

                YouParticleLinks()

                YouHexagonOutline()
                    .stroke(LivingOSTheme.graphite.opacity(0.14), lineWidth: 0.7)

                YouParticleFigure()
                    .frame(width: 94, height: 174)
                    .position(
                        x: LifeFieldLayout.visualCore.x * proxy.size.width,
                        y: LifeFieldLayout.visualCore.y * proxy.size.height + 20
                    )

                ForEach(nodes) { node in
                    YouStateNode(node: node)
                        .frame(width: node.dimension == .health || node.dimension == .relationships ? 132 : 82)
                        .position(LifeFieldLayout.point(for: node.dimension, in: proxy.size))
                }
            }
        }
    }
}

struct YouStateNode: View {
    let node: LifeFieldNodePresentation
    @ScaledMetric(relativeTo: .caption) private var titleSize: CGFloat = 13
    @ScaledMetric(relativeTo: .callout) private var valueSize: CGFloat = 14

    var body: some View {
        ZStack {
            ZStack {
                Circle()
                    .stroke(LivingOSTheme.graphite.opacity(0.2), lineWidth: 0.7)
                    .frame(width: 24, height: 24)
                Circle()
                    .fill(LivingOSTheme.ink)
                    .frame(width: 9, height: 9)
            }

            VStack(spacing: 1) {
                Text(node.title)
                    .font(.system(size: titleSize, weight: .medium))
                Text(node.displayValue, format: .number)
                    .font(.system(size: valueSize, design: .monospaced))
                    .foregroundStyle(LivingOSTheme.graphite)
            }
            .offset(y: YouStateNodeLayout.labelOffset(for: node.dimension))
        }
        .frame(minWidth: 44, minHeight: 44)
        .foregroundStyle(LivingOSTheme.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(node.title)
        .accessibilityValue("\(node.displayValue) 分")
    }
}

struct YouParticleCloud: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 18.0,
            paused: reduceMotion || scenePhase != .active
        )) { timeline in
            let frozen = reduceMotion || scenePhase != .active
            let samples = LivingDotFieldGeometry.samples(
                columns: 31,
                rows: 31,
                phase: frozen ? 0.18 : timeline.date.timeIntervalSinceReferenceDate / 14,
                reduceMotion: frozen
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
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct YouParticleLinks: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 18.0,
            paused: reduceMotion || scenePhase != .active
        )) { timeline in
            let frozen = reduceMotion || scenePhase != .active
            let samples = LifeFieldParticleLinkGeometry.samples(
                countPerLink: 34,
                phase: frozen ? 0.19 : timeline.date.timeIntervalSinceReferenceDate / 8,
                reduceMotion: frozen
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
                        with: .color(LivingOSTheme.ink.opacity(sample.opacity * 0.6))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct YouParticleFigure: View {
    var body: some View {
        YouParticleCloud()
            .mask {
                Image(systemName: "figure.stand")
                    .resizable()
                    .scaledToFit()
                    .padding(.vertical, 4)
            }
            .overlay {
                Image(systemName: "figure.stand")
                    .resizable()
                    .scaledToFit()
                    .padding(.vertical, 4)
                    .foregroundStyle(LivingOSTheme.ink.opacity(0.08))
            }
            .accessibilityHidden(true)
    }
}

struct YouHexagonOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let dimensions: [LifeDimension] = [
            .health, .learning, .finance, .relationships, .career, .interests,
        ]
        var path = Path()
        for (index, dimension) in dimensions.enumerated() {
            let point = LifeFieldLayout.point(for: dimension, in: rect.size)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        if let first = dimensions.first {
            path.addLine(to: LifeFieldLayout.point(for: first, in: rect.size))
        }
        return path
    }
}

struct WeeklyStateTimelineView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let days: [WeeklyStateDay]
    let now: Date
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本周")
                .font(.headline)

            Rectangle()
                .fill(LivingOSTheme.mist)
                .frame(height: 0.5)

            if dynamicTypeSize.isAccessibilitySize {
                ScrollView(.horizontal) {
                    timelineDays(fixedWidth: 72)
                }
                .scrollIndicators(.hidden)
            } else {
                timelineDays(fixedWidth: nil)
            }

            Rectangle()
                .fill(LivingOSTheme.mist)
                .frame(height: 0.5)
        }
    }

    private func timelineDays(fixedWidth: CGFloat?) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(days) { day in
                WeeklyStateDayView(
                    day: day,
                    isToday: calendar.isDate(day.date, inSameDayAs: now)
                )
                .frame(width: fixedWidth)
                .frame(maxWidth: fixedWidth == nil ? .infinity : nil)
            }
        }
    }
}

struct WeeklyStateDayView: View {
    let day: WeeklyStateDay
    let isToday: Bool

    var body: some View {
        VStack(spacing: 7) {
            Text(day.date, format: .dateTime.weekday(.narrow))
                .font(.caption.weight(isToday ? .semibold : .regular))
            Text(day.date, format: .dateTime.month(.twoDigits).day(.twoDigits))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(LivingOSTheme.graphite)
                .fixedSize(horizontal: true, vertical: false)

            ZStack(alignment: .top) {
                if isToday {
                    Rectangle()
                        .fill(LivingOSTheme.signal)
                        .frame(width: 1, height: 42)
                    Circle()
                        .fill(LivingOSTheme.signal)
                        .frame(width: 7, height: 7)
                }

                WeeklyActivityGlyph(day: day)
                    .frame(width: 22, height: 42)
                    .offset(y: isToday ? 12 : 0)
            }
            .frame(height: 48)

            Text(isToday ? "今天" : " ")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isToday ? LivingOSTheme.signal : .clear)
        }
        .foregroundStyle(LivingOSTheme.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month().day()))
        .accessibilityValue("完成 \(day.completedCount) 项，获得 \(day.xp) XP\(isToday ? "，今天" : "")")
    }
}

struct WeeklyActivityGlyph: View {
    let day: WeeklyStateDay

    var body: some View {
        Canvas { context, size in
            let columns = 3
            let rows = 6
            let total = columns * rows
            let active = min(total, max(day.completedCount == 0 ? 0 : 3, day.completedCount * 3 + day.xp / 25))
            for index in 0..<total {
                let column = index % columns
                let row = index / columns
                let diameter: CGFloat = index < active ? 1.7 : 1.1
                let x = (CGFloat(column) + 0.5) * size.width / CGFloat(columns)
                let y = (CGFloat(row) + 0.5) * size.height / CGFloat(rows)
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: x - diameter / 2,
                        y: y - diameter / 2,
                        width: diameter,
                        height: diameter
                    )),
                    with: .color(LivingOSTheme.ink.opacity(index < active ? 0.78 : 0.1))
                )
            }
        }
        .accessibilityHidden(true)
    }
}

struct YouSettingsRows: View {
#if DEBUG
    let onReset: () -> Void
#endif

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink {
                StateAssessmentView(mode: .weekly)
            } label: {
                YouSettingsRow(icon: "waveform.path.ecg", title: "每周评估")
            }

            NavigationLink {
                LocalDataPrivacyView()
            } label: {
                YouSettingsRow(icon: "lock.shield", title: "数据与隐私")
            }

            NavigationLink {
#if DEBUG
                YouPreferencesView(onReset: onReset)
#else
                YouPreferencesView()
#endif
            } label: {
                YouSettingsRow(icon: "gearshape", title: "设置")
            }
        }
    }
}

struct YouSettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3.weight(.light))
                .frame(width: 28)
            Text(title)
                .font(.body)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(LivingOSTheme.graphite)
        }
        .foregroundStyle(LivingOSTheme.ink)
        .frame(minHeight: 62)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LivingOSTheme.mist)
                .frame(height: 0.5)
        }
        .contentShape(Rectangle())
    }
}

struct LocalDataPrivacyView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 42

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Local by design")
                    .font(.system(size: titleSize, weight: .bold))
                    .tracking(-1.5)
                Text("任务、状态评估、卡片、金币、现实奖励与图片都只保存在这台设备上。LIVELVL 不使用账户、网络、云同步或真实支付。")
                    .font(.body)
                    .foregroundStyle(LivingOSTheme.graphite)
                    .fixedSize(horizontal: false, vertical: true)
                Text("删除 App 或使用 Debug 全量重置会移除本地数据；历史兑换保留商品当时的名称、价格、备注与图片引用快照。")
                    .font(.body)
                    .foregroundStyle(LivingOSTheme.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(LivingOSMetrics.pageHorizontalInset)
        }
        .background(LivingOSTheme.canvas)
        .navigationTitle("数据与隐私")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct YouPreferencesView: View {
#if DEBUG
    let onReset: () -> Void
#endif

    var body: some View {
        List {
            Section("显示与辅助功能") {
                Text("LIVELVL 会跟随系统的动态字体、VoiceOver 与减少动态效果设置。")
                    .foregroundStyle(.secondary)
            }

#if DEBUG
            Section("开发者") {
                Button("重置所有本地数据", role: .destructive, action: onReset)
            }
#endif
        }
        .scrollContentBackground(.hidden)
        .background(LivingOSTheme.canvas)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}
