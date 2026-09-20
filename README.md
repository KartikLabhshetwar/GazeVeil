# GazeVeil

AirPods-aware screen privacy for macOS. Look away in any direction and GazeVeil places a native glass blur over every display; face the screen again to clear it.

## Run

Requirements: macOS 14+, Xcode command-line tools, and head-tracking AirPods for the motion path.

```bash
./build.sh --run
```

The app opens a guided setup window on first launch. Connect and wear AirPods 3/4, AirPods Pro, or AirPods Max, then choose **Center & Start** while facing the display. Use **Recenter** whenever your seating position changes.

The motion sensor is inside supported AirPods, not the MacBook. AirPods 1 and 2 cannot provide head-motion data. The Mac connects to the earbuds over Bluetooth and Core Motion exposes their orientation through `CMHeadphoneMotionManager`.

If motion is denied, enable **GazeVeil** in **System Settings → Privacy & Security → Motion & Fitness**. The AirPods must be worn, connected, and selected as the Mac's audio output.

The eye icon remains in the menu bar for quick start/stop, recentering, blur preview, and reopening the controls.

## How it works

- Quaternion-relative motion detects left, right, up, and down without Euler-angle wraparound errors.
- A short debounce and hysteresis prevent sensor jitter from flashing the overlay.
- The overlay uses macOS `NSVisualEffectView`. GazeVeil does not use the camera, take screenshots, save motion history, or connect to a server.
- The shield clears when you face the screen, click it, or after an eight-second failsafe.
- The menu bar item uses the standard native macOS menu.

## Development

```bash
swift test
swift build -c release
```

The project has no third-party dependencies or bundled assets. Liquid Glass is used on macOS 26, with a native material fallback on macOS 14 and later.

## License

GazeVeil is licensed under the GNU Affero General Public License v3.0. See `LICENSE`.
