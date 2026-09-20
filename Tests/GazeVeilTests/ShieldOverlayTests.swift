import Testing
@testable import GazeVeil

@MainActor
@Test func `shield overlay can be shown and dismissed`() {
    let overlay = ShieldOverlay()
    overlay.show(
        progress: 1,
        pose: HeadPose(angleDegrees: 30, yawDegrees: 30, pitchDegrees: 0)
    )
    #expect(overlay.isVisible)

    overlay.hide()
    #expect(!overlay.isVisible)
}
