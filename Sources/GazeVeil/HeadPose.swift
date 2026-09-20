import Foundation

struct HeadOrientation: Equatable, Sendable {
    let yawRadians: Double
    let pitchRadians: Double
    let quaternion: Quaternion
    let timestamp: TimeInterval

    init(yawRadians: Double, pitchRadians: Double, timestamp: TimeInterval = 0) {
        self.yawRadians = yawRadians
        self.pitchRadians = pitchRadians
        quaternion = .init(yawRadians: yawRadians, pitchRadians: pitchRadians)
        self.timestamp = timestamp
    }

    init(
        yawRadians: Double,
        pitchRadians: Double,
        quaternion: Quaternion,
        timestamp: TimeInterval
    ) {
        self.yawRadians = yawRadians
        self.pitchRadians = pitchRadians
        self.quaternion = quaternion.normalized
        self.timestamp = timestamp
    }
}

struct Quaternion: Equatable, Sendable {
    let x: Double
    let y: Double
    let z: Double
    let w: Double

    init(x: Double, y: Double, z: Double, w: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    init(yawRadians: Double, pitchRadians: Double) {
        let yaw = yawRadians / 2
        let pitch = pitchRadians / 2
        x = -sin(pitch) * sin(yaw)
        y = sin(pitch) * cos(yaw)
        z = cos(pitch) * sin(yaw)
        w = cos(pitch) * cos(yaw)
    }

    var normalized: Self {
        let length = sqrt(x * x + y * y + z * z + w * w)
        guard length > 0 else { return .init(x: 0, y: 0, z: 0, w: 1) }
        return .init(x: x / length, y: y / length, z: z / length, w: w / length)
    }
}

struct HeadPose: Equatable, Sendable {
    let angleDegrees: Double
    let yawDegrees: Double
    let pitchDegrees: Double
}

struct HeadPoseCalculator {
    private(set) var center: HeadOrientation?

    mutating func calibrate(_ orientation: HeadOrientation) {
        center = orientation
    }

    func pose(for orientation: HeadOrientation) -> HeadPose? {
        guard let center else { return nil }

        let yaw = Self.shortestAngle(from: center.yawRadians, to: orientation.yawRadians)
        let pitch = Self.shortestAngle(from: center.pitchRadians, to: orientation.pitchRadians)
        let yawDegrees = yaw * 180 / .pi
        let pitchDegrees = pitch * 180 / .pi

        return HeadPose(
            angleDegrees: Self.angularDistance(from: center, to: orientation),
            yawDegrees: yawDegrees,
            pitchDegrees: pitchDegrees
        )
    }

    static func angularDistance(from start: HeadOrientation, to end: HeadOrientation) -> Double {
        let a = start.quaternion.normalized
        let b = end.quaternion.normalized
        let dot = abs(a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w)
        return 2 * acos(min(1, max(-1, dot))) * 180 / .pi
    }

    private static func shortestAngle(from start: Double, to end: Double) -> Double {
        atan2(sin(end - start), cos(end - start))
    }

    static func shieldProgress(
        angleDegrees: Double,
        comfortDegrees: Double,
        fullCoverDistanceDegrees: Double
    ) -> Double {
        min(1, max(0, (angleDegrees - comfortDegrees) / fullCoverDistanceDegrees))
    }
}

enum ShieldSignal: Equatable {
    case clear
    case hold
    case engage
}

struct ShieldTrigger {
    private var crossedAt: TimeInterval?
    private var isArmed = true

    mutating func update(
        angleDegrees: Double,
        timestamp: TimeInterval,
        comfortDegrees: Double
    ) -> ShieldSignal {
        if angleDegrees <= max(0, comfortDegrees - 1.5) {
            crossedAt = nil
            isArmed = true
            return .clear
        }
        if angleDegrees <= comfortDegrees {
            crossedAt = nil
            return .hold
        }
        guard isArmed else { return .hold }
        guard let crossedAt else {
            self.crossedAt = timestamp
            return .hold
        }
        guard timestamp - crossedAt >= 0.12 else { return .hold }
        isArmed = false
        return .engage
    }

    mutating func disarmUntilCentered() {
        crossedAt = nil
        isArmed = false
    }

    mutating func reset() {
        crossedAt = nil
        isArmed = true
    }
}
