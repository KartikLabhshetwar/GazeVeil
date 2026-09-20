#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h}
app_dir="$repo_root/build/GazeVeil.app"
release_version=${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$repo_root/App/Info.plist")}
build_number=${BUILD_NUMBER:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$repo_root/App/Info.plist")}

if [[ ! $release_version =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    printf 'VERSION must use SemVer, for example 0.1.0\n' >&2
    exit 2
fi

if [[ ! $build_number =~ '^[1-9][0-9]*$' ]]; then
    printf 'BUILD_NUMBER must be a positive integer\n' >&2
    exit 2
fi

cd "$repo_root"
swift build -c release

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS"
mkdir -p "$app_dir/Contents/Resources"
cp .build/release/GazeVeil "$app_dir/Contents/MacOS/GazeVeil"
strip -x "$app_dir/Contents/MacOS/GazeVeil"
cp App/Info.plist "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $release_version" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$app_dir/Contents/Info.plist"
cp App/GazeVeil.icns "$app_dir/Contents/Resources/GazeVeil.icns"
codesign --force --sign - "$app_dir" >/dev/null

printf 'Built %s version %s (%s)\n' "$app_dir" "$release_version" "$build_number"

if [[ ${1:-} == "--run" ]]; then
    open "$app_dir"
fi
