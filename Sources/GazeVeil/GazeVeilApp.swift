import AppKit
import SwiftUI

@main
struct GazeVeilApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("GazeVeil", id: "settings") {
            RootView(model: model)
        }
        .defaultSize(width: 600, height: 620)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            Text(model.menuStatusText)

            Divider()

            Toggle("Protection", isOn: $model.isEnabled)
            Button("Recenter") { model.recenter() }
                .disabled(!model.canCalibrate)
            if model.shieldEngaged {
                Button("Clear Privacy Shield") { model.clearShield() }
            }

            Divider()

            Button("Test Privacy Shield") { model.testShield() }
                .disabled(model.shieldEngaged)
            OpenSettingsButton()

            Divider()

            Button("Quit GazeVeil") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        } label: {
            MenuBarIcon()
        }
    }
}

private struct MenuBarIcon: View {
    private static let image = Bundle.main.url(forResource: "GazeVeil", withExtension: "icns")
        .flatMap(NSImage.init(contentsOf:))
        ?? NSApp.applicationIconImage
        ?? NSImage(size: NSSize(width: 18, height: 18))

    var body: some View {
        Image(nsImage: Self.image)
            .resizable()
            .interpolation(.high)
            .renderingMode(.original)
            .frame(width: 18, height: 18)
            .accessibilityLabel("GazeVeil")
    }
}

private struct OpenSettingsButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
    }
}
