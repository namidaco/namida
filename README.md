# <div style="display: flex; align-items: center;"><img src="some stuff/namida.png" width="82" style="margin-right: 10px;">Namida</div>


A Beautiful and Feature-rich Music & Video Player, Built in Flutter

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
- Tracks, Albums, Artists, Genres, Playlists, Queues and Folders Pages.
- Waveform seekbar.
- Lots of customizations (check out customization section).

## Others:
- Define parameters to use for filtering tracks in search lists.
- Global Tracks Selection
   - allows u to select from multiple places into the same list.
- Never miss your sessions!
   - persistent and reliable queue system, your sessions are saved for later usage.
- Reliable History System
   - lets u specifiy minimum seconds/percentage to count a listen
- Most Played Playlist
   - find out your top tracks (relies on your history)

## Some additional cool features:
- Smort Tracks Generation:
    - uuh.. with dis advanced algorithm brought for you, u can generate tracks related to one you currently listening to, typically the ones that you often listened to in the same period.
    - also u can generate tracks from specific range of time, or from available moods, or randomly.
- Animating Thumbnail:
   - A thumbnail that animates with the current audio peak, looks cool.
- Miniplayer Party Mode:
   - Applies an edge breathing effect, color can be static or dynamic (all the colors extracted from the artwork)
- Particles Effect
   - they speed up with the audio peak too
- Insert after latest inserted
   - Want to insert multiple tracks one after each other? this will get your back.
- Repeat for N times
   - in addition to normal repeat modes (all, none, one), this one lets you repeat the track for number of times before playing the next track.
- <p>CAN IMPORT YOUTUBE HISTORY <img src="some stuff/ong.png" width=16 height=16/></p>
- <p>LASTFM TOO AND MAYBE MORE IN FUTURE <img src="some stuff/yoowhat.gif" width=16 height=16/></p>
- you gonna find decent amount of options/customizations in the settings and inside dialogs so make sure to check them out.

# Video Integration
- Namida is capable of playing videos related to the music, video can be found either locally or fetched from youtube
<details>
<summary>how locally?</summary>
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
<summary>how youtube?</summary>
 • looks up in the track comment tag (as they are mostly done by @yt-dlp) or filename for any matching youtube link, if found then it starts downloading (and caches permanently) and plays once it's ready, streaming here isn't a good idea as the priority goes for the music file itself.
</details>
<br>


# Screenshots
# Installation
-

### Note Regarding Tag Editor
>- tag editor needs SAF (storage access framework) permission in order to edit metadata.
>- usually u will have to set it for each folder that contains the desired track so there is like 2 options
>    1. request saf permission everytime you are editing a track that isn't inside the folder having access (it will be always the last granted folder) 
>    2. copy track to a specific folder (i chose backup folder), ask for permission, edit metadata, move the track back to the original path
>- obviously i chose the second, this will cause the permission to reset if u changed default backup location. 

### Note Regarding waveform generation
>- Currently, generating waveform takes ~8 seconds for a 3 min track, I'm limited by the technology of my time, though that being said, once the waveform is generated, it is cached permanently, meaning you will not have to wait again.
>- Due to that, I've provided an option to generate all waveforms at once, maybe u can use it on a night sleep.

## - Permission Note:
### the following actions require <font size="1">`all_files_access`</font> permission (requested when needed)
>- respect .nomedia
>- editing audio tags
>- creating or restoring backups

### Special Thanks:
 >- @LucJosin for their jaudiotagger integration, which actually powers namida.
 >- @55nknown for their awesome miniplayer physics.
 >- @alexmercerind for helping me out a lot.
 >- @lusaxweb for their awesome Iconsax icon pack.
 >- All the packages maintainers which made namida possible.
 <br>
 
> ### © Logo by @midjourney
# Donate
- 

# LICENSE
uhhmm i dont understand much about general licenses so here is yours

```
© Copyright (C) 2023-present Namidaco <namida.coo@gmail.com>
ANY  CODE  STEALING  IS ONLY ALLOWED IF YOU UNDERSTAND IT OR THE PURPOSE BEHIND IT
and ofc redistributing the program as a whole under different name or license without permission is not allowed.
```
