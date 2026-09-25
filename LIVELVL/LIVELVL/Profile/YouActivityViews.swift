import Charts
import SwiftUI

struct YouLiveTableView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedYear: Int
    @State private var selectedActivity: YouDailyActivity?

    let completions: [Completion]
    let now: Date
    let calendar: Calendar

    init(completions: [Completion], now: Date, calendar: Calendar) {
        self.completions = completions
        self.now = now
        self.calendar = calendar
        _selectedYear = State(initialValue: calendar.component(.year, from: now))
    }

    private var years: [Int] {
        YouActivityHistoryBuilder.availableYears(
            completions: completions,
            now: now,
            calendar: calendar
        )
    }

    private var days: [YouDailyActivity] {
        YouActivityHistoryBuilder.year(
            completions: completions,
            year: selectedYear,
            now: now,
            calendar: calendar
        )
    }

    private var layout: YouYearGridLayout {
        YouYearGridLayout(days: days, calendar: calendar)
    }

    private var selectedYearIndex: Int {
        years.firstIndex(of: selectedYear) ?? max(0, years.count - 1)
    }

    private var hasActivity: Bool {
        days.contains { $0.hasActivity }
    }

    var body: some View {
        YouSurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                liveHeader

                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        yearGrid
                    }
                    .scrollIndicators(.hidden)
                    .onAppear { scrollToRelevantMonth(using: proxy) }
                    .onChange(of: selectedYear) { _, _ in
                        selectedActivity = nil
                        scrollToRelevantMonth(using: proxy)
                    }
                }

                if let selectedActivity {
                    selectedDaySummary(selectedActivity)
                } else if !hasActivity {
                    Text("暂无 XP 记录")
                        .font(.caption)
                        .foregroundStyle(LivingOSTheme.graphite)
                } else {
                    Text("轻点日期查看当天记录")
                        .font(.caption)
                        .foregroundStyle(LivingOSTheme.graphite)
                }

                intensityLegend
            }
        }
    }

    @ViewBuilder private var liveHeader: some View {
        if YouAdaptiveLayout.mode(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize) == .stacked {
            VStack(alignment: .leading, spacing: 8) {
                liveTitle
                yearNavigation
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                liveTitle
                Spacer()
                yearNavigation
            }
        }
    }

    private var liveTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("LIVE 表").font(.title2.weight(.bold))
            Text("每日经验越多，颜色越深")
                .font(.caption)
                .foregroundStyle(LivingOSTheme.graphite)
        }
    }

    private var yearNavigation: some View {
        HStack(spacing: 2) {
            Button {
                selectedYear = years[max(0, selectedYearIndex - 1)]
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 44)
            }
            .disabled(selectedYearIndex == 0)
            .accessibilityLabel("上一年")

            Text(String(selectedYear))
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .frame(minWidth: 44)

            Button {
                selectedYear = years[min(years.count - 1, selectedYearIndex + 1)]
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 44)
            }
            .disabled(selectedYearIndex >= years.count - 1)
            .accessibilityLabel("下一年")
        }
        .foregroundStyle(LivingOSTheme.ink)
    }

    private var yearGrid: some View {
        let cell: CGFloat = dynamicTypeSize.isAccessibilitySize ? 13 : 11
        let gap: CGFloat = 3
        let pitch = cell + gap
        return ZStack(alignment: .topLeading) {
            ForEach(monthStarts, id: \.month) { marker in
                Text("\(marker.month)月")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(LivingOSTheme.graphite)
                    .position(x: CGFloat(marker.column) * pitch + 10, y: 7)
                    .id(marker.month)
            }

            ForEach(layout.cells) { cellModel in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(for: cellModel.activity.intensity))
                    .overlay {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(
                                calendar.isDate(cellModel.activity.date, inSameDayAs: now)
                                    ? LivingOSTheme.signal
                                    : LivingOSTheme.mist.opacity(0.9),
                                lineWidth: calendar.isDate(cellModel.activity.date, inSameDayAs: now) ? 1 : 0.5
                            )
                    }
                    .frame(width: cell, height: cell)
                    .position(
                        x: CGFloat(cellModel.column) * pitch + cell / 2,
                        y: CGFloat(cellModel.row) * pitch + cell / 2 + 23
                    )
                    .opacity(cellModel.activity.isFuture ? 0.48 : 1)
                    .onTapGesture { selectedActivity = cellModel.activity }
                    .accessibilityHidden(true)
            }
        }
        .frame(
            width: max(1, CGFloat(layout.weekCount)) * pitch,
            height: 23 + 7 * pitch
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LIVE 表，\(selectedYear) 年")
        .accessibilityValue(accessibleActivityValue)
        .accessibilityAdjustableAction { direction in
            adjustAccessibleDay(direction)
        }
    }

    private var monthStarts: [(month: Int, column: Int)] {
        (1...12).compactMap { month in
            guard let cell = layout.cells.first(where: {
                calendar.component(.month, from: $0.activity.date) == month
            }) else { return nil }
            return (month, cell.column)
        }
    }

    private var accessibleActivityValue: String {
        let fallback = days.first(where: { calendar.isDate($0.date, inSameDayAs: now) })
            ?? days.first
        guard let activity = selectedActivity ?? fallback else { return "暂无日期" }
        return YouActivityAccessibility.value(
            activity: activity,
            isToday: calendar.isDate(activity.date, inSameDayAs: now),
            calendar: calendar
        )
    }

    private func adjustAccessibleDay(_ direction: AccessibilityAdjustmentDirection) {
        guard !days.isEmpty else { return }
        let fallbackIndex = days.firstIndex(where: {
            calendar.isDate($0.date, inSameDayAs: now)
        }) ?? 0
        let currentIndex = selectedActivity.flatMap { current in
            days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: current.date) })
        } ?? fallbackIndex
        let nextIndex: Int
        switch direction {
        case .increment: nextIndex = min(days.count - 1, currentIndex + 1)
        case .decrement: nextIndex = max(0, currentIndex - 1)
        @unknown default: nextIndex = currentIndex
        }
        selectedActivity = days[nextIndex]
    }

    private func selectedDaySummary(_ activity: YouDailyActivity) -> some View {
        HStack {
            Text(activity.date, format: .dateTime.year().month().day())
            Spacer()
            if activity.isFuture {
                Text("未来日期")
            } else {
                Text("\(activity.xp) XP · \(activity.completedCount) 项完成")
            }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(LivingOSTheme.graphite)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(YouActivityAccessibility.value(
            activity: activity,
            isToday: calendar.isDate(activity.date, inSameDayAs: now),
            calendar: calendar
        ))
    }

    private var intensityLegend: some View {
        HStack(spacing: 8) {
            Text("0")
            ForEach(YouXPIntensity.allCases, id: \.rawValue) { intensity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color(for: intensity))
                    .overlay {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(LivingOSTheme.mist, lineWidth: 0.5)
                    }
                    .frame(width: 12, height: 12)
                    .accessibilityLabel(intensity.accessibilityName)
            }
            Text("300+ XP")
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(LivingOSTheme.graphite)
    }

    private func color(for intensity: YouXPIntensity) -> Color {
        switch intensity {
        case .empty: .white
        case .light: Color(white: 0.82)
        case .medium: Color(white: 0.56)
        case .dark: Color(white: 0.20)
        case .black: .black
        }
    }

    private func scrollToRelevantMonth(using proxy: ScrollViewProxy) {
        let currentYear = calendar.component(.year, from: now)
        let month = selectedYear == currentYear ? calendar.component(.month, from: now) : 1
        DispatchQueue.main.async {
            proxy.scrollTo(month, anchor: selectedYear == currentYear ? .center : .leading)
        }
    }
}

