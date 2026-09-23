import AppKit
import Carbon.HIToolbox
import CoreMotion
import Observation

@MainActor
@Observable
final class AppModel {
    var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            UserDefaults.standard.set(isEnabled, forKey: "isEnabled")
            isEnabled ? enableProtection() : disableProtection()
        }
    }
    var comfortDegrees: Double {
        didSet { UserDefaults.standard.set(comfortDegrees, forKey: "comfortDegrees") }
    }
    var fullCoverDistanceDegrees: Double {
        didSet { UserDefaults.standard.set(fullCoverDistanceDegrees, forKey: "fullCoverDistanceDegrees") }
    }

    private(set) var displayedPose = HeadPose(angleDegrees: 0, yawDegrees: 0, pitchDegrees: 0)
    private(set) var connectionText = "Protection is off"
    private(set) var shieldEngaged = false
    private(set) var errorText: String?
    private(set) var canCalibrate = false
    private(set) var isCentered = false

    @ObservationIgnored
    private let tracker = HeadphoneMotionTracker()
    @ObservationIgnored
    private let overlay = ShieldOverlay()
    @ObservationIgnored
    private var calculator = HeadPoseCalculator()
    @ObservationIgnored
    private var trigger = ShieldTrigger()
    @ObservationIgnored
    private var latestOrientation: HeadOrientation?
    @ObservationIgnored
    private var smoothedYawDegrees = 0.0
    @ObservationIgnored
    private var smoothedPitchDegrees = 0.0
    @ObservationIgnored
    private var smoothedAngleDegrees = 0.0
    @ObservationIgnored
    private var previousOrientation: HeadOrientation?
    @ObservationIgnored
    private var lastSampleTime = 0.0
    @ObservationIgnored
    private var lastUIUpdateTime = 0.0
    @ObservationIgnored
    private var lastOverlayUpdateTime = 0.0
    @ObservationIgnored
    private var dismissTask: Task<Void, Never>?
    @ObservationIgnored
    private var isSettingUp = false
    @ObservationIgnored
    private var recenterHotKey: RecenterHotKey?

    init() {
        let defaults = UserDefaults.standard
        comfortDegrees = min(35, max(5, defaults.object(forKey: "comfortDegrees") as? Double ?? 15))
        fullCoverDistanceDegrees = min(30, max(5, defaults.object(forKey: "fullCoverDistanceDegrees") as? Double ?? 15))

        tracker.onStatus = { [weak self] status in self?.connectionText = status }
        tracker.onOrientation = { [weak self] orientation in self?.receive(orientation) }
        tracker.onDisconnect = { [weak self] in self?.disconnected() }
        overlay.onDismiss = { [weak self] in self?.dismissShield(requireCenter: true) }
        recenterHotKey = RecenterHotKey { [weak self] in self?.recenter() }

        if defaults.bool(forKey: "isEnabled") { isEnabled = true }
    }

    var angleText: String {
        isCentered ? String(format: "%.1f° from center", displayedPose.angleDegrees) : "Not centered"
    }
    var pitchText: String { String(format: "%+.1f°", displayedPose.pitchDegrees) }
    var statusText: String {
        if shieldEngaged { return "Screen protected" }
        if isEnabled, !isCentered { return "Face the display to center" }
        return connectionText
    }
    var menuStatusText: String { shieldEngaged ? "Privacy shield active" : statusText }
    var statusSymbol: String {
        if shieldEngaged { return "eye.slash.fill" }
        if isEnabled { return "shield.checkered" }
        return "eye.slash"
    }

    func beginSetup() {
        guard !isEnabled else { return }
        isSettingUp = true
        connectionText = "Looking for compatible AirPods…"
        tracker.start()
    }

    func cancelSetup() {
        isSettingUp = false
        guard !isEnabled else { return }
        tracker.stop()
        latestOrientation = nil
        canCalibrate = false
        connectionText = "Protection is off"
    }

    @discardableResult
    func finishSetup() -> Bool {
        guard latestOrientation != nil else {
            errorText = "Wear and connect compatible AirPods before continuing."
            return false
        }
        isSettingUp = false
        isEnabled = true
        recenter()
        return true
    }

    func recenter() {
        guard let latestOrientation else { return }
        calculator.calibrate(latestOrientation)
        isCentered = true
        resetMotionState()
        dismissShield(requireCenter: false)
        connectionText = "AirPods connected"
        errorText = nil
    }

    func clearShield() {
        dismissShield(requireCenter: isEnabled)
    }

    func testShield() {
        guard !shieldEngaged else { return }
        errorText = nil
        shieldEngaged = true
        overlay.show(
            progress: 1,
            pose: HeadPose(angleDegrees: 45, yawDegrees: 24, pitchDegrees: 0)
        )
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.dismissShield(requireCenter: self?.isEnabled == true)
        }
    }

    private func enableProtection() {
        errorText = nil
        trigger.reset()
        tracker.start()
        if latestOrientation == nil {
            connectionText = "Looking for compatible AirPods…"
        } else {
            recenter()
        }
    }

    private func disableProtection() {
        guard !isSettingUp else { return }
        tracker.stop()
        calculator = HeadPoseCalculator()
        latestOrientation = nil
        canCalibrate = false
        isCentered = false
        resetMotionState()
        connectionText = "Protection is off"
        dismissShield(requireCenter: false)
    }

    private func receive(_ orientation: HeadOrientation) {
        guard orientation.yawRadians.isFinite,
              orientation.pitchRadians.isFinite,
              orientation.timestamp >= lastSampleTime
        else { return }

        latestOrientation = orientation
        if !canCalibrate { canCalibrate = true }
        lastSampleTime = orientation.timestamp
        errorText = nil

        guard isEnabled else { return }
        if calculator.center == nil {
            calculator.calibrate(orientation)
            isCentered = true
            resetMotionState()
            connectionText = "AirPods connected"
            return
        }
        guard let rawPose = calculator.pose(for: orientation) else { return }

        if let previousOrientation,
           HeadPoseCalculator.angularDistance(from: previousOrientation, to: orientation) > 45 {
            calculator.calibrate(orientation)
            resetMotionState()
            connectionText = "Sensor reference reset and recentered"
            return
        }
        previousOrientation = orientation

        smoothedYawDegrees = smoothedYawDegrees * 0.78 + rawPose.yawDegrees * 0.22
        smoothedPitchDegrees = smoothedPitchDegrees * 0.78 + rawPose.pitchDegrees * 0.22
        smoothedAngleDegrees = smoothedAngleDegrees * 0.78 + rawPose.angleDegrees * 0.22
        let pose = HeadPose(
            angleDegrees: smoothedAngleDegrees,
            yawDegrees: smoothedYawDegrees,
            pitchDegrees: smoothedPitchDegrees
        )

        if orientation.timestamp - lastUIUpdateTime >= 0.5 {
            displayedPose = pose
            lastUIUpdateTime = orientation.timestamp
        }

        let progress = HeadPoseCalculator.shieldProgress(
            angleDegrees: pose.angleDegrees,
            comfortDegrees: comfortDegrees,
            fullCoverDistanceDegrees: fullCoverDistanceDegrees
        )

        switch trigger.update(
            angleDegrees: pose.angleDegrees,
            timestamp: orientation.timestamp,
            comfortDegrees: comfortDegrees
        ) {
        case .clear:
            if shieldEngaged { dismissShield(requireCenter: false) }
        case .engage:
            engageShield(progress: max(0.28, progress), pose: pose)
        case .hold:
            if shieldEngaged,
               orientation.timestamp - lastOverlayUpdateTime >= 1.0 / 30.0 {
                overlay.update(progress: max(0.28, progress), pose: pose)
                lastOverlayUpdateTime = orientation.timestamp
            }
        }
    }

    private func engageShield(progress: Double, pose: HeadPose) {
        shieldEngaged = true
        overlay.show(progress: progress, pose: pose)
        lastOverlayUpdateTime = lastSampleTime
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.dismissShield(requireCenter: true)
        }
    }

    private func dismissShield(requireCenter: Bool) {
        dismissTask?.cancel()
        dismissTask = nil
        overlay.hide()
        shieldEngaged = false
        if requireCenter { trigger.disarmUntilCentered() }
    }

    private func resetMotionState() {
        displayedPose = HeadPose(angleDegrees: 0, yawDegrees: 0, pitchDegrees: 0)
        smoothedYawDegrees = 0
        smoothedPitchDegrees = 0
        smoothedAngleDegrees = 0
        previousOrientation = nil
        lastUIUpdateTime = 0
        lastOverlayUpdateTime = 0
        trigger.reset()
    }

    private func disconnected() {
        calculator = HeadPoseCalculator()
        latestOrientation = nil
        canCalibrate = false
        isCentered = false
        resetMotionState()
        connectionText = "AirPods disconnected"
        dismissShield(requireCenter: false)
    }
}

