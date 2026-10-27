import CoreGraphics
import Testing
@testable import LIVELVL

@MainActor
struct RadarGeometryTests {
    @Test func zeroStateMapsToTheCenterWithoutAnInventedMinimum() {
        let center = CGPoint(x: 50, y: 50)
        let points = RadarGeometry.points(values: LifeStateValues(repeating: 0),
            center: center, radius: 40)
        #expect(points.allSatisfy { $0 == center })
    }
    @Test func sixFullValuesProduceARealHexagonStartingAtTop() {
        let points = RadarGeometry.points(
            values: LifeStateValues(repeating: 10.0),
            center: CGPoint(x: 100, y: 100),
            radius: 80
        )
        #expect(points.count == 6)
        #expect(abs(points[0].x - 100) < 0.001)
        #expect(abs(points[0].y - 20) < 0.001)
        #expect(abs(points[3].x - 100) < 0.001)
        #expect(abs(points[3].y - 180) < 0.001)
    }

    @Test func scoreIsClampedBeforeConvertingToRadius() {
        let values = LifeStateValues(
            health: 12, learning: 10, career: 10,
            finance: 10, relationships: 10, interests: 10
        )
        let points = RadarGeometry.points(
            values: values, center: CGPoint(x: 50, y: 50), radius: 40
        )
        #expect(abs(points[0].y - 10) < 0.001)
    }
}