struct YouXPTrendView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var period: YouXPTrendPeriod = .week
    @State private var anchor: Date
    @State private var selectedDate: Date?

    let completions: [Completion]
    let now: Date
    let calendar: Calendar

    init(completions: [Completion], now: Date, calendar: Calendar) {
        self.completions = completions
        self.now = now
        self.calendar = calendar
        _anchor = State(initialValue: now)
    }

    private var series: YouXPTrendSeries {
        YouActivityHistoryBuilder.trend(
            completions: completions,
            period: period,
            anchor: anchor,
            now: now,
            calendar: calendar
        )
    }

    private var selectedPoint: YouXPTrendPoint? {
        guard let selectedDate else { return nil }
        return series.points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    private var trendAxis: YouXPTrendAxis? {
        YouXPTrendAxis(series: series)
    }

    private var xAxisLabelAnchor: UnitPoint {
        UnitPoint(x: trendAxis?.labelAnchorX ?? 0.5, y: 0)
    }

    var body: some View {
        YouSurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                trendHeader

                Picker("趋势周期", selection: $period) {
                    Text("周").tag(YouXPTrendPeriod.week)
                    Text("月").tag(YouXPTrendPeriod.month)
                    Text("年").tag(YouXPTrendPeriod.year)
                }
                .pickerStyle(.segmented)
                .onChange(of: period) { _, _ in
                    anchor = now
                    selectedDate = nil
                }

                periodTitle
                    .font(.subheadline.weight(.medium))

                if let selectedPoint {
                    HStack {
                        Text(pointTitle(selectedPoint))
                        Spacer()
                        Text("\(selectedPoint.xp) XP")
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(LivingOSTheme.graphite)
                }

                Chart {
                    RuleMark(y: .value("基线", 0))
                        .foregroundStyle(LivingOSTheme.mist)

                    ForEach(series.points) { point in
                        LineMark(
                            x: .value("日期", point.date),
                            y: .value("XP", point.xp)
                        )
                        .foregroundStyle(LivingOSTheme.ink)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                        PointMark(
                            x: .value("日期", point.date),
                            y: .value("XP", point.xp)
                        )
                        .foregroundStyle(LivingOSTheme.ink)
                        .symbolSize(selectedPoint?.id == point.id ? 42 : 14)
                    }

                    if let selectedPoint {
                        RuleMark(x: .value("已选择", selectedPoint.date))
                            .foregroundStyle(LivingOSTheme.signal.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .chartYScale(domain: 0...series.yMaximum)
                .chartXScale(domain: trendAxis?.domain ?? anchor...anchor.addingTimeInterval(86_400))
                .chartXAxis { chartXAxis }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, series.yMaximum / 2, series.yMaximum])
                }
                .chartXSelection(value: $selectedDate)
                .frame(height: 190)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: period)
                .accessibilityLabel("XP 趋势图")
                .accessibilityValue("本周期共 \(series.totalXP) XP，纵轴上限 \(series.yMaximum) XP")

                if series.totalXP == 0 {
                    Text("暂无 XP 记录")
                        .font(.caption)
                        .foregroundStyle(LivingOSTheme.graphite)
                }
            }
        }
    }

    @ViewBuilder private var trendHeader: some View {
        if YouAdaptiveLayout.mode(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize) == .stacked {
            VStack(alignment: .leading, spacing: 8) {
                trendTitle
                periodNavigation
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                trendTitle
                Spacer()
                periodNavigation
            }
        }
    }

    private var trendTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("XP 趋势").font(.title2.weight(.bold))
            Text("本周期 \(series.totalXP) XP")
                .font(.caption.monospacedDigit())
                .foregroundStyle(LivingOSTheme.graphite)
        }
    }

    private var periodNavigation: some View {
        HStack(spacing: 2) {
            Button { movePeriod(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 44)
            }
            .accessibilityLabel("上一周期")
            Button { movePeriod(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 44)
            }
            .disabled(!YouXPTrendNavigation.canMoveForward(
                period: period,
                anchor: anchor,
                now: now,
                calendar: calendar
            ))
            .accessibilityLabel("下一周期")
        }
        .foregroundStyle(LivingOSTheme.ink)
    }

    @ViewBuilder private var periodTitle: some View {
        switch period {
        case .week:
            Text(series.interval.start, format: .dateTime.month().day())
                + Text(" – ")
                + Text(calendar.date(byAdding: .day, value: 6, to: series.interval.start) ?? series.interval.start, format: .dateTime.month().day())
        case .month:
            Text(series.interval.start, format: .dateTime.year().month())
        case .year:
            Text(series.interval.start, format: .dateTime.year())
        }
    }

    @AxisContentBuilder private var chartXAxis: some AxisContent {
        switch period {
        case .week:
            AxisMarks(values: trendAxis?.values ?? []) { value in
                AxisGridLine().foregroundStyle(LivingOSTheme.mist.opacity(0.5))
                AxisValueLabel(
                    centered: trendAxis?.centersLabelsBetweenValues ?? false,
                    anchor: xAxisLabelAnchor
                ) {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.weekday(.narrow))
                    }
                }
            }
        case .month:
            AxisMarks(values: trendAxis?.labelValues ?? []) { value in
                AxisGridLine().foregroundStyle(LivingOSTheme.mist.opacity(0.5))
                AxisValueLabel(
                    centered: trendAxis?.centersLabelsBetweenValues ?? false,
                    anchor: xAxisLabelAnchor
                ) {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.day())
                    }
                }
            }
        case .year:
            AxisMarks(values: trendAxis?.values ?? []) { value in
                AxisGridLine().foregroundStyle(LivingOSTheme.mist.opacity(0.5))
                AxisValueLabel(
                    centered: trendAxis?.centersLabelsBetweenValues ?? false,
                    anchor: xAxisLabelAnchor
                ) {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.narrow))
                    }
                }
            }
        }
    }

    private func pointTitle(_ point: YouXPTrendPoint) -> String {
        if period == .year {
            return point.date.formatted(.dateTime.year().month())
        }
        return point.date.formatted(.dateTime.month().day().weekday(.abbreviated))
    }

    private func movePeriod(by value: Int) {
        if let date = calendar.date(byAdding: period.calendarComponent, value: value, to: anchor) {
            anchor = date
            selectedDate = nil
        }
    }
}

struct YouSurfaceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(LivingOSTheme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(LivingOSTheme.mist.opacity(0.8), lineWidth: 0.5)
            }
    }
}
