<link rel="stylesheet" href="styles.css" />

# <div style="margin-right: 18px; margin-top: 18px; display:flex; vertical-align: middle; align-items: center; max-width: 100%;"><img src="assets/namida_icon.png" width="82" style="margin-right: 18px;">Namida</div>

A Beautiful and Feature-rich Music & Video Player with YouTube Support, Built in Flutter

<a href="https://namida.app">![](https://img.shields.io/badge/-Website-%23463e35)
</a>
<a href="https://docs.namida.app">![](https://img.shields.io/badge/-Docs-%23f1d6b6)
</a>
<a href="https://t.me/namida_official">![](https://img.shields.io/badge/Channel-blue?link=https%3A%2F%2Ft.me%2Fnamida_officialt&logo=telegram&logoColor=white)
</a>
<a href="https://t.me/+FmdfsgKoGmM1ZGFk">![](https://img.shields.io/badge/Chat-blue?link=https%3A%2F%2Ft.me%2F%2BFmdfsgKoGmM1ZGFk&logo=telegram&logoColor=white)
</a>
<a href="https://discord.gg/WeY7DTVChT">![](https://img.shields.io/discord/1156253663803740271?label=Discord&logo=discord&logoColor=white&color=7B55C1)
</a>
<a href="#installation">![](https://img.shields.io/badge/Platforms-Android_%7C_Windows_%7C_Linux_%7C_macOS_%7C_iOS-slateblue)
</a><br>
<a href="https://github.com/namidaco/namida/releases/latest">![](https://img.shields.io/github/v/release/namidaco/namida?label=Stable)
</a>
<a href="https://github.com/namidaco/namida-snapshots/releases/latest">![](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fnamidaco.github.io%2Fnamida-snapshots%2Faltstore-source.json&query=%24.apps%5B0%5D.versions%5B0%5D.version&label=Beta&prefix=v&color=f5a623)
</a>
<a href="https://github.com/namidaco/namida/commits/main">![](https://img.shields.io/github/commits-since/namidaco/namida/latest?label=Commits%20since%20stable)
</a>
<a href="https://github.com/namidaco/namida/commits/main">![](https://img.shields.io/github/last-commit/namidaco/namida?label=Last%20commit)
</a>
<a href="https://aur.archlinux.org/packages/namida-bin">![](https://img.shields.io/aur/version/namida-bin?logo=archlinux&label=AUR)
</a>
<a href="https://github.com/microsoft/winget-pkgs/tree/master/manifests/n/namidaco/Namida">![](https://img.shields.io/winget/v/namidaco.Namida?label=winget)
</a><br>
<a href="https://github.com/namidaco/namida/stargazers">![](https://img.shields.io/github/stars/namidaco/namida?style=flat&logo=github&label=Stars)
</a>
<a href="https://github.com/namidaco/namida/releases">![](https://img.shields.io/github/downloads/namidaco/namida/total?label=Downloads)
</a>
<a href="https://github.com/namidaco/namida-snapshots/releases">![](https://img.shields.io/github/downloads/namidaco/namida-snapshots/total?label=Beta%20downloads)
</a>
<a href="https://github.com/namidaco/namida/issues?q=is%3Aissue+is%3Aclosed">![](https://img.shields.io/github/issues-closed/namidaco/namida?label=Issues)
</a>
<a href="https://hitsofcode.com/github/namidaco/namida/view?branch=main">![](https://hitsofcode.com/github/namidaco/namida?branch=main)
</a>
<a href="https://github.com/flutter/flutter">![](https://img.shields.io/badge/Built%20in-Flutter-%23369FE7)
</a>

Don't forget to 🌟 star the repo if you like the project ^^

# Intro

New to Namida? Take the [tour](https://docs.namida.app/tour/) for a quick look at the main features. Everything else is in the [docs](https://docs.namida.app)

<a href="#installation"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/installation_dark.svg"><img src="./some%20stuff/summaries/installation_light.svg" width="159" align="absmiddle" alt="Download"></picture></a>
<a href="https://docs.namida.app/tour/"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/docs_tour_dark.svg"><img src="./some%20stuff/summaries/docs_tour_light.svg" width="121" align="absmiddle" alt="Take the tour"></picture></a>
<a href="https://docs.namida.app/#quickstart"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/docs_quickstart_dark.svg"><img src="./some%20stuff/summaries/docs_quickstart_light.svg" width="163" align="absmiddle" alt="Quickstart"></picture></a>
<a href="https://docs.namida.app/screens/"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/docs_screens_dark.svg"><img src="./some%20stuff/summaries/docs_screens_light.svg" width="178" align="absmiddle" alt="Screens map"></picture></a>

# Sections

- [Features](#-features)
  - [Library \& Indexing](#library--indexing)
  - [Look \& Feel](#look--feel)
  - [Sound](#sound)
  - [Streaming & YouTube](#streaming--youtube)
  - [Video Integration](#video-integration)
  - [System Integration](#system-integration)
  - [Others](#others)
  - [Some additional cool features](#some-additional-cool-features)
- [Screenshots](#screenshots)
  - [Usage Preview](#usage-preview)
- [Installation](#installation)
  - [Android Permissions](#permission-note)
- [Translate & Contribute](#translate--contribute)
- [Community](#community)
  - [Companion Apps](#companion-apps)
- [Donate](#donate)
- [Special Thanks](#special-thanks)
- [LICENSE](#license)

# 🎉 Features

Everything you might expect from a music player, in addition to the following:

<a name="library--indexing"></a>
<details open>
<summary><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/library_indexing_dark.svg"><img src="./some%20stuff/summaries/library_indexing_light.svg" width="435" align="absmiddle" alt="Library &amp; Indexing"></picture></summary>

- Powerful Indexer & Tag Editor, powered by `taglib`.
- Artists & Genres Separators.
- Prevent Duplicated Tracks, Minimum File Size & Duration.
- Folders-based Library, with excluded folders.
- Sort by almost any track or album property.

</details>

<a name="look--feel"></a>
<details open>
<summary><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/look_feel_dark.svg"><img src="./some%20stuff/summaries/look_feel_light.svg" width="435" align="absmiddle" alt="Look &amp; Feel"></picture></summary>

- Material3-like Theme with Dynamic Colors from the current artwork.
- Home, Tracks, Albums, Artists, Genres, Playlists, Folders & Queues Pages, plus cool ones like Most Played, Moods, Tags, Ratings, Languages, Stats & more.
- Waveform Seekbar & Widescreen Player Layout.
- Visualizers, Animated Backgrounds & Custom Wallpapers. <sub><code>new</code></sub>
- Lots of customizations (check out [customization section](#customization-settings)).

</details>

<a name="sound"></a>
<details open>
<summary><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/sound_dark.svg"><img src="./some%20stuff/summaries/sound_light.svg" width="435" align="absmiddle" alt="Sound"></picture></summary>

- Parametric Equalizer with AutoEQ import. <sub><code>new</code></sub>
- Bit-perfect Playback, USB DAC Direct Access, Exclusive Mode (desktop) & 32-bit float audio. <sub><code>new</code></sub>
- Audio Path, see every step from the file to your device. <sub><code>new</code></sub>
- Output Device Selection & Mono Audio. <sub><code>new</code></sub>
- Sound Effects like Bass Enhancer, Reverb, Virtual Surround, 8D Audio & Vocal Remover (Android). <sub><code>new</code></sub>
- Smart Crossfade with Beat Matching <sub><code>new</code></sub>, Gapless Playback, Play/Pause Fade & Skip Silence.
- Speed & Pitch Control (semitones & 432Hz) & Loudness Enhancer.
- Per-track Speed, Pitch, Volume & Equalizer, and Sound Presets to switch them all at once. <sub><code>new</code></sub>
- Replay Gain support (Normalize loudness between tracks)

</details>

<a name="streaming--youtube"></a>
<details open>
<summary><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/streaming_youtube_dark.svg"><img src="./some%20stuff/summaries/streaming_youtube_light.svg" width="435" align="absmiddle" alt="Streaming &amp; YouTube"></picture></summary>

- Best Video & Audio Quality, Audio Only & Data Saver Mode.
- Sign in with Multiple Profiles, get your Feed, Subscriptions, Playlists & Notifications.
- Multi Library (Local/YT/Subsonic/Jellyfin/WebDAV/SMB) & Offline Caching for Servers. <sub><code>new</code></sub>
- Video View with [gestures](https://docs.namida.app/features/youtube/#video-view) for volume, brightness, seeking, fullscreen, speed up & more.
- SponsorBlock, Return YouTube Dislike, Segments & Heatmap.
- Subtitles & Captions.
- Downloads, Caching & Offline Playback, with a Cache Priority System.
- Split Downloads by Chapters & Remove Sponsor Segments. <sub><code>new</code></sub>
- Downloads Tags config & Filename builder (similar to yt-dlp).
- Auto title/artist/album extraction from video titles, for downloads & scrobbling.

<a href="https://docs.namida.app/features/youtube/#filename-formats"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/yt_formats_dark.svg"><img src="./some%20stuff/summaries/yt_formats_light.svg" width="239" align="absmiddle" alt="Available formats &amp; example"></picture></a>

</details>

<a name="video-integration"></a>
<details open>
<summary><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/video_integration_dark.svg"><img src="./some%20stuff/summaries/video_integration_light.svg" width="435" align="absmiddle" alt="Video Integration"></picture></summary>

- For Local Library, Namida is capable of playing videos related to the music, Video can be found either locally or fetched from youtube

<a href="https://docs.namida.app/guides/medium/#link-local-video"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/video_local_dark.svg"><img src="./some%20stuff/summaries/video_local_light.svg" width="149" align="absmiddle" alt="How locally?"></picture></a>
<a href="https://docs.namida.app/guides/medium/#link-yt-video"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/video_youtube_dark.svg"><img src="./some%20stuff/summaries/video_youtube_light.svg" width="158" align="absmiddle" alt="How youtube?"></picture></a>

- Since v4.0.0, full video library indexing & playback is supported, videos can now be played independently, as well as dedicated videos folder view.

</details>

<a name="system-integration"></a>
<details open>
<summary><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/system_integration_dark.svg"><img src="./some%20stuff/summaries/system_integration_light.svg" width="435" align="absmiddle" alt="System Integration"></picture></summary>

- Home Screen Widget & Quick Settings Tiles.
- Android Auto & Wear OS. <sub><code>new</code></sub>
- Status Bar Lyrics. <sub><code>new</code></sub>
- Desktop: System Tray, Keyboard Shortcuts, System Wide Hotkeys & Floating Lyrics Window.
- Now Playing Broadcasts & Webhook for Tasker, scripts & scrobblers. <sub><code>new</code></sub>

</details>

<a name="others"></a>
<details open>
<summary><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/others_dark.svg"><img src="./some%20stuff/summaries/others_light.svg" width="435" align="absmiddle" alt="Others"></picture></summary>

- Lyrics fetching & displaying (Synced, Plain & Word Synced lrc/ttml), and an Editor to sync them yourself. <sub><code>new</code></sub>
- Smart Playlists with flexible rules, usable in search too.
- Listening Party, listen to the same queue with friends in sync, online or on the same network. <sub><code>new</code></sub>
- Sync app data between your devices over local network (history, playlists, favourites, queues, lyrics, etc). <sub><code>new</code></sub>
- Bookmarks & Chapters for tracks and videos. <sub><code>new</code></sub>
- Stats Charts & Your Year Page.
- Search by title, artist, album, filename, lyrics & more, even with typos.
- Persistent Queues, your sessions are saved for later.
- Flexible History (editable, importable) with minimum seconds/percentage to count a listen.
- Most Played, your top tracks in any time range.
- Custom Playlists Order & Artworks, Auto Import from M3U files & Music Servers.
- Global Tracks Selection, select from multiple places into the same list.
- Swipe Actions for tracks & videos, Artwork Gestures (tap & long press).
- Folder images (`cover.jpg` etc) & `.info.txt` for small info.
- Sleep Timer (Tracks or Minutes) & Pausing Scenarios (calls, notifications, volume 0, etc).

</details>

<a name="some-additional-cool-features"></a>
<details open>
<summary><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/cool_features_dark.svg"><img src="./some%20stuff/summaries/cool_features_light.svg" width="435" align="absmiddle" alt="Some additional cool features"></picture></summary>

- Smort Tracks Generation: uuh.. with dis advanced algorithm brought for you, generate tracks u often listened to alongside the current one. also by release date, time range, ratings, moods, or randomly.
- Lost Memories: meet tracks you listened to around this time, but n years ago.
- Animating Thumbnail & Particles, moving with the audio peak.
- Miniplayer Party Mode, edge breathing effect with static or artwork colors.
- Track Play Mode, when playing from search: selected track only, search results, album, first artist or first genre.
- Insert after latest inserted, want to insert multiple tracks one after each other? this will get your back.
- Repeat for N times, in addition to normal repeat modes (all, none, one), this one lets you repeat the track for number of times before playing the next track.
- Extract feat. & ft. artists, u won't miss the featured artists in the title, they'll have their own entry inside artists tab.
- <p>CAN IMPORT YOUTUBE HISTORY & DATA <img src="some stuff/ong.png" width=16 height=16/></p>
- <p>LASTFM, SPOTIFY & LISTENBRAINZ TOO AND MAYBE MORE IN FUTURE <img src="some stuff/yoowhat.gif" width=16 height=16/></p>
- decent amount of options/customizations in settings & dialogs, make sure to check them out ^^

</details>

# Screenshots

<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/collection_light_1.webp" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/collection_light_2.webp" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/collection_light_3.webp" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/collection_light_4.webp" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/collection_dark_1.webp" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/collection_dark_2.webp" class="imgbr"/>

<a name="customization-settings"></a>
<details>
<summary><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/customization_dark.svg"><img src="./some%20stuff/summaries/customization_light.svg" width="435" align="absmiddle" alt="Customization Settings"></picture></summary>
    <img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_customization.webp" class="imgbr" width="50%">
</details>

<details>
<summary><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/all_settings_dark.svg"><img src="./some%20stuff/summaries/all_settings_light.svg" width="435" align="absmiddle" alt="All Settings"></picture></summary>

<table>
  <tr><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings.webp" class="imgbr"/></td><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_theme.webp" class="imgbr"/></td><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_indexer.webp" class="imgbr"/></td></tr>
  <tr><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_playback.webp" class="imgbr"/></td><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_youtube.webp" class="imgbr"/></td><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_extras.webp" class="imgbr"/></td></tr>
  <tr><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_backup.webp" class="imgbr"/></td><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_advanced.webp" class="imgbr"/></td></tr>
</table>

</details>

<details>
<summary><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/yt_miniplayer_dark.svg"><img src="./some%20stuff/summaries/yt_miniplayer_light.svg" width="435" align="absmiddle" alt="YouTube Miniplayer"></picture></summary>
    <img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/manual/yt_miniplayer.jpg" class="imgbr" width="50%">
</details>

<details>
<summary><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/screenshots_2023_dark.svg"><img src="./some%20stuff/summaries/screenshots_2023_light.svg" width="435" align="absmiddle" alt="2023 Screenshots"></picture></summary>

<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots_2023/collection_light_1.jpg" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots_2023/collection_light_2.jpg" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots_2023/collection_dark_1.jpg" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots_2023/collection_dark_2.jpg" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots_2023/customization_settings.jpg" class="imgbr" width="50%">
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots_2023/yt_miniplayer.png" class="imgbr" width="50%">

</details>

<details open>
<summary><a name="usage-preview"></a><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/usage_preview_dark.svg"><img src="./some%20stuff/summaries/usage_preview_light.svg" width="435" align="absmiddle" alt="Usage Preview"></picture></summary>

| Animating Thumbnail | Recommends & Listens |
| --- | --- |
| <video src="https://github.com/namidaco/namida/assets/85245079/da47c270-9f45-4ff5-a08e-e99e4b7ebb7c.mp4"> | <video src="https://github.com/namidaco/namida/assets/85245079/72e978b3-6e15-4b4e-948a-03b470802b30.mp4"> |

</details>

# Installation

<div align="center">

<table>

<tr>
  <th><div align="center">Platform</div></th>
  <th><div align="center">Stable</div></th>
  <th><div align="center">Beta</div></th>
  <th><div align="center">Guide</div></th>
</tr>

<tr>
<td align="center"><b>Android</b></td>
<td align="center" width="200">
  <div style="display:flex; flex-direction:column; align-items:center;">
    <a href="https://github.com/namidaco/namida/releases/latest"><img src="./some stuff/badge_github.png" height="50"></a>
    <a href="https://apps.obtainium.imranr.dev/redirect?r=obtainium://add/https://github.com/namidaco/namida/"><img src="./some stuff/badge_obtainium.png" height="50" style="margin-top:8px;"></a>
  </div>
</td>
<td align="center" width="200">
  <div style="display:flex; flex-direction:column; align-items:center;">
    <a href="https://github.com/namidaco/namida-snapshots/releases/latest"><img src="./some stuff/badge_github_beta.png" height="50"></a>
    <a href="https://apps.obtainium.imranr.dev/redirect?r=obtainium://add/https://github.com/namidaco/namida-snapshots/"><img src="./some stuff/badge_obtainium_beta.png" height="50" style="margin-top:8px;"></a>
  </div>
</td>
<td align="center"><a href="https://docs.namida.app/installation/#android-install"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/install_guide_dark.svg"><img src="./some%20stuff/summaries/install_guide_light.svg" width="150" align="absmiddle" alt="Install guide"></picture></a></td>
</tr>

<tr>
<td align="center"><b>Windows</b></td>
<td align="center" width="200">
  <div style="display:flex; flex-direction:column; align-items:center;">
    <a href="https://github.com/namidaco/namida/releases/latest"><img src="./some stuff/badge_github.png" height="50"></a>
    <a href="https://github.com/microsoft/winget-pkgs/tree/master/manifests/n/namidaco/Namida"><img src="./some%20stuff/summaries/pm_winget.svg" height="50" alt="winget"></a>
  </div>
</td>
<td align="center" width="200">
  <div style="display:flex; flex-direction:column; align-items:center;">
    <a href="https://github.com/namidaco/namida-snapshots/releases/latest"><img src="./some stuff/badge_github_beta.png" height="50"></a>
  </div>
</td>
<td align="center"><a href="https://docs.namida.app/installation/#windows-install"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/install_guide_dark.svg"><img src="./some%20stuff/summaries/install_guide_light.svg" width="150" align="absmiddle" alt="Install guide"></picture></a></td>
</tr>

<tr>
<td align="center"><b>Linux</b> <sub><code>new</code></sub></td>
<td align="center"><i>Soon</i></td>
<td align="center" width="200">
  <div style="display:flex; flex-direction:column; align-items:center;">
    <a href="https://github.com/namidaco/namida-snapshots/releases/latest"><img src="./some stuff/badge_github_beta.png" height="50"></a>
    <a href="https://aur.archlinux.org/packages/namida-bin"><img src="./some%20stuff/summaries/pm_aur.svg" height="50" alt="AUR"></a>
  </div>
</td>
<td align="center"><a href="https://docs.namida.app/installation/#linux-install"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/install_guide_dark.svg"><img src="./some%20stuff/summaries/install_guide_light.svg" width="150" align="absmiddle" alt="Install guide"></picture></a></td>
</tr>

<tr>
<td align="center"><b>macOS</b> <sub><code>new</code></sub></td>
<td align="center"><i>Soon</i></td>
<td align="center" width="200">
  <div style="display:flex; flex-direction:column; align-items:center;">
    <a href="https://github.com/namidaco/namida-snapshots/releases/latest"><img src="./some stuff/badge_github_beta.png" height="50"></a>
  </div>
</td>
<td align="center"><a href="https://docs.namida.app/installation/#apple-install"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/install_guide_dark.svg"><img src="./some%20stuff/summaries/install_guide_light.svg" width="150" align="absmiddle" alt="Install guide"></picture></a></td>
</tr>

<tr>
<td align="center"><b>iOS</b> <sub><code>new</code></sub></td>
<td align="center"><i>Soon</i></td>
<td align="center" width="200">
  <div style="display:flex; flex-direction:column; align-items:center;">
    <a href="https://github.com/namidaco/namida-snapshots/releases/latest"><img src="./some stuff/badge_github_beta.png" height="50"></a>
    <a href="https://namidaco.github.io/namida-snapshots/altstore-source.json"><img src="./some%20stuff/summaries/pm_altstore.svg" height="50" alt="AltStore"></a>
  </div>
</td>
<td align="center"><a href="https://docs.namida.app/installation/#apple-install"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/install_guide_dark.svg"><img src="./some%20stuff/summaries/install_guide_light.svg" width="150" align="absmiddle" alt="Install guide"></picture></a></td>
</tr>

</table>

</div>

Full installation steps for every platform (which file to pick, dependencies and updates) are in the [docs](https://docs.namida.app/installation/).

> [!WARNING]
> Namida is only available through [namida.app](https://namida.app), GitHub & Telegram.
> We are not responsible for downloads from other sources.

<a name="permission-note"></a>
<details>
<summary><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/permissions_dark.svg"><img src="./some%20stuff/summaries/permissions_light.svg" width="435" align="absmiddle" alt="Android Permissions"></picture></summary>

> - `WAKE_LOCK` & `FOREGROUND_SERVICE` & `FOREGROUND_SERVICE_MEDIA_PLAYBACK`: keep app alive for media playback.
> - `INTERNET`: for many stuff like artist/album images, streaming & downloading, etc.
> - `READ_EXTERNAL_STORAGE` (Android ≤ 12): list files from indexer folders only.
> - `READ_MEDIA_AUDIO` (Android 13+): list audio files from indexer folders only.
> - `READ_MEDIA_VIDEO` (Android 13+): list video files from indexer folders only (for video playback).
> - `READ_MEDIA_IMAGES` (Android 13+): list image files from indexer folders only (for fallback covers).
> - `WRITE_EXTERNAL_STORAGE` (Android ≤ 10): same as below but less restrict.
> - `MANAGE_EXTERNAL_STORAGE` or `all_files_access` (Android 10+ / requested when needed): used for
>   - editing audio tags
>   - creating or auto-restoring backups
>   - saving artworks
>   - deleting files
>   - compressing images & fix ytdlp images
>   - exporting playlists as m3u
>   - downloading youtube content
>   - playing tracks from a root folder
>   - in-app file browser
> - `VIBRATE`: vibrate/haptic feedback while doing some actions (can be turned off in settings).
> - `POST_NOTIFICATIONS` (requested when needed): post notifications like history import/download progress.
> - `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (requested when needed): improve downloads.
> - `WRITE_SETTINGS` (requested when needed): to set audio as ringtone/etc.
> - `QUERY_ALL_PACKAGES`: to allow opening custom equalizer apps.

</details>

# Translate & Contribute

You can help translating Namida to your language on the Translation Repo.

<a href="https://github.com/namidaco/namida-translations"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/translations_dark.svg"><img src="./some%20stuff/summaries/translations_light.svg" width="174" align="absmiddle" alt="Translations"></picture></a>

Building is not currently directly possible, see why on [#37](https://github.com/namidaco/namida/issues/37#issuecomment-1780341883).

<!-- [![Translation status](https://translate.codeberg.org/widget/namida-translations/namicomponent/horizontal-auto.svg)](https://translate.codeberg.org/engage/namida-translations/) -->

# Community

Join us on our platforms for updates, tips, discussion & ideas.

<a href="https://t.me/namida_official"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/social_tg_channel_dark.svg"><img src="./some%20stuff/summaries/social_tg_channel_light.svg" width="176" align="absmiddle" alt="Telegram"></picture></a>
<a href="https://t.me/+FmdfsgKoGmM1ZGFk"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/social_tg_chat_dark.svg"><img src="./some%20stuff/summaries/social_tg_chat_light.svg" width="176" align="absmiddle" alt="Telegram"></picture></a>
<a href="https://discord.gg/WeY7DTVChT"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/social_discord_dark.svg"><img src="./some%20stuff/summaries/social_discord_light.svg" width="176" align="absmiddle" alt="Discord"></picture></a>

<details>
<summary><a name="companion-apps"></a><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/companion_apps_dark.svg"><img src="./some%20stuff/summaries/companion_apps_light.svg" width="435" align="absmiddle" alt="Companion Apps"></picture></summary>

> **Community-built tools for an enhanced namida experience**
>
> - 🔄 [Namida Sync](https://github.com/010101-sans/namida_sync), a tool for syncing namida backups & files across android, windows and linux
>   - by [@010101-sans](https://github.com/010101-sans)
> - 📊 [Namida Charts](https://github.com/DiWu17/namida_history_app), a companion app that shows yearly, monthly & more listening stats with charts based on namida history
>   - by [@DiWu17](https://github.com/DiWu17)
> - 🎁 [Namida Wrapped](https://namida-wrapped.vercel.app), a local web ui for generating spotify wrapped-style stats
>   - by [@bebrriko](https://github.com/bebrriko)

</details>

# Donate

Donation will help improve namida and will show appreciation.

<a href="https://www.buymeacoffee.com/namidaco"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/donate_bmc_dark.svg"><img src="./some%20stuff/summaries/donate_bmc_light.svg" width="201" align="absmiddle" alt="Buy me a coffee"></picture></a>
<a href="https://ko-fi.com/namidaco"><picture><source media="(prefers-color-scheme: dark)" srcset="./some%20stuff/summaries/donate_kofi_dark.svg"><img src="./some%20stuff/summaries/donate_kofi_light.svg" width="201" align="absmiddle" alt="Ko-fi"></picture></a>

> Bitcoin/ETH/USDT (BEP20): `0x95b2834c84def92860df773d8b3d80d4c296d748`

# Special Thanks

> - [@MSOB7YY](https://github.com/MSOB7YY) for their youtube client, which powers youtube section.
> - [@cameralis](https://github.com/cameralis) for their awesome miniplayer physics.
> - [@alexmercerind](https://github.com/alexmercerind) for helping me out a lot.
> - [@lusaxweb](https://github.com/lusaxweb) for their awesome Iconsax icon pack.
> - All packages' maintainers which made namida possible.
>   <br>

# LICENSE

Project is licensed under [EULA](https://github.com/namidaco/namida/blob/main/LICENSE).

```
© Copyright (C) 2023-present Namidaco <namida.coo@gmail.com>
- You may read/compile/modify the code for your personal usage, or for the purpose of contribution for the software.
- Redistributing the program as a whole under different name or license without permission is not allowed.
```

---

<a href="https://trendshift.io/repositories/9581" target="_blank"><img src="https://trendshift.io/api/badge/repositories/9581" alt="namidaco%2Fnamida | Trendshift" style="width: 250px; height: 55px;" width="250" height="55"/></a>

Don't forget to 🌟 star the repo if you like the project ^^

<a href="https://www.star-history.com/?repos=namidaco%2Fnamida&amp;type=date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=namidaco/namida&amp;type=date&amp;theme=dark&amp;legend=top-left" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=namidaco/namida&amp;type=date" />
    <img alt="Namida GitHub star history" src="https://api.star-history.com/chart?repos=namidaco/namida&amp;type=date" />
  </picture>
</a>

<br>

> Made by human, **not** vibe coded. AI usage is minimal and very selective.
> Every design choice comes after thoughtful decisions and series of refining, down to every pixel.
> Parts that are built by ai will have a disclaimer. [See here](https://github.com/namidaco/namida/issues/945) for more info.
