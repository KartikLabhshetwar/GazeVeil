import Testing
@testable import GazeVeil

@MainActor
@Test(arguments: [true, false])
func `shield overlay can be shown and dismissed`(coverExternalDisplays: Bool) {
    let overlay = ShieldOverlay()
    overlay.show(
        progress: 1,
        pose: HeadPose(angleDegrees: 30, yawDegrees: 30, pitchDegrees: 0),
        coverExternalDisplays: coverExternalDisplays
    )
    #expect(overlay.isVisible)

    overlay.hide()
    #expect(!overlay.isVisible)
}
