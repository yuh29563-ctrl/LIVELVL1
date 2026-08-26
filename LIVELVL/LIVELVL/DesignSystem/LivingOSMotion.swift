import Foundation

struct LivingOSMotionProfile: Equatable, Sendable {
    let allowsParticles: Bool
    let allowsDepthTilt: Bool
    let stateFadeDuration: TimeInterval
    let snapDuration: TimeInterval

    static func resolved(reduceMotion: Bool) -> Self {
        if reduceMotion {
            return Self(
                allowsParticles: false,
                allowsDepthTilt: false,
                stateFadeDuration: 0.2,
                snapDuration: 0.2
            )
        }

        return Self(
            allowsParticles: true,
            allowsDepthTilt: true,
            stateFadeDuration: 0.2,
            snapDuration: 0.34
        )
    }
}
