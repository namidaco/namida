# Namida Flatpak

`app.namida.Namida.yml` builds a Flatpak from a prebuilt Flutter bundle. CI
(`build_flatpak` job in `release_beta.yml`) feeds it the tarball from the
`build_linux_portable` job, uploads `Namida-x86_64-<ver>.flatpak` to the release, and the tarball
itself as `Namida-x86_64-<ver>-flatpak-payload.tar.gz`, which is what Flathub builds from.

The manifest is identical here and on Flathub. Only `namida-source.json` differs: here it points
at the local `namida-linux.tar.gz`, on Flathub at the release asset (url + sha256 + `x-checker-data`).

The bundle keeps the `com.msob7y.namida` desktop/metainfo/icon names used by the other linux
packages, the manifest renames them (`rename-*`) and the app takes its id from `FLATPAK_ID` at runtime.

## Install (bundle from a release)

```sh
flatpak install --user Namida-x86_64-<ver>.flatpak
flatpak run app.namida.Namida
```

## Moving data from the old `com.msob7y.namida` flatpak

Close Namida, then:

```sh
mv ~/.var/app/com.msob7y.namida ~/.var/app/app.namida.Namida
mv ~/.var/app/app.namida.Namida/data/com.msob7y.namida ~/.var/app/app.namida.Namida/data/app.namida.Namida
flatpak uninstall --user com.msob7y.namida
```

## Build locally

```sh
# needs: flatpak, flatpak-builder, and the flathub remote configured
cp <namida .linux.tar.gz> linux/packaging/flatpak/namida-linux.tar.gz
flatpak-builder --user --install-deps-from=flathub --force-clean \
  --repo=linux/packaging/flatpak/repo linux/packaging/flatpak/build-dir \
  linux/packaging/flatpak/app.namida.Namida.yml
flatpak build-bundle linux/packaging/flatpak/repo Namida-x86_64.flatpak app.namida.Namida
```

## Why ffmpeg/mpv are compiled in the manifest

A Flatpak cannot depend on host packages: inside the sandbox only the runtime
(`org.freedesktop.Platform`) and what the manifest installs exist, so "use the
system ffmpeg" never resolves there, and the runtime ships neither libmpv nor
the ffmpeg CLI. The custom ffmpeg/ffprobe binaries from `external/ffmpeg_build`
are built against a newer glibc than the runtime, so the manifest compiles
ffmpeg (LGPL config) and links `/app/namida/bin/ffmpeg{,probe}` to it.

## Flathub

Submission prepared in a clone of the flathub fork (`C:\Programming\flathub`, branch
`add-app.namida.Namida` off `new-pr`). Steps:

1. Release, then fill `url` + `sha256` in that clone's `namida-source.json`
   (`sha256sum Namida-x86_64-<ver>-flatpak-payload.tar.gz`), and copy `app.namida.Namida.yml` from here.
2. Push the branch to the fork, open a PR against `flathub/flathub:new-pr` titled `Add app.namida.Namida`,
   with the text below. Answer the review, then comment `bot, build`.
3. After the merge, accept the invite to `flathub/app.namida.Namida` (2FA required, within a week).
4. Verify the app on the Flathub developer portal: the token goes in
   `https://namida.app/.well-known/org.flathub.VerifiedApps.txt`.
5. Updates: the Flathub bot opens a PR on that repo for every new release asset (`x-checker-data`),
   merge the ones worth shipping. Manifest changes are copied there from this folder.

`https://namida.app` must stay reachable, Flathub's linter checks the domain of the app id.

### PR text

> Namida is a music and video player, submitted by its developer.
>
> **License and binaries**: Namida is proprietary (EULA, `LicenseRef-proprietary`). The main repo is
> public but the app depends on closed-source components (`youtipie`, `playlist_manager`,
> `basic_audio_handler`, `namico_login_manager`, `namico_subscription_manager`,
> `flutter_sharing_intent`), so it cannot be built from public sources. The manifest uses the
> official prebuilt release bundle. The EULA (section 3) allows redistribution of unmodified
> official builds through Flathub. libass, libplacebo, ffmpeg and mpv are built from source.
>
> **Permissions**:
> - `--filesystem=host`: music and video libraries live anywhere (other drives, `/mnt`, `/run/media`),
>   indexing is done by walking folders, and the tag editor writes back to the files.
> - `--talk-name=org.freedesktop.Notifications`: notifications (`flutter_local_notifications` talks to
>   the bus directly, not through the portal).
> - `--talk-name=org.freedesktop.ScreenSaver`: keeps the screen awake while playing.
> - `--talk-name=org.kde.StatusNotifierWatcher`: tray icon.
> - `--own-name=org.mpris.MediaPlayer2.namida`: MPRIS media controls.
> - `--system-talk-name=org.freedesktop.NetworkManager`: connectivity detection, without it the app
>   considers itself offline.
> - `--filesystem=xdg-run/pipewire-0:ro`: mpv's PipeWire audio output.
