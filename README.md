<link rel="stylesheet" href="styles.css" />

# <div style="margin-right: 18px; margin-top: 18px; display:flex; vertical-align: middle; align-items: center; max-width: 100%;"><img src="assets/namida_icon.png" width="82" style="margin-right: 18px;">Namida</div>

A Beautiful and Feature-rich Music & Video Player with Youtube Support, Built in Flutter

<a href="https://namida.app">![](https://img.shields.io/badge/-Website-%23463e35)
</a>
<a href="https://docs.namida.app">![](https://img.shields.io/badge/-Docs-%23f1d6b6)
</a>
<a href="https://t.me/namida_official">![](https://img.shields.io/badge/Channel-blue?link=https%3A%2F%2Ft.me%2Fnamida_officialt&logo=telegram&logoColor=white)
</a>
<a href="https://t.me/+FmdfsgKoGmM1ZGFk">![](https://img.shields.io/badge/Chat-blue?link=https%3A%2F%2Ft.me%2F%2BFmdfsgKoGmM1ZGFk&logo=telegram&logoColor=white)
</a>
<a href="https://discord.gg/WeY7DTVChT">![](https://img.shields.io/badge/Discord-7B55C1?link=https%3A%2F%2Fdiscord.gg%2FWeY7DTVChT&logo=discord&logoColor=white)
</a>
<a href="https://github.com/namidaco/namida/releases">
![](https://img.shields.io/github/downloads/namidaco/namida/total.svg)
</a>
<a href="https://github.com/flutter/flutter">![](https://img.shields.io/badge/Built%20in-Flutter-%23369FE7)
</a>
<a href="https://github.com/namidaco/namida/releases">
[![Hits-of-Code](https://hitsofcode.com/github/namidaco/namida?branch=main)](https://hitsofcode.com/github/namidaco/namida/view?branch=main)
</a>
<a href="https://github.com/namidaco/namida/releases">
[![](https://img.shields.io/endpoint?url=https://ghloc.vercel.app/api/namidaco/namida/badge?style=flat&logo=dart&logoColor=aqua&label=Total%20Lines&color=darkturquoise)](https://ghloc.vercel.app/namidaco/namida?branch=main)
</a>

<div>
  <a href="https://github.com/namidaco/namida/releases/latest">
    <img src="./some stuff/badge_github.png" height="50">
  </a>
  &nbsp;
  <a href="https://apps.obtainium.imranr.dev/redirect?r=obtainium://add/https://github.com/namidaco/namida/">
    <img src="https://raw.githubusercontent.com/ImranR98/Obtainium/main/assets/graphics/badge_obtainium.png" height="50">
  </a>
</div>

# Documentation

New to Namida or want to discover more? **[Checkout the docs here](https://docs.namida.app)**

# Sections:

- [Documentation](#documentation)
- [Features](#-features)
  - [Library \& Indexing](#library--indexing)
  - [Look \& Feel](#look--feel)
  - [Sound](#sound)
  - [Streaming & Youtube](#streaming--youtube)
  - [System Integration](#system-integration)
  - [Others](#others)
  - [Some additional cool features](#some-additional-cool-features)
- [Video Integration](#video-integration)
- [Screenshots](#screenshots)
- [Usage Preview](#usage-preview)
- [Installation](#installation)
- [Companion Apps](#companion-apps)
- [Permission Note](#permission-note)
- [Special Thanks](#special-thanks)
- [Translate](#translate)
- [Contribute](#contribute)
- [Donate](#donate)
- [Social](#social)
- [LICENSE](#license)

# 🎉 Features

- Everything you might expect from a music player, in addition to the following:

## Library & Indexing

- Powerful Indexer & Tag Editor, powered by `taglib`.
- Artists & Genres Separators.
- Prevent Duplicated Tracks, Minimum File Size & Duration.
- Folders-based Library, with excluded folders.
- Sort by almost any track or album property.

## Look & Feel

- Material3-like Theme with Dynamic Colors from the current artwork.
- Home, Tracks, Albums, Artists, Genres, Playlists, Folders & Queues Pages, plus cool ones like Most Played, Moods, Tags, Ratings, Languages, Stats & more.
- Waveform Seekbar & Widescreen Player Layout.
- Visualizers, Animated Backgrounds & Custom Wallpapers. <sub><code>new</code></sub>
- Lots of customizations (check out [customization section](#customization-settings)).

## Sound

- Parametric Equalizer with AutoEQ import. <sub><code>new</code></sub>
- Bit-perfect Playback, USB DAC Direct Access, Exclusive Mode (desktop) & 32-bit float audio. <sub><code>new</code></sub>
- Audio Path, see every step from the file to your device. <sub><code>new</code></sub>
- Output Device Selection & Mono Audio. <sub><code>new</code></sub>
- Sound Effects like Bass Enhancer, Reverb, Virtual Surround, 8D Audio & Vocal Remover (Android). <sub><code>new</code></sub>
- Smart Crossfade with Beat Matching <sub><code>new</code></sub>, Gapless Playback, Play/Pause Fade & Skip Silence.
- Speed & Pitch Control (semitones & 432Hz) & Loudness Enhancer.
- Per-track Speed, Pitch, Volume & Equalizer, and Sound Presets to switch them all at once. <sub><code>new</code></sub>
- Replay Gain support (Normalize loudness between tracks)

## Streaming & Youtube

- Best Video & Audio Quality, Audio Only & Data Saver Mode.
- Sign in with Multiple Profiles, get your Feed, Subscriptions, Playlists & Notifications.
- Multi Library (Local/YT/Subsonic/Jellyfin/WebDAV/SMB) & Offline Caching for Servers. <sub><code>new</code></sub>
- Video View with [gestures](https://docs.namida.app/features/youtube/#video-view) for volume, brightness, seeking, fullscreen, speed up & more.
- SponsorBlock, Return Youtube Dislike, Segments & Heatmap.
- Subtitles & Captions.
- Downloads, Caching & Offline Playback, with a Cache Priority System.
- Split Downloads by Chapters & Remove Sponsor Segments. <sub><code>new</code></sub>
- Downloads Tags config & Filename builder (similar to yt-dlp).
- Auto title/artist/album extraction from video titles, for downloads & scrobbling.

<details>

<summary>Available formats & example</summary>

- Formats:
  - `video_id`, `id`: video identifier
  - `video_url`, `url`: video full url (https://www.youtube.com/watch?v=`id`)
  - `video_title`, `fulltitle`: video full title
  - `title`: extracted music title from video title (_Navjaxx - **<ins>Fading Light</ins>** (Slowed)_)
  - `artist`: extracted music artist from video title (**\*<ins>Navjaxx</ins>** - Fading Light (Slowed)\*) or else `channel`
  - `genre`: music genre. automatically set to **_Nightcore_** when the video title contains "nightcore".
  - `ext`: format container extension (mp4, m4a, webm). this is not necessary as it would be added automatically
  - `channel_fulltitle`: channel full name
  - `channel`, `uploader`: channel name (excluding ` - Topic`)
  - `channel_id`, `uploader_id`: channel id
  - `channel_url`, `uploader_url`: channel url
  - `timestamp`: UNIX timestamp of the video (milliseconds since epoch)
  - `upload_date`: upload date of the video, converted to local time (yyyyMMdd)
  - `view_count`: view count of the video
  - `like_count`: like count of the video
  - `description`: video description. links are wrapped in a markdown style
  - `duration`: video duration in seconds (204)
  - `duration_string`: video duration formatted (3:24)
  - `playlist_title`: title of the playlist containing the video
  - `playlist_id`: id of the playlist containing the video
  - `playlist`: `playlist_title` if available or else `playlist_id`
  - `playlist_count`: total videos count in the playlist
  - `playlist_index`: index of the video in the playlists (starts at 0)
  - `playlist_autonumber`: position of the video in the playlists (starts at 1)
  - `none`: empty field. useful for tags to override any other settings

- Example:

```bash
# [04] music title [(channel name)]
[%(playlist_autonumber)s] %(title)s [(%(channel)s)]

# saving to separate folders
# music playlist/02. music title.m4a
%(playlist)s/%(playlist_autonumber)s. %(title)s.%(ext)s
```

</details>

## System Integration

- Home Screen Widget & Quick Settings Tiles.
- Android Auto & Wear OS. <sub><code>new</code></sub>
- Status Bar Lyrics. <sub><code>new</code></sub>
- Desktop: System Tray, Keyboard Shortcuts, System Wide Hotkeys & Floating Lyrics Window.
- Now Playing Broadcasts & Webhook for Tasker, scripts & scrobblers. <sub><code>new</code></sub>

## Others:

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

## Some additional cool features:

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

# Video Integration

- For Local Library, Namida is capable of playing videos related to the music, Video can be found either locally or fetched from youtube

<details>
<summary>

###### How locally?

</summary>
typically looks (inside the folders you specificed) for any matching title, matching goes as following:
<br>
-- Alan walker - Faded.m4a
<br>
-- video alAn WaLkER - faDed (480p).mp4
<br>
the video filename should contain at least one of the following:
 <br>
   1. the music filename as shown above.
 <br>
   2. title & first artist of the track.
 <br>
   3. track youtube id (in track comment tag/filename, see "#How youtube?" section below).
<br>
note: some cleanup is made to improve the matching, all symbols & whitespaces are ignored.
</details>

<details>
<summary>

###### How youtube?

</summary>

- looks up in the track comment tag (as they are mostly done by @yt-dlp) or filename for any matching youtube link, if found then it starts downloading (and caches) and plays once it's ready, streaming here isn't a good idea as the priority goes for the music file itself.
  - for comment tag, any url format should get matched normally (example: `https://youtu.be/video_id`).
  - for filenames, it should contain `v=video_id` or `id=video_id` in order to get matched.

</details>

- Since v4.0.0, full video library indexing & playback is supported, videos can now be played independently, as well as dedicated videos folder view.

# Screenshots

<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/collection_light_1.webp" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/collection_light_2.webp" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/collection_light_3.webp" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/collection_light_4.webp" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/collection_dark_1.webp" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/collection_dark_2.webp" class="imgbr"/>

<details>
  <summary>

### Customization Settings

  </summary>
    <img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_customization.webp" class="imgbr" width="50%">
</details>

<details>
  <summary>

### All Settings

  </summary>

<table>
  <tr><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings.webp" class="imgbr"/></td><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_theme.webp" class="imgbr"/></td><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_indexer.webp" class="imgbr"/></td></tr>
  <tr><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_playback.webp" class="imgbr"/></td><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_youtube.webp" class="imgbr"/></td><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_extras.webp" class="imgbr"/></td></tr>
  <tr><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_backup.webp" class="imgbr"/></td><td valign="top"><img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/readme/settings/settings_advanced.webp" class="imgbr"/></td></tr>
</table>

</details>

<details>
  <summary>

### YouTube Miniplayer

  </summary>
    <img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/manual/yt_miniplayer.jpg" class="imgbr" width="50%">
</details>

<details>
  <summary>

### 2023 Screenshots

  </summary>

<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots_2023/collection_light_1.jpg" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots_2023/collection_light_2.jpg" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots_2023/collection_dark_1.jpg" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots_2023/collection_dark_2.jpg" class="imgbr"/>
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots_2023/customization_settings.jpg" class="imgbr" width="50%">
<img src="https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots_2023/yt_miniplayer.png" class="imgbr" width="50%">

</details>
<br>

### Usage Preview

| Animating Thumbnail | Recommends & Listens |
| --- | --- |
| <video src="https://github.com/namidaco/namida/assets/85245079/da47c270-9f45-4ff5-a08e-e99e4b7ebb7c.mp4"> | <video src="https://github.com/namidaco/namida/assets/85245079/72e978b3-6e15-4b4e-948a-03b470802b30.mp4"> |

# Installation

<div align="center">

<table>

<tr>
  <th><div align="center">Platform</div></th>
  <th><div align="center">Stable</div></th>
  <th><div align="center">Beta</div></th>
</tr>

<tr>
<td align="center"><b>Android</b></td>
<td align="center" width="200">
  <div style="display:flex; flex-direction:column; align-items:center;">
    <a href="https://github.com/namidaco/namida/releases/latest">
      <img src="./some stuff/badge_github.png" height="50">
    </a>
    <a href="https://apps.obtainium.imranr.dev/redirect?r=obtainium://add/https://github.com/namidaco/namida/">
      <img src="https://raw.githubusercontent.com/ImranR98/Obtainium/main/assets/graphics/badge_obtainium.png" height="50" style="margin-top:8px;">
    </a>
  </div>
</td>
<td align="center" width="200">
  <div style="display:flex; flex-direction:column; align-items:center;">
    <a href="https://github.com/namidaco/namida-snapshots/releases/latest">
      <img src="./some stuff/badge_github.png" height="50">
    </a>
    <a href="https://apps.obtainium.imranr.dev/redirect?r=obtainium://add/https://github.com/namidaco/namida-snapshots/">
      <img src="https://raw.githubusercontent.com/ImranR98/Obtainium/main/assets/graphics/badge_obtainium.png" height="50" style="margin-top:8px;">
    </a>
  </div>
</td>
</tr>

<tr>
<td align="center"><b>Windows</b></td>
<td align="center" width="200">
  <div style="display:flex; flex-direction:column; align-items:center;">
    <a href="https://github.com/namidaco/namida/releases/latest">
      <img src="./some stuff/badge_github.png" height="50">
    </a>
  </div>
</td>
<td align="center" width="200">
  <div style="display:flex; flex-direction:column; align-items:center;">
    <a href="https://github.com/namidaco/namida-snapshots/releases/latest">
      <img src="./some stuff/badge_github.png" height="50">
    </a>
  </div>
</td>
</tr>

<tr>
<td align="center"><b>Linux</b> <sub><code>new</code></sub></td>
<td align="center"><i>Soon</i></td>
<td align="center" width="200">
  <div style="display:flex; flex-direction:column; align-items:center;">
    <a href="https://github.com/namidaco/namida-snapshots/releases/latest">
      <img src="./some stuff/badge_github.png" height="50">
    </a>
    <a href="#linux-installation"><sub>Installation steps ↓</sub></a>
  </div>
</td>
</tr>

</table>

</div>

### Linux Installation

1. **Install Dependencies**

> [!IMPORTANT]
> Install dependencies: **mpv** for playback
> (you may skip this if you used a package manager)
>
> ```bash
> sudo pacman -S mpv            # Arch/Manjaro
> sudo apt install mpv libmpv2  # Debian/Ubuntu/Mint
> sudo dnf install mpv mpv-libs # Fedora/RHEL
> ```

> [!NOTE]
> (Optional) Install **webkit2gtk** for youtube login & poToken
>
> ```bash
> sudo pacman -S webkit2gtk-4.1          # Arch/Manjaro
> sudo apt install libwebkit2gtk-4.1-0   # Debian/Ubuntu/Mint
> sudo dnf install webkit2gtk4.1         # Fedora/RHEL
> ```

2. **Install Namida**

```bash
# Quick Install
curl -fsSL https://raw.githubusercontent.com/namidaco/namida/main/scripts/install_linux_tar.sh | sudo bash

# Package managers
yay -Sy namida-bin                  # AUR (Arch Linux)
paru -Sy namida-bin                 # AUR (Arch Linux)
sudo apt install ./namida.deb   # Debian/Ubuntu (download .deb from beta releases)
sudo dnf install ./namida.rpm   # Fedora/RHEL (download .rpm from beta releases)

# Nix (Home Manager) Installation
# Available at: https://codeberg.org/iWisp360/namida-nix
```

### Companion Apps:

> [!TIP]
> **Community-built tools for an enhanced namida experience**
>
> - 🔄 [Namida Sync](https://github.com/010101-sans/namida_sync), a tool for syncing namida backups & files across android, windows and linux
>   - by [@010101-sans](https://github.com/010101-sans)
> - 📊 [Namida Charts](https://github.com/DiWu17/namida_history_app), a companion app that shows yearly, monthly & more listening stats with charts based on namida history
>   - by [@DiWu17](https://github.com/DiWu17)
> - 🎁 [Namida Wrapped](https://namida-wrapped.vercel.app), a local web ui for generating spotify wrapped-style stats
>   - by [@bebrriko](https://github.com/bebrriko)

### Permission Note:

#### The permissions namida uses and why:

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

### Special Thanks:

> - [@MSOB7YY](https://github.com/MSOB7YY) for their youtube client, which powers youtube section.
> - [@cameralis](https://github.com/cameralis) for their awesome miniplayer physics.
> - [@alexmercerind](https://github.com/alexmercerind) for helping me out a lot.
> - [@lusaxweb](https://github.com/lusaxweb) for their awesome Iconsax icon pack.
> - All packages' maintainers which made namida possible.
>   <br>

# Translate

- You can help translating Namida to your language on [Translation Repo](https://github.com/namidaco/namida-translations)

# Contribute

- Building is not currently directly possible, see why on https://github.com/namidaco/namida/issues/37#issuecomment-1780341883

<!-- [![Translation status](https://translate.codeberg.org/widget/namida-translations/namicomponent/horizontal-auto.svg)](https://translate.codeberg.org/engage/namida-translations/) -->

# Donate

- Donation will help improve namida and will show appreciation.

<a href="https://www.buymeacoffee.com/namidaco" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 42px;" ></a>
<a href="https://ko-fi.com/namidaco" target="_blank"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Ko-fi" style="height: 42px;" ></a>

> Bitcoin/ETH/USDT (BEP20): `0x95b2834c84def92860df773d8b3d80d4c296d748`

- Don't forget to 🌟 star the repo if you like the project ^^

# Social

- join us on our platforms for updates, tips, discussion & ideas
  - [Telegram (Updates)](https://t.me/namida_official)
  - [Telegram (Chat)](https://t.me/+FmdfsgKoGmM1ZGFk)
  - [Discord](https://discord.gg/WeY7DTVChT)

> [!WARNING]
> Namida is only available through [namida.app](https://namida.app), GitHub & Telegram.
> We are not responsible for downloads from other sources.

# LICENSE

Project is licensed under [EULA](https://github.com/namidaco/namida/blob/main/LICENSE) License.

```
© Copyright (C) 2023-present Namidaco <namida.coo@gmail.com>
- You may read/compile/modify the code for your personal usage, or for the purpose of contribution for the software.
- Redistributing the program as a whole under different name or license without permission is not allowed.
```

---

<a href="https://trendshift.io/repositories/9581" target="_blank"><img src="https://trendshift.io/api/badge/repositories/9581" alt="namidaco%2Fnamida | Trendshift" style="width: 250px; height: 55px;" width="250" height="55"/></a>

<a href="https://www.star-history.com/?repos=namidaco%2Fnamida&amp;type=date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=namidaco/namida&amp;type=date&amp;theme=dark&amp;legend=top-left" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=namidaco/namida&amp;type=date" />
    <img alt="Namida GitHub star history" src="https://api.star-history.com/chart?repos=namidaco/namida&amp;type=date" />
  </picture>
</a>

> Made by human, **not** vibe coded. AI usage is minimal and very selective.
> Every design choice comes after thoughtful decisions and series of refining, down to every pixel.
> Parts that are built by ai will have a disclaimer. [See here](https://github.com/namidaco/namida/issues/945) for more info.
