#!/usr/bin/env bash
#
# Builds a Namida AppImage from a `flutter build linux --release` bundle.
#
# Usage:
#   scripts/make_appimage.sh <bundle_dir> <output.AppImage>
#   e.g. scripts/make_appimage.sh build/linux/x64/release/bundle build_final/Namida-x86_64-6.4.2-beta.AppImage
#
# Environment (all optional):
#   APPIMAGE_UPDATE_INFO  appimagetool update string, e.g.
#                         "gh-releases-zsync|namidaco|namida-snapshots|latest|Namida-*-x86_64.AppImage.zsync"
#                         (also produces <output>.zsync next to the AppImage)
#   APPIMAGETOOL          path to an appimagetool binary (downloaded automatically when unset)
#   ARCH                  x86_64 (default) | aarch64
#
# Layout of the resulting AppDir:
#   /AppRun, /com.msob7y.namida.desktop, /com.msob7y.namida.png, /.DirIcon
#   /namida, /lib, /data, /bin, /share    <- the flutter bundle, copied verbatim to the AppDir root so that
#                                            $APPDIR/bin/{ffmpeg,ffprobe,audiowaveform} matches
#                                            NamidaPlatformBuilder.getExecutablesDirectoryPath()
#   /usr/lib                              <- libmpv.so.2 + its transitive deps that are not "system" libs
#   /usr/share/{icons,metainfo}
#
# Deliberately NOT bundled: GTK3, glibc, libstdc++, mesa/GL, X11/xcb, wayland, ALSA/JACK/PipeWire
# (see the AppImage excludelist) - the host provides them, exactly like the .tar.gz build does.
# The bundle should therefore be built on the OLDEST glibc you want to support (CI uses ubuntu-24.04).

set -euo pipefail

BUNDLE_DIR="${1:?usage: $0 <bundle_dir> <output.AppImage>}"
OUT_FILE="${2:?usage: $0 <bundle_dir> <output.AppImage>}"

APP_ID="com.msob7y.namida"
ARCH_NAME="${ARCH:-x86_64}"
EXCLUDELIST_URL="https://raw.githubusercontent.com/AppImageCommunity/pkg2appimage/master/excludelist"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINUX_DIR="$REPO_ROOT/linux"

if [ ! -x "$BUNDLE_DIR/namida" ]; then
  echo "error: '$BUNDLE_DIR/namida' not found - run 'flutter build linux --release' first" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
APPDIR="$WORK_DIR/Namida.AppDir"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "==> Creating AppDir"
mkdir -p "$APPDIR"
cp -a "$BUNDLE_DIR"/. "$APPDIR"/

# ---------------------------------------------------------------------------
# AppRun, desktop entry, icons, metainfo
# ---------------------------------------------------------------------------
cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export APPDIR="${APPDIR:-$HERE}"
export LD_LIBRARY_PATH="$HERE/lib:$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$HERE/namida" "$@"
EOF
chmod +x "$APPDIR/AppRun"

# TryExec is dropped: integration tools resolve it against $PATH, which the AppImage is not on.
sed -e "s|^Icon=.*|Icon=$APP_ID|" \
    -e "s|^Exec=.*|Exec=namida %F|" \
    -e "/^TryExec=/d" \
    "$LINUX_DIR/namida.desktop" > "$APPDIR/$APP_ID.desktop"

cp "$LINUX_DIR/icons/namida_512.png" "$APPDIR/$APP_ID.png"
ln -sf "$APP_ID.png" "$APPDIR/.DirIcon"
for size in 128 256 512; do
  install -Dm644 "$LINUX_DIR/icons/namida_$size.png" \
    "$APPDIR/usr/share/icons/hicolor/${size}x${size}/apps/$APP_ID.png"
done
install -Dm644 "$LINUX_DIR/packaging/$APP_ID.metainfo.xml" \
  "$APPDIR/usr/share/metainfo/$APP_ID.appdata.xml"

