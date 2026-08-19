import Foundation

enum LifeDimension: String, CaseIterable, Codable, Identifiable, Sendable {
    case health, learning, career, finance, relationships, interests

    var id: String { rawValue }

    var title: String {
        switch self {
        case .health: "健康"
        case .learning: "学习"
        case .career: "事业"
        case .finance: "财务"
        case .relationships: "关系"
        case .interests: "兴趣"
        }
    }
}
