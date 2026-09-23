import Carbon.HIToolbox
import Testing
@testable import GazeVeil

@Suite("Head pose math")
struct HeadPoseTests {
    @Test("Recenter shortcut maps letters to virtual key codes")
    func recenterShortcutKeyCode() {
        #expect(RecenterShortcutKey.r.keyCode == UInt32(kVK_ANSI_R))
        #expect(RecenterShortcutKey.z.keyCode == UInt32(kVK_ANSI_Z))
    }

    @Test("Identity is centered")
    func identityIsCentered() throws {
        var calculator = HeadPoseCalculator()
        calculator.calibrate(HeadOrientation(yawRadians: 0, pitchRadians: 0))

        let pose = try #require(calculator.pose(for: HeadOrientation(yawRadians: 0, pitchRadians: 0)))
        #expect(abs(pose.angleDegrees) < 0.001)
    }

    @Test("Yaw crosses the configured threshold")
    func yawThreshold() throws {
        var calculator = HeadPoseCalculator()
        calculator.calibrate(HeadOrientation(yawRadians: 0, pitchRadians: 0))

        let pose = try #require(calculator.pose(for: HeadOrientation(
            yawRadians: 24 * .pi / 180,
            pitchRadians: 0
        )))
        #expect(abs(pose.angleDegrees - 24) < 0.001)
        let progress = HeadPoseCalculator.shieldProgress(
            angleDegrees: pose.angleDegrees,
            comfortDegrees: 15,
            fullCoverDistanceDegrees: 18
        )
        #expect(abs(progress - 0.5) < 0.001)
    }

    @Test("Yaw stays continuous across the plus-minus pi boundary")
    func yawWraparound() throws {
        var calculator = HeadPoseCalculator()
        calculator.calibrate(HeadOrientation(yawRadians: 179 * .pi / 180, pitchRadians: 0))

        let pose = try #require(calculator.pose(for: HeadOrientation(
            yawRadians: -179 * .pi / 180,
            pitchRadians: 0
        )))
        #expect(abs(pose.angleDegrees - 2) < 0.001)
    }

    @Test("Looking up or down triggers the privacy shield")
    func pitchTriggers() throws {
        var calculator = HeadPoseCalculator()
        calculator.calibrate(HeadOrientation(yawRadians: 0, pitchRadians: 0))

        let pose = try #require(calculator.pose(for: HeadOrientation(
            yawRadians: 0,
            pitchRadians: 35 * .pi / 180
        )))
        #expect(abs(pose.angleDegrees - 35) < 0.001)
        #expect(abs(pose.pitchDegrees - 35) < 0.001)
    }

    @Test("Shield requires sustained yaw and a centered reset")
    func shieldTriggerDebouncesAndRearms() {
        var trigger = ShieldTrigger()

        #expect(trigger.update(angleDegrees: 16, timestamp: 0, comfortDegrees: 15) == .hold)
        #expect(trigger.update(angleDegrees: 14, timestamp: 0.08, comfortDegrees: 15) == .hold)
        #expect(trigger.update(angleDegrees: 16, timestamp: 0.12, comfortDegrees: 15) == .hold)
        #expect(trigger.update(angleDegrees: 16, timestamp: 0.25, comfortDegrees: 15) == .engage)
        #expect(trigger.update(angleDegrees: 20, timestamp: 0.4, comfortDegrees: 15) == .hold)
        #expect(trigger.update(angleDegrees: 13, timestamp: 0.5, comfortDegrees: 15) == .clear)
        #expect(trigger.update(angleDegrees: 16, timestamp: 0.6, comfortDegrees: 15) == .hold)
        #expect(trigger.update(angleDegrees: 16, timestamp: 0.73, comfortDegrees: 15) == .engage)
    }

    @Test("Progress clamps")
    func progressClamps() {
        #expect(HeadPoseCalculator.shieldProgress(
            angleDegrees: 5,
            comfortDegrees: 15,
            fullCoverDistanceDegrees: 18
        ) == 0)
        #expect(HeadPoseCalculator.shieldProgress(
            angleDegrees: 40,
            comfortDegrees: 15,
            fullCoverDistanceDegrees: 18
        ) == 1)
    }
}
