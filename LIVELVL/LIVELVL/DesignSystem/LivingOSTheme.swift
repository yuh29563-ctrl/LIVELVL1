import SwiftUI

enum LivingOSTheme {
    static let canvas = Color(
        red: 244.0 / 255.0,
        green: 245.0 / 255.0,
        blue: 246.0 / 255.0
    )
    static let surface = Color(
        red: 248.0 / 255.0,
        green: 249.0 / 255.0,
        blue: 250.0 / 255.0
    )
    static let ink = Color(
        red: 11.0 / 255.0,
        green: 12.0 / 255.0,
        blue: 13.0 / 255.0
    )
    static let graphite = Color(
        red: 102.0 / 255.0,
        green: 106.0 / 255.0,
        blue: 112.0 / 255.0
    )
    static let mist = Color(
        red: 217.0 / 255.0,
        green: 220.0 / 255.0,
        blue: 225.0 / 255.0
    )
    static let signal = Color(
        red: 1,
        green: 59.0 / 255.0,
        blue: 48.0 / 255.0
    )
}

nonisolated enum LivingOSTypography {
    static let rewardsHero: Font.TextStyle = .largeTitle
    static let archiveCaptionTitle: Font.TextStyle = .headline
    static let taskTitle: Font.TextStyle = .body
}

enum LivingOSMetrics {
    static let pageHorizontalInset: CGFloat = 24
    static let pageTitleSize: CGFloat = 56
    static let coreCornerRadius: CGFloat = 26
    static let archiveCardCornerRadius: CGFloat = 28
    static let coreWidthFraction: CGFloat = 0.34
    static let minimumCoreWidth: CGFloat = 124
    static let maximumCoreWidth: CGFloat = 180

    static func coreWidth(containerWidth: CGFloat) -> CGFloat {
        min(maximumCoreWidth, max(minimumCoreWidth, containerWidth * coreWidthFraction))
    }
}

enum LifeStateDisplayScale {
    static func percentage(from score: Double) -> Int {
        Int((min(10, max(0, score)) * 10).rounded())
    }
}
