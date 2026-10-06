#!/usr/bin/env bash
#
# Based on the unofficial AppImage by Samueru-sama / pkgforge-dev, which packaged Namida this way first:
# https://github.com/pkgforge-dev/Namida-AppImage
#
# Builds a Namida AppImage from a `flutter build linux --release` bundle with quick-sharun
# (https://github.com/pkgforge-dev/Anylinux-AppImages). Everything is bundled, including glibc, GTK
# and webkit2gtk, so nothing is taken from the host and the AppImage runs on any distro.
#
# Must run on archlinux with the anylinux tools installed (pkgforge-dev/anylinux-setup-action)
# and `mpv` + `webkit2gtk-4.1` installed from pacman.
#
# Usage:
#   scripts/make_appimage.sh <bundle_dir> <output_dir>
#   e.g. scripts/make_appimage.sh build/linux/x64/release/bundle build_final
#
# Environment (all optional):
#   VERSION   version baked into the file name and metadata, e.g. 6.4.2-beta
#   UPINFO    appimagetool update string, e.g.
#             "gh-releases-zsync|namidaco|namida-snapshots|latest|Namida-x86_64-*.AppImage.zsync"
#             (also produces <output>.zsync next to the AppImage)

set -euo pipefail

BUNDLE_DIR="$(readlink -f "${1:?usage: $0 <bundle_dir> <output_dir>}")"
OUT_DIR="$(readlink -f -m "${2:?usage: $0 <bundle_dir> <output_dir>}")"

APP_ID="com.msob7y.namida"
ARCH_NAME="$(uname -m)"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINUX_DIR="$REPO_ROOT/linux"

if [ ! -x "$BUNDLE_DIR/namida" ]; then
  echo "error: '$BUNDLE_DIR/namida' not found - run 'flutter build linux --release' first" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

# TryExec is dropped: integration tools resolve it against $PATH, which the AppImage is not on
sed -e "s|^Icon=.*|Icon=$APP_ID|" -e "/^TryExec=/d" "$LINUX_DIR/$APP_ID.desktop" > "$WORK_DIR/$APP_ID.desktop"
cp "$LINUX_DIR/icons/namida_512.png" "$WORK_DIR/$APP_ID.png"

export APPDIR="$WORK_DIR/AppDir"
export OUTPATH="$OUT_DIR"
export ARCH="$ARCH_NAME"
export MAIN_BIN="namida"
export DESKTOP="$WORK_DIR/$APP_ID.desktop"
export ICON="$WORK_DIR/$APP_ID.png"
export ADD_HOOKS="self-updater.hook"
if [ -n "${VERSION:-}" ]; then
  export OUTNAME="Namida-$ARCH_NAME-$VERSION.AppImage"
fi

echo "==> Deploying with quick-sharun"
# quick-sharun silently skips binaries without the executable bit
chmod +x "$BUNDLE_DIR/namida" "$BUNDLE_DIR/bin/ffmpeg" "$BUNDLE_DIR/bin/ffprobe"
# ffmpeg/ffprobe are our own builds from external/ffmpeg_build, libmpv and webkit2gtk are
# dlopen'ed at runtime so they are listed explicitly, lib/ carries libapp.so and the plugins
quick-sharun \
  "$BUNDLE_DIR/namida" \
  "$BUNDLE_DIR/bin/ffmpeg" \
  "$BUNDLE_DIR/bin/ffprobe" \
  "$BUNDLE_DIR/lib" \
  /usr/lib/libmpv.so* \
  /usr/lib/libwebkit2gtk-4.1.so*

install -Dm644 "$BUNDLE_DIR/share/metainfo/$APP_ID.metainfo.xml" \
  "$APPDIR/share/metainfo/$APP_ID.appdata.xml"

echo "==> Building AppImage"
quick-sharun --make-appimage

echo "==> Testing AppImage"
quick-sharun --test "$OUT_DIR"/*.AppImage

echo "==> Done"
ls -la "$OUT_DIR"
