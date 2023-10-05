<link rel="stylesheet" href="styles.css" />

# <div style="margin-right: 18px; margin-top: 18px; display:flex; vertical-align: middle; align-items: center; max-width: 100%;"><img src="some stuff/namida.png" width="82" style="margin-right: 18px;">Namida</div>

A Beautiful and Feature-rich Music & Video Player with Youtube Support, Built in Flutter

![Static Badge](https://img.shields.io/badge/Built%20in-Flutter-blue)

# Sections:

- [Features](#-features)
  - [Library \& Indexing](#library--indexing)
  - [Look \& Feel](#look--feel)
  - [Streaming](#streaming)
  - [Others](#others)
  - [Some additional cool features](#some-additional-cool-features)
- [Video Integration](#video-integration)
- [Screenshots](#screenshots)
- [Usage Preview](#usage-preview)
- [Installation](#installation)
- [Permission Note](#-permission-note)
- [Special Thanks](#special-thanks)
- [Donate](#donate)
- [LICENSE](#license)

# 🎉 Features

- Everything you might expect from a music player, in addition to the following:

## Library & Indexing

- Powerful Indexer & Tag Editor, powered by @jaudiotagger.
- Artists and Genres Separators.
- Prevent Duplicated Tracks.
- Set Minimum File Size & Duration.
- Folders-based Library system, with the ability to exclude folders as well.
- Sort by almost any property of the track or the album.. etc.

## Look & Feel

- Material3-like Theme.
- Dynamic Theming, Player Colors are picked from the current album artwork.
- Home, Tracks, Albums, Artists, Genres, Playlists, Queues and Folders Pages.
- Waveform Seekbar.
- Lots of customizations (check out [customization section](#customization-settings)).

## Streaming

- Best Video & Audio Quality
- Audio Only Mode
- Support Caching & Offline Playback
- Support Downloads
- Video View with gestures support (swipe to control volume, double tap to seek, swipe up/pinch in to enter fullscreen, etc)
- Edit tags for downloads
- Optional Auto title/artist/album extraction for downloads and scrobbling

## Others:

- Sleep Timer (Tracks or Minutes)
- Play/Pause Fade Effect, along with Skip Silence.
- Control pausing scenarios (calls, notifications, volume 0, etc..)
- Define parameters to use for filtering tracks in search lists.
- Global Tracks Selection
  - allows u to select from multiple places into the same list.
- Never miss your sessions!
  - persistent and reliable queue system, your sessions are saved for later usage.
- Reliable History System
  - despite being a flexible system (easily modified, manipulated, imported), it lets u specifiy minimum seconds/percentage to count a listen.
- Most Played Playlist
  - find out your top tracks based on your history record.

## Some additional cool features:

- Smort Tracks Generation:
  - uuh.. with dis advanced algorithm brought for you, u can generate tracks related to one you currently listening to, typically the ones that you often listened to in the same period. based on your history.
  - also u can generate tracks released around the same time, or from specific range of time, from ratings, from available moods, or randomly.
- Animating Thumbnail:
  - A thumbnail that animates with the current audio peak, looks cool.
- Miniplayer Party Mode:
  - Applies an edge breathing effect, colors can be static or dynamic (all the colors extracted from the artwork)
- Particles Effect
  - they speed up with the audio peak too
- Insert after latest inserted
  - Want to insert multiple tracks one after each other? this will get your back.
- Repeat for N times
  - in addition to normal repeat modes (all, none, one), this one lets you repeat the track for number of times before playing the next track.
- Extract feat. & ft. artist
  - u won't miss the featured artists in the title, they'll have their own entry inside artists tab.
- <p>CAN IMPORT YOUTUBE HISTORY <img src="some stuff/ong.png" width=16 height=16/></p>
- <p>LASTFM TOO AND MAYBE MORE IN FUTURE <img src="some stuff/yoowhat.gif" width=16 height=16/></p>
- you gonna find decent amount of options/customizations in the settings and inside dialogs so make sure to check them out.

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
note: some cleanup is made to improve the matching, all symbols & whitespaces are ignored.
</details>

<details>
<summary>

###### How youtube?

</summary>
 • looks up in the track comment tag (as they are mostly done by @yt-dlp) or filename for any matching youtube link, if found then it starts downloading (and caches) and plays once it's ready, streaming here isn't a good idea as the priority goes for the music file itself.
</details>

# Screenshots

<img src="screens/collection_light_1.jpg" class="imgbr"/>
<img src="screens/collection_light_2.jpg" class="imgbr"/>
<img src="screens/collection_dark_1.jpg" class="imgbr"/>
<img src="screens/collection_dark_2.jpg" class="imgbr"/>


<details>
  <summary>

### Customization Settings

  </summary>
    <img src="screens/customization_settings.jpg" class="imgbr">
</details>
<br>

### Usage Preview



# Installation

- Download latest version from [releases](https://github.com/namidaco/namida/releases) page
- Available variants are arm & arm64

### Permission Note:

##### the following actions require <span>`all_files_access`</span> permission (requested when needed)

> - editing audio tags
> - creating or restoring backups
> - saving artworks
> - compressing images
> - downloading youtube content

### Special Thanks:

> - [@Artx-II](https://github.com/Artx-II) for their initial dart port of Newpipe Extractor, which powers youtube section.
> - [@cameralis](https://github.com/cameralis) for their awesome miniplayer physics.
> - [@alexmercerind](https://github.com/alexmercerind) for helping me out a lot.
> - [@lusaxweb](https://github.com/lusaxweb) for their awesome Iconsax icon pack.
> - All packages' maintainers which made namida possible.
>   <br>

> ### © Logo by @midjourney

# Donate

- Donation will help improve namida and will show appreciation.

<a href="https://www.buymeacoffee.com/namidaco" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 42px;" ></a>

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/U7U0PF2L5)

# LICENSE

Project is licensed under [EULA](https://github.com/namidaco/namida/blob/main/LICENSE) License.

```
© Copyright (C) 2023-present Namidaco <namida.coo@gmail.com>
- You may read/compile/modify the code for your personal usage, or for the purpose of contribution for the software.
- Redistributing the program as a whole under different name or license without permission is not allowed.
```
