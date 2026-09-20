# GazeVeil

AirPods-aware screen privacy for macOS. Look away from your display and GazeVeil covers it with a native glass blur; face the display again to clear it.

<p align="center">
  <a href="https://github.com/KartikLabhshetwar/GazeVeil/releases/download/v0.1.0/GazeVeil-0.1.0-macOS-arm64.zip">⬇️ Download for Apple Silicon</a>
  &nbsp;&nbsp;•&nbsp;&nbsp;
  <a href="https://github.com/KartikLabhshetwar/GazeVeil/releases/download/v0.1.0/GazeVeil-0.1.0-macOS-x86_64.zip">⬇️ Download for Intel Mac</a>
</p>

GazeVeil is signed with a Developer ID certificate and notarized by Apple. It requires macOS 14 or later.

## Install

1. Download the correct ZIP for your Mac.
2. Open the ZIP and drag **GazeVeil.app** into **Applications**.
3. Open GazeVeil and follow the onboarding instructions.
4. Wear compatible AirPods, select them as the Mac's audio output, then choose **Center & Start** while facing the display.

Choose **Apple Silicon** for Macs with an M-series chip. Choose **Intel Mac** for older Intel-based Macs.

## Requirements

- macOS 14 or later
- AirPods 3 or 4, AirPods Pro, or AirPods Max
- **Reduce transparency** turned off under **System Settings → Accessibility → Display**

If motion access is denied, enable GazeVeil under **System Settings → Privacy & Security → Motion & Fitness**.

## Using GazeVeil

The eye icon in the menu bar provides controls to start or stop protection, recenter head tracking, test the privacy shield, and reopen settings. Use **Recenter** whenever your seating position changes.

The shield clears when you face the display, click anywhere on it, or after an eight-second failsafe. This keeps the app dismissible even if motion sensing stalls.

## Privacy

GazeVeil reads processed orientation data from the motion sensors inside compatible AirPods. It does not:

- use the camera;
- capture or record the screen;
- save motion history; or
- connect to a server.

All behavior runs locally on the Mac.

## How it works

- Quaternion-relative motion detects left, right, up, and down without angle wraparound errors.
- Debounce and hysteresis prevent sensor jitter from flashing the shield.
- macOS 26 uses public `NSGlassEffectView` APIs over a full-screen system material.
- macOS 14 and 15 use the native `NSVisualEffectView` fallback.
- Multiple displays are protected independently.

## Build from source

Requirements: Xcode command-line tools and Swift 6.2 or later.

```bash
make test
make local
make run
```

The project is native Swift and has no third-party runtime dependencies.

## Release process

Versions follow Semantic Versioning. The current release is `0.1.0`, bundle build `1`.

```bash
make credentials APPLE_ID=you@example.com  # first release only
make release-all
```

For the next patch release:

```bash
make set-version VERSION=0.1.1 BUILD_NUMBER=2
make release-all
```

See [CHANGELOG.md](CHANGELOG.md) for release history.

## License

GazeVeil is licensed under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE).
