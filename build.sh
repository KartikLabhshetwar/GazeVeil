#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h}
app_dir="$repo_root/build/GazeVeil.app"

cd "$repo_root"
swift build -c release

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS"
mkdir -p "$app_dir/Contents/Resources"
cp .build/release/GazeVeil "$app_dir/Contents/MacOS/GazeVeil"
strip -x "$app_dir/Contents/MacOS/GazeVeil"
cp App/Info.plist "$app_dir/Contents/Info.plist"
cp App/GazeVeil.icns "$app_dir/Contents/Resources/GazeVeil.icns"
codesign --force --sign - "$app_dir" >/dev/null

printf 'Built %s\n' "$app_dir"

if [[ ${1:-} == "--run" ]]; then
    open "$app_dir"
fi
