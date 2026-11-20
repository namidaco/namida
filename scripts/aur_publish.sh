#!/bin/bash

# Publishes a linux tarball to AUR from linux/packaging/aur/PKGBUILD.in: stable to namida-bin, betas to namida-beta-bin.
# Usage: aur_publish.sh <pubspec version> <tarball>, e.g. aur_publish.sh 8.6.5-beta+261114224 build_final/namida-v8.6.5-beta.linux.tar.gz

set -e

VERSION="$1"
TARBALL="$2"

if [ -z "$VERSION" ] || [ ! -f "$TARBALL" ]; then
  echo "Usage: $0 <pubspec version> <tarball>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../linux/packaging/aur/PKGBUILD.in"
TARBALL="$(realpath "$TARBALL")"

PKGVER="${VERSION%%[-+]*}"
BUILDNUMBER="${VERSION##*+}"

# -- single quotes keep ${pkgver} & ${_buildnumber} for makepkg
if [[ "$VERSION" == *-beta* ]]; then
  PKGNAME="namida-beta-bin"
  URL="https://github.com/namidaco/namida-snapshots"
  SOURCE='namida-v${pkgver}-beta.linux.tar.gz::https://github.com/namidaco/namida-snapshots/releases/download/${pkgver}-beta%2B${_buildnumber}/namida-v${pkgver}-beta.linux.tar.gz'
else
  PKGNAME="namida-bin"
  URL="https://github.com/namidaco/namida"
  SOURCE='namida-v${pkgver}.linux.tar.gz::https://github.com/namidaco/namida/releases/download/v${pkgver}/namida-v${pkgver}.linux.tar.gz'
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
git clone "ssh://aur@aur.archlinux.org/${PKGNAME}.git" "$WORK_DIR/$PKGNAME"
cd "$WORK_DIR/$PKGNAME"

PKGREL=1
if [ -f PKGBUILD ]; then
  CURRENT_VER=$(grep "^pkgver=" PKGBUILD | cut -d'=' -f2)
  CURRENT_REL=$(grep "^pkgrel=" PKGBUILD | cut -d'=' -f2)
  # -- pacman doesnt compare the build number, same pkgver needs a higher pkgrel
  if [ "$CURRENT_VER" = "$PKGVER" ]; then
    PKGREL=$((CURRENT_REL + 1))
  fi
fi

SHA256=$(sha256sum "$TARBALL" | awk '{print $1}')

sed \
  -e "s|@PKGNAME@|${PKGNAME}|" \
  -e "s|@PKGVER@|${PKGVER}|" \
  -e "s|@BUILDNUMBER@|${BUILDNUMBER}|" \
  -e "s|@PKGREL@|${PKGREL}|" \
  -e "s|@URL@|${URL}|" \
  -e "s|@SOURCE@|${SOURCE}|" \
  -e "s|@SHA256@|${SHA256}|" \
  "$TEMPLATE" > PKGBUILD
makepkg --printsrcinfo > .SRCINFO

# -- old per-repo bump script, the template lives in the namida repo now
git rm -q --ignore-unmatch bump.sh
git add PKGBUILD .SRCINFO
git commit -m "update to v${PKGVER} (build ${BUILDNUMBER})"
git push origin HEAD:master

echo "Published ${PKGNAME} v${PKGVER} (build ${BUILDNUMBER}, pkgrel ${PKGREL})"
