import AppKit

@MainActor
final class ShieldOverlay {
    var onDismiss: (() -> Void)?
    private var panels: [ShieldPanel] = []

    var isVisible: Bool { !panels.isEmpty }

    func show(progress: Double, pose: HeadPose, coverExternalDisplays: Bool = true) {
        if panels.isEmpty {
            panels = screens(coverExternalDisplays: coverExternalDisplays).map { screen in
                ShieldPanel(screen: screen) { [weak self] in self?.onDismiss?() }
            }
            panels.forEach { $0.show() }
        }
        update(progress: progress, pose: pose)
    }

    func update(progress: Double, pose: HeadPose) {
        panels.forEach { $0.update(progress: progress, pose: pose) }
    }

    func hide() {
        panels.forEach { $0.close() }
        panels.removeAll()
    }

    private func screens(coverExternalDisplays: Bool) -> [NSScreen] {
        guard !coverExternalDisplays else { return NSScreen.screens }

        let builtInScreens = NSScreen.screens.filter(\.isBuiltIn)
        if !builtInScreens.isEmpty { return builtInScreens }
        return NSScreen.main.map { [$0] } ?? Array(NSScreen.screens.prefix(1))
    }
}

private extension NSScreen {
    var isBuiltIn: Bool {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return false
        }
        return CGDisplayIsBuiltin(CGDirectDisplayID(screenNumber.uint32Value)) != 0
    }
}

@MainActor
private final class ShieldPanel {
    private let window: NSPanel
    private let effectView: NSView
    private let gradient = CAGradientLayer()

    init(screen: NSScreen, onDismiss: @escaping () -> Void) {
        window = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        let rootView = ClickToClearView(frame: NSRect(origin: .zero, size: screen.frame.size))
        rootView.onDismiss = onDismiss

        effectView = NSView(frame: rootView.bounds)
        effectView.autoresizingMask = [.width, .height]
        effectView.wantsLayer = true
        effectView.layer?.mask = gradient

        let strongBlur = NSVisualEffectView(frame: effectView.bounds)
        strongBlur.autoresizingMask = [.width, .height]
        strongBlur.blendingMode = .behindWindow
        strongBlur.material = .fullScreenUI
        strongBlur.state = .active
        effectView.addSubview(strongBlur)

        if #available(macOS 26, *) {
            let glass = NSGlassEffectView(frame: effectView.bounds)
            glass.autoresizingMask = [.width, .height]
            glass.style = .regular
            glass.tintColor = NSColor.white.withAlphaComponent(0.16)
            effectView.addSubview(glass)
        }
        rootView.addSubview(effectView)

        let hint = NSVisualEffectView()
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.blendingMode = .withinWindow
        hint.material = .popover
        hint.state = .active
        hint.wantsLayer = true
        hint.layer?.cornerRadius = 15
        hint.layer?.borderWidth = 1
        hint.layer?.borderColor = NSColor.white.withAlphaComponent(0.23).cgColor
        hint.layer?.shadowColor = NSColor.black.cgColor
        hint.layer?.shadowOpacity = 0.1
        hint.layer?.shadowRadius = 15
        hint.layer?.shadowOffset = CGSize(width: 0, height: -4)

        let label = NSTextField(labelWithString: "GazeVeil  •  Click anywhere to clear")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.alignment = .center
        hint.addSubview(label)
        rootView.addSubview(hint)
        NSLayoutConstraint.activate([
            hint.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            hint.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 28),
            hint.widthAnchor.constraint(equalToConstant: 250),
            hint.heightAnchor.constraint(equalToConstant: 30),
            label.leadingAnchor.constraint(equalTo: hint.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: hint.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: hint.centerYAnchor),
        ])

        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.animationBehavior = .none
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = rootView
        gradient.frame = effectView.bounds
    }

    func show() {
        window.orderFrontRegardless()
    }

    func update(progress: Double, pose: HeadPose) {
        let amount = CGFloat(min(1, max(0, progress)))
        let magnitude = max(0.001, hypot(pose.yawDegrees, pose.pitchDegrees))
        let horizontal = CGFloat(pose.yawDegrees / magnitude)
        let vertical = CGFloat(pose.pitchDegrees / magnitude)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = effectView.bounds
        gradient.startPoint = CGPoint(x: 0.5 - horizontal * 0.5, y: 0.5 - vertical * 0.5)
        gradient.endPoint = CGPoint(x: 0.5 + horizontal * 0.5, y: 0.5 + vertical * 0.5)

        if amount >= 0.99 {
            gradient.colors = [NSColor.white.cgColor, NSColor.white.cgColor]
            gradient.locations = [0, 1]
        } else {
            let edge = min(1, amount * 1.2)
            gradient.colors = [
                NSColor.white.cgColor,
                NSColor.white.cgColor,
                NSColor.clear.cgColor,
            ]
            gradient.locations = [0, NSNumber(value: max(0, edge - 0.24)), NSNumber(value: edge)]
        }
        CATransaction.commit()
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }
}

@MainActor
private final class ClickToClearView: NSView {
    var onDismiss: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        onDismiss?()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
