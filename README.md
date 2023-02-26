# Namida

A Beautiful and Feature-rich Music Player Built in Flutter

# 🎉 Features
## Indexing
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
- Define parameters to use for filtering tracks in search lists.
- Customize anything and everything.
## Customization
- Enable/Disable Blur & Glow Effects.
- Border Radius Multiplier.
- Font Scale.
- Track Tile & Album Tile Customization settings.
- Control exactly what to show in the track tile, all information that was extracted can be put.
- Lots of other options (check customization section).


# Installation
-

# Note Regarding Tag Editor
- tag editor needs SAF (storage access framework) permission in order to edit metadata.
- usually u will have to set it for each folder that contains the desired track so there is like 2 options
    1. request saf permission everytime you are editing a track that isn't inside the folder having access (it will be always the last granted folder) 
    2. copy track to a specific folder (i chose backup folder), ask for permission, edit metadata, move the track back to the original path
- obviously i chose the second, this will cause the permission to reset if u changed default backup location. 

# Note Regarding waveform generation
- Currently, generating waveform takes ~8 seconds for a 3 min track, I'm limited by the technology of my time, though that being said, once the waveform is generated, it is cached permanently, meaning you will not have to wait again.
- Due to that, I've provided an option to generate all waveforms at once, maybe u can use it on a night sleep.

# Support


## Permission Note:
### the following actions require `all_files_access` permission (requested when needed)
- respect .nomedia
- editing audio tags
- creating or restoring backups