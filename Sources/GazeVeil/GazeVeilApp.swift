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
            Image(systemName: model.statusSymbol)
                .accessibilityLabel("GazeVeil")
        }
        .menuBarExtraStyle(.menu)
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
