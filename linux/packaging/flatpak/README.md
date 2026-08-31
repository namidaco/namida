# Namida Flatpak

`com.msob7y.namida.yml` builds a Flatpak from a prebuilt Flutter bundle. CI
(`build_flatpak` job in `release_beta.yml`) feeds it the tarball from the
`build_linux_portable` job and uploads `Namida-x86_64-<ver>.flatpak` to the release.

## Install (bundle from a release)

```sh
flatpak install --user Namida-x86_64-<ver>.flatpak
flatpak run com.msob7y.namida
```

## Build locally

```sh
# needs: flatpak, flatpak-builder, and the flathub remote configured
cp <namida .linux.tar.gz> linux/packaging/flatpak/namida-linux.tar.gz
flatpak-builder --user --install-deps-from=flathub --force-clean \
  --repo=linux/packaging/flatpak/repo linux/packaging/flatpak/build-dir \
  linux/packaging/flatpak/com.msob7y.namida.yml
flatpak build-bundle linux/packaging/flatpak/repo Namida-x86_64.flatpak com.msob7y.namida
```

## Why ffmpeg/mpv are compiled in the manifest

A Flatpak cannot depend on host packages: inside the sandbox only the runtime
(`org.freedesktop.Platform`) and what the manifest installs exist, so "use the
system ffmpeg" never resolves there, and the runtime ships neither libmpv nor
the ffmpeg CLI. The custom ffmpeg/ffprobe binaries from `external/ffmpeg_build`
are built against a newer glibc than the runtime, so the manifest compiles
ffmpeg (LGPL config) and links `/app/namida/bin/ffmpeg{,probe}` to it;
`audiowaveform` from the tarball is kept (it only needs libc/libstdc++).

## Flathub notes (not submitted yet)

- The app id `com.msob7y.namida` implies control of the domain `msob7y.com`.
  Flathub's verification (and increasingly submission review) expects an id
  rooted in a domain you control; for GitHub-hosted projects the convention is
  `io.github.namidaco.namida`. Shipping the `.flatpak` bundle in releases has
  no such requirement — this only matters if/when submitting to Flathub.
- Flathub requires building from source for open-source apps; prebuilt binaries
  are the accepted path for proprietary/EULA apps (which Namida's license is),
  submitted by the upstream developer. The `path:` source must then become a
  versioned release `url:` + `sha256:`.
- Submission = PR adding the manifest to github.com/flathub/flathub (branch
  `new-pr`); after acceptance the manifest lives in its own flathub/<app-id> repo.