@MainActor
final class HeadphoneMotionTracker: NSObject, CMHeadphoneMotionManagerDelegate {
    var onOrientation: ((HeadOrientation) -> Void)?
    var onStatus: ((String) -> Void)?
    var onDisconnect: (() -> Void)?

    private let manager = CMHeadphoneMotionManager()
    private var isRunning = false
    private var lastStatus: String?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        manager.delegate = self
        manager.startConnectionStatusUpdates()

        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .denied:
            report("Motion access denied in System Settings")
        case .restricted:
            report("Motion access is restricted")
        default:
            if manager.isDeviceMotionAvailable {
                startMotionUpdates()
            } else {
                report("Connect AirPods 3/4, Pro, or Max")
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        manager.stopDeviceMotionUpdates()
        manager.stopConnectionStatusUpdates()
        manager.delegate = nil
        lastStatus = nil
    }

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        report("AirPods connected")
        startMotionUpdates()
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        manager.stopDeviceMotionUpdates()
        report("AirPods disconnected")
        onDisconnect?()
    }

    private func startMotionUpdates() {
        guard isRunning, manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        report("AirPods connected")

        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self else { return }
            if let error {
                self.report(error.localizedDescription)
                return
            }
            guard let motion else { return }
            self.onOrientation?(HeadOrientation(
                yawRadians: motion.attitude.yaw,
                pitchRadians: motion.attitude.pitch,
                quaternion: Quaternion(
                    x: motion.attitude.quaternion.x,
                    y: motion.attitude.quaternion.y,
                    z: motion.attitude.quaternion.z,
                    w: motion.attitude.quaternion.w
                ),
                timestamp: motion.timestamp
            ))
        }
    }

    private func report(_ status: String) {
        guard status != lastStatus else { return }
        lastStatus = status
        onStatus?(status)
    }
}

@MainActor
private final class RecenterHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.handle,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        guard handlerStatus == noErr else { return }

        let identifier = EventHotKeyID(signature: OSType(0x47565A4C), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_R),
            UInt32(cmdKey | optionKey | controlKey | shiftKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
    }

    private static let handle: EventHandlerUPP = { _, _, userData in
        guard let userData else { return noErr }
        let hotKey = Unmanaged<RecenterHotKey>.fromOpaque(userData).takeUnretainedValue()
        MainActor.assumeIsolated { hotKey.action() }
        return noErr
    }
}