# ---------------------------------------------------------------------------
# libmpv (dlopen'ed by media_kit) + its non-system dependencies -> usr/lib
# ---------------------------------------------------------------------------
echo "==> Bundling libmpv"
LIBMPV="$(ldconfig -p | awk '$1=="libmpv.so.2"{print $NF; exit}')"
if [ -z "$LIBMPV" ]; then
  echo "error: libmpv.so.2 not found on this machine (install libmpv2 / libmpv-dev)" >&2
  exit 1
fi

EXCLUDES="$(curl -fsSL "$EXCLUDELIST_URL" 2>/dev/null | sed 's/#.*//' || true)"
if [ -z "$EXCLUDES" ]; then
  echo "warn: could not fetch $EXCLUDELIST_URL, using built-in fallback list" >&2
  EXCLUDES="ld-linux-x86-64.so.2 libc.so.6 libdl.so.2 libm.so.6 libmvec.so.1 libpthread.so.0 libresolv.so.2
librt.so.1 libutil.so.1 libanl.so.1 libnss_files.so.2 libnss_dns.so.2 libstdc++.so.6 libgcc_s.so.1
libGL.so.1 libEGL.so.1 libGLdispatch.so.0 libGLX.so.0 libOpenGL.so.0 libdrm.so.2 libglapi.so.0 libgbm.so.1
libxcb.so.1 libX11.so.6 libX11-xcb.so.1 libxcb-dri3.so.0 libxcb-dri2.so.0 libwayland-client.so.0
libasound.so.2 libjack.so.0 libpipewire-0.3.so.0 libfontconfig.so.1 libfreetype.so.6 libharfbuzz.so.0
libfribidi.so.0 libcom_err.so.2 libexpat.so.1 libgpg-error.so.0 libICE.so.6 libSM.so.6 libusb-1.0.so.0
libuuid.so.1 libz.so.1 libgmp.so.10"
fi
# one soname per line
EXCLUDES="$(tr -s ' \t' '\n' <<< "$EXCLUDES" | grep -v '^$')"
# libraries the flutter bundle already ships in lib/ must not be duplicated
FLUTTER_LIBS="$(ls "$APPDIR/lib")"

is_excluded() {
  grep -qx -- "$1" <<< "$EXCLUDES" || grep -qx -- "$1" <<< "$FLUTTER_LIBS"
}

mkdir -p "$APPDIR/usr/lib"
cp -L "$LIBMPV" "$APPDIR/usr/lib/libmpv.so.2"
ln -sf libmpv.so.2 "$APPDIR/usr/lib/libmpv.so" # media_kit tries plain libmpv.so first
echo "   bundle libmpv.so.2 ($LIBMPV)"

# ldd prints the full transitive closure, so one pass is enough
ldd "$LIBMPV" | awk '/=> \//{print $1" "$3}' | sort -u | while read -r soname sopath; do
  if is_excluded "$soname"; then
    echo "   skip   $soname"
  else
    cp -L "$sopath" "$APPDIR/usr/lib/$soname"
    echo "   bundle $soname"
  fi
done

# ---------------------------------------------------------------------------
# appimagetool
# ---------------------------------------------------------------------------
if [ -z "${APPIMAGETOOL:-}" ]; then
  APPIMAGETOOL="$WORK_DIR/appimagetool"
  echo "==> Downloading appimagetool ($ARCH_NAME)"
  curl -fsSL -o "$APPIMAGETOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH_NAME}.AppImage"
  chmod +x "$APPIMAGETOOL"
fi

mkdir -p "$(dirname "$OUT_FILE")"
export ARCH="$ARCH_NAME"
export APPIMAGE_EXTRACT_AND_RUN=1 # no FUSE needed (containers / CI)

TOOL_ARGS=(--no-appstream)
if [ -n "${APPIMAGE_UPDATE_INFO:-}" ]; then
  TOOL_ARGS+=(-u "$APPIMAGE_UPDATE_INFO")
fi

echo "==> Building $OUT_FILE"
"$APPIMAGETOOL" "${TOOL_ARGS[@]}" "$APPDIR" "$OUT_FILE"

echo "==> Done"
ls -la "$OUT_FILE"* 2>/dev/null || true
