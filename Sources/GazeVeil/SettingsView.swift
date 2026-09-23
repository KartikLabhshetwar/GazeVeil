import AppKit
import SwiftUI

struct RootView: View {
    @Bindable var model: AppModel
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false

    var body: some View {
        Group {
            if didCompleteOnboarding {
                SettingsView(model: model) {
                    model.isEnabled = false
                    didCompleteOnboarding = false
                }
            } else {
                OnboardingView(model: model) {
                    didCompleteOnboarding = true
                }
            }
        }
        .frame(width: 600, height: 620)
        .background(.background)
    }
}

private struct OnboardingView: View {
    @Bindable var model: AppModel
    let finish: () -> Void
    @State private var page = 0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if page == 0 {
                welcome
            } else {
                connect
            }
        }
        .padding(36)
        .onDisappear {
            if page == 1, !model.isEnabled { model.cancelSetup() }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer(minLength: 8)

            AppIcon(size: 64)

            VStack(alignment: .leading, spacing: 10) {
                Text("Privacy follows your attention.")
                    .font(.largeTitle.bold())
                Text("GazeVeil uses the motion sensors already inside your AirPods. Look away in any direction and the display blurs; face it again and the blur clears.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 13) {
                Text("Enable the live glass effect")
                    .font(.headline)

                Label("Open System Settings", systemImage: "1.circle.fill")
                Label("Select Accessibility", systemImage: "2.circle.fill")
                Label("Open Display and turn off Reduce transparency", systemImage: "3.circle.fill")

                Divider()

                Label(
                    reduceTransparency
                        ? "Reduce Transparency is on — turn it off before continuing."
                        : "Ready — Reduce Transparency is off.",
                    systemImage: reduceTransparency ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                )
                .foregroundStyle(reduceTransparency ? Color.orange : Color.green)

                Text("Keep this setting off while using GazeVeil. macOS otherwise replaces live glass with an opaque surface.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .gazeGlass(tint: .accentColor.opacity(0.1))
            .accessibilityElement(children: .contain)

            Spacer()

            HStack {
                Text("Requires AirPods 3/4, AirPods Pro, or AirPods Max")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Continue") {
                    page = 1
                    model.beginSetup()
                }
                .prominentGlassButton()
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var connect: some View {
        VStack(alignment: .leading, spacing: 26) {
            Button("Back", systemImage: "chevron.left") {
                model.cancelSetup()
                page = 0
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text("Connect, face the display, then center")
                    .font(.largeTitle.bold())
                Text("Wear your AirPods and select them as the Mac’s audio output. GazeVeil will use your current pose as straight ahead.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 18) {
                Image(systemName: model.canCalibrate ? "airpodspro.chargingcase.wireless.fill" : "airpodspro")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(model.canCalibrate ? Color.green : Color.secondary)
                    .frame(width: 54)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.canCalibrate ? "AirPods ready" : "Waiting for AirPods")
                        .font(.title2.bold())
                    Text(connectionDetail)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !model.canCalibrate { ProgressView().controlSize(.small) }
            }
            .padding(24)
            .gazeGlass(tint: model.canCalibrate ? .green.opacity(0.08) : nil)
            .accessibilityElement(children: .combine)

            if !model.canCalibrate {
                Text("If they are connected but still waiting, put both AirPods in your ears and keep your head still for a moment.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = model.errorText {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            HStack {
                Text("Motion data stays on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Center & Start") {
                    if model.finishSetup() { finish() }
                }
                .prominentGlassButton()
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canCalibrate)
            }
        }
    }

    private var connectionDetail: String {
        if model.canCalibrate { return "Motion sensor ready" }
        if model.connectionText == "AirPods connected" {
            return "Connected — waiting for the motion sensor"
        }
        return model.connectionText
    }
}

private struct SettingsView: View {
    @Bindable var model: AppModel
    let runSetupAgain: () -> Void
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 18) {
                AppIcon(size: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text("GazeVeil")
                        .font(.title.bold())
                    Text(model.statusText)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("Protection", isOn: $model.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityLabel("Privacy protection")
                    .help("Turn AirPods head tracking on or off")
            }
            .padding(24)
            .gazeGlass(tint: model.isEnabled ? .accentColor.opacity(0.1) : nil)
            .accessibilityElement(children: .contain)

            if reduceTransparency {
                Label(
                    "Turn off Reduce Transparency in System Settings → Accessibility → Display to see the live glass blur.",
                    systemImage: "circle.lefthalf.filled"
                )
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }

            Form {
                Section("Live status") {
                    LabeledContent("AirPods", value: model.connectionText)
                    LabeledContent("Movement", value: model.angleText)
                    LabeledContent("Vertical angle", value: model.pitchText)
                }

                Section("Sensitivity") {
                    LabeledContent("Blur begins", value: "\(Int(model.comfortDegrees))°")
                    Slider(value: $model.comfortDegrees, in: 5...35, step: 1)
                        .accessibilityLabel("Blur begins angle")
                        .help("How far you can turn in any direction before the screen starts to blur")

                    LabeledContent("Full cover distance", value: "+\(Int(model.fullCoverDistanceDegrees))°")
                    Slider(value: $model.fullCoverDistanceDegrees, in: 5...30, step: 1)
                        .accessibilityLabel("Full cover distance")
                        .help("Additional movement in any direction required for full coverage")
                }

                Section("Recenter shortcut") {
                    Picker("Key", selection: $model.recenterShortcutKey) {
                        ForEach(RecenterShortcutKey.allCases) { key in
                            Text(key.title).tag(key)
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle("Command", isOn: $model.recenterShortcutUsesCommand)
                    Toggle("Option", isOn: $model.recenterShortcutUsesOption)
                    Toggle("Control", isOn: $model.recenterShortcutUsesControl)
                    Toggle("Shift", isOn: $model.recenterShortcutUsesShift)

                    Text("Use this shortcut anywhere in macOS. At least one modifier is required.")
                        .foregroundStyle(.secondary)
                    if let error = model.recenterShortcutError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Privacy") {
                    Text("GazeVeil reads processed orientation from Core Motion and renders a system material locally. It does not use the camera, capture the screen, save motion history, or connect to a server.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            HStack {
                Button("Recenter") { model.recenter() }
                    .disabled(!model.canCalibrate)
                Button("Test Privacy Shield") { model.testShield() }
                    .disabled(model.shieldEngaged)
                if model.shieldEngaged {
                    Button("Clear") { model.clearShield() }
                }
                Spacer()
                Button("Run onboarding again", action: runSetupAgain)
                    .buttonStyle(.link)
            }

            Text("Looking left, right, up, or down activates the shield.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(26)
    }
}

private struct AppIcon: View {
    let size: CGFloat

    private static let image = Bundle.main.url(forResource: "GazeVeil", withExtension: "icns")
        .flatMap(NSImage.init(contentsOf:))
        ?? NSApp.applicationIconImage
        ?? NSImage(size: NSSize(width: 64, height: 64))

    var body: some View {
        Image(nsImage: Self.image)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private extension View {
    @ViewBuilder
    func gazeGlass(tint: Color? = nil) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular.tint(tint), in: .rect(cornerRadius: 24))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.separator.opacity(0.45), lineWidth: 0.5)
                }
        }
    }

    @ViewBuilder
    func prominentGlassButton() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glassProminent)
                .controlSize(.large)
        } else {
            buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}
