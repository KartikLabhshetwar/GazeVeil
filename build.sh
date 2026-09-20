#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h}
app_dir="$repo_root/build/GazeVeil.app"
release_version=${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$repo_root/App/Info.plist")}
build_number=${BUILD_NUMBER:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$repo_root/App/Info.plist")}
target_arch=${ARCH:-$(uname -m)}

if [[ ! $release_version =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    printf 'VERSION must use SemVer, for example 0.1.0\n' >&2
    exit 2
fi

if [[ ! $build_number =~ '^[1-9][0-9]*$' ]]; then
    printf 'BUILD_NUMBER must be a positive integer\n' >&2
    exit 2
fi

if [[ $target_arch != arm64 && $target_arch != x86_64 ]]; then
    printf 'ARCH must be arm64 or x86_64\n' >&2
    exit 2
fi

cd "$repo_root"
swift build -c release --arch "$target_arch"
binary_dir=$(swift build -c release --arch "$target_arch" --show-bin-path)

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS"
mkdir -p "$app_dir/Contents/Resources"
cp "$binary_dir/GazeVeil" "$app_dir/Contents/MacOS/GazeVeil"
strip -x "$app_dir/Contents/MacOS/GazeVeil"
cp App/Info.plist "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $release_version" "$app_dir/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$app_dir/Contents/Info.plist"
cp App/GazeVeil.icns "$app_dir/Contents/Resources/GazeVeil.icns"
codesign --force --sign - "$app_dir" >/dev/null

printf 'Built %s version %s (%s) for %s\n' "$app_dir" "$release_version" "$build_number" "$target_arch"

if [[ ${1:-} == "--run" ]]; then
    open "$app_dir"
fi
