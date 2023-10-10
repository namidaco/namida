# Namida Changelog

## 10/10/2023
# v1.3.0
### 🎉 New Features:
- feat:
   - #aabbff1: add mood as tag field
   - #6e2159d: add downloaded music to library automatically
   - #07ab4cd: add youtube as a library tab
   - #3514ef1: image cache clear dialog rework, now can choose which directories to clear
   - #edda4ea: yt audio language tracks support (this also includes caching)
   - #517a484: on Youtube Link open (showDownload, play, addToPlaylist, alwaysAsk)
   - #149902c: clipboard auto paste & direct yt link open
   - #ce481c7: extract by ffmpeg if tagger failed
   - #c9b9445: display video listen count & jump to listen for youtube videos
   - #3da20ce: share logs easily from within about page
   - #6888d8a: group artworks by album
   - #37a1fe5: album distinguish parameters
   - #9e82433: media type chips for searching, can now control which media to search for (tracks, albums, artists, genres, playlists, folders) 
   - #2d84131: auto search option when setting youtube link

### 🛠️ Bug fixes & Improvements:
- chore:
   - #36273bb: playback improvements
   - #584f733: display video info while clearing video cache
   - #1d070d9: few ui fixes/improvements
   - #e1889d6: few tweaks
   - #822072e: search cleanup is true by default
   - #9395a1a: try editing tags with ffmpeg if tagger failed
   - #032b313: suspend playing next while reordering queue
   - #ca03127: some improvements
   - #c60cd84: add yt miniplayer screenshot
   - #ac69925: few tweaks
   - #3953f53: few tweaks
   - #ae424ac: prevent accidental triggers (android back & home gestures)
   - #461d045: max image cache size
   - #973e824: auto-coloring from device wallpaper (A12+)
   - #d9a0aa1: display remaining duration instead of total
- fix:
   - #ac90081: video playback sync for local music
   - #f7487f4: not fetching lower res yt images
- code:
   - #4c35777: refactor snackbars
- core:
   - #19b60b9: add yt history import to yt history too

## 03/10/2023
# v1.0.0 (first release)
### 🎉 New Features:
- feat:
   - #d9a0aa1: display remaining duration instead of total
   - #0d28477: youtube settings section
   - #db504f8: expose parallax effect toggle
   - #f501db3: swipe up tp enter fullscreen
   - #aa11934: open in youtube view for local tracks
   - #2a214c8: dim after inactivity for yt miniplayer (later to expose dim intenstiy and timer)
   - #fab06ec: option to keep cached downloaded versions
   - #b7d9726: integrate yt search in main searchbar
   - #b4404b0: Home View with History Page
   - #20a0159: download notification
   - #0de852a: max video cache option

### 🛠️ Bug fixes & Improvements:
- chore:
   - #92b0d7d: removed useYoutubeMiniplayer option [its being automatically controlled now]
   - #3953f53: few tweaks
   - #ae424ac: prevent accidental triggers (android back & home gestures)
   - #f021060: add recentlyAdded as queue source
   - #196c140: some tweaks
   - #529dd1f: move yt palette to separate folder
   - #331d8a4: ui improvements
   - #aa572be: some fixes
   - #a6a1b94: audio & video buffered separately rendered
   - #4088621: write metadata to newly cached audio files (this allows playing them later without issues)
   - #c07d210: ui refinements, progress bar for yt miniplayer
   - #f59b865: smoother playback, fixes & cache status on card
   - #36bcae5: more seamless playback experience (will now try to play from cache before waiting to fetch info)
   - #0005585: volume sliding only from within safe area
   - #7bc6b98: some goodies
   - #69b020b: some improvements & fixes
   - #d24238a: about page, cleanup & prepare for publish
- core:
   - #19b60b9: add yt history import to yt history too
- perf:
   - #4f2e581: efficient image request
- repo:
   - #187c033: move translations to separate submodule

## 27/09/2023
### 🎉 New Features:
- feat:
   - #6a11b59: offline playback (consistent video caching, can now play without connection)
   - #0685432: continuos seek on double tap
   - #082442f: full cache support, flawless video info, audio only mode
   - #74bfeac: volume change on vertical swipe

### 🛠️ Bug fixes & Improvements:
- chore:
   - #d24238a: about page, cleanup & prepare for publish
   - #a0275fb: video stretch fixes & perf improvements
   - #9ed5c5a: upstream history_manager
   - #23a11a8: update CHANGELOG.md with a new script to auto generate from commits
- chore(ui):
   - #c778696: new yt channel card , playlist cards are playable now
- perf:
   - #61dc93b: backup dialog sizes computing
- license:
   - #c054181: use EULA License


## 21/09/2023
### 🎉 New Features:
   - #dc8a038: expose video/audio download metadata tags
   - #74bfeac: volume change on vertical swipe
   - #7618916: youtube history system
   - #b8892ef: option to write video upload date to downloaded files
   - #e92e5ab: Full Youtube Playback Support, this comes with refined controls, audio caching/downloading, new artist-title splitter, keepFeatKeywordsOnly for youtube scrobbling
   - #e5b9f0d: search navigation button
   - #c625bb7: youtube playlists
   - #d1da50c: set player (volume, speed, pitch) from within minplayer
   - #75972d3: onNotificationTap open (app, miniplayer, queue)
   - #bea7840: open yt link from intent currently shows download dialog, later to be exposed
   - #7d1d576: option to match yt import by both link and title&artist
   - #ea320fb: expose infinity queue on next/prev
   - #5ff30db: picture_in_picture (beta)
   - #91d8ccf: youtube download
   - #020be50: option to keep file dates when editing tags
   - #4e33645: youtube thumbnail/desc/comments caching, quality real-time choosing, initial video widget, focused menu, shimmer & other stuff
   - #e28a79a: auto skip timer when failing to play
   - #e7e763b: (mixes, recentListens, topRecentListens, lostMemories, recentlyAdded, recentAlbums, recentArtists, topRecentAlbums, topRecentArtists)
   - #cfb3d40: separate static color for dark mode

### 🛠️ Bug fixes & Improvements:
- chore:
   - #a0683ff: intent & manifest improvements
   - #2908bbe: av sync fixes
   - #32bb792: open miniplayer upon playing a video
   - #4bcb165: re-structure app directories yt stuff in root dir aint lookin gud
   - #20cbe88: project files re-structure
   - #f97a752: some ui fixes queue sleep icon & search icon in nav bar
   - #ba75788: expose searchbar functions this fixes not opening searchbar if pressed 2millis afar also for upcoming search nav button
   - #4d6a905: pip improvements
   - #1ce7396: some miniplayers magic
   - #3cd953b: youtube pl cards design & other improvements
   - #247f20c: closing dialogs on pip entering
   - #e87d30f: improve fade effect algorithm
   - #13efe4b: enter pip only with videos
   - #6a6f279: refactor toggling enum settings
   - #a94ab28: yt download sheet looks saxier also more detailed status for download icon in yt miniplayer
   - #08b4a1d: play decision after removing from queue
   - #9d2270e: start pip only if playing
   - #dd94450: re-structure internal directory paths this mainly comes in preparation for video downloads
   - #eaad25a: color generation improvements & others
   - #9876595: generate all palettes by default on startup
   - #3c74a5e: fix queue scroll animation in some scenarios
   - #4acd110: yt miniplayer refines
   - #740866c: icon in miniplayer when no connection
   - #9e3ca95: chips for sorting cache videos
   - #f8dd83c: ui tweaks
   - #0910039: some improvements/fixes

- fix:
   - #4f7b399: strecthed video in landscape
   - #2b665a5: downloading cached versions
   - #bd69146: removed number from queue
   - #8f10894: keep cached version when downloading same version by default it was being deleted
   - #061338d: queue favourite button
   - #c589460: folders onWillPop
   - #2813aca: artwork rebuild
   - #90d419d: yt-dlp thumbnail fix improvements (wont move file back if failed)
- code:
   - #c9fe5d1: move history logic to separete mixin this comes for youtube & local videos history
   - #96f46fc: yt miniplayer custom implementation
   - #b95cb58: refactor playlist class to mixin this comes for the upcoming youtube playlists
   - #df92c31: refactor unknown tag fields
   - #7cda5e6: refactor app dirs & paths
   - #398ce61: refactor AnimatedCrossFade this also includes the fix for jumping animation
- chore(lang):
   - #58773e3: update translations
   - #85aaa50: update lang keys
- perf:
   - #4ef3888: run some function in isolate
   - #9ec1cce: move search to isolate


## 20/08/2023
### 🎉 New Features:
   - #2db0a93: expose video matching algorithm
   - #8524032: advanced option to fix yt-dlp big-sized thumbnails
   - #c7b6815: option to compress images
   - #1d3d265: time ranges for most played playlist (day,3 days, week, month... etc)
   - #ec8bd40: history import report with missing entries and ability to manually add them
   - #6343789: advanced option to replace history listens
   - #66b54ff: advanced option to update directory path extremely useful if the directory has been moved, also optional check to replace only missing tracks
   - #a1a8d7d: manage queue generation options exposing insertion parameters like (tracksNo, insertNext, sortBy) for each insertion type
   - #c59eb1f: display more video info in miniplayer
   - #2792536: expose interruption events (pause, duck, do nothing)
   - #0f9108d: option to pause/play on volume 0
   - #71a0a82: some other ui improvements
   - #55fd12e: empty playlist page design
   - #583dba5: new sort: shuffle
   - #76c955c: option to shuffle all tracks or next only (as default)
   - #bacda78: saving youtube stats when importing yt history this comes in preparation for future full youtube support
   - #8571648: option to match all tracks when importing history
   - #0021675: expose track palette for customizing
   - #49d6881: display duration difference while seeking
   - #388beda: script to automatically add language keys
   - #d135789: localization support
   - #783ca13: animating icon while refreshing library
   - #2f6692e: advanced sub-dialog in track dialog this comes in preparation for exposing color palette to edit
### 🛠️ Bug fixes & Improvements:
- chore:
   - #e84698b: smol ui tweak (yt download)
   - #2e7eb7a: restoring last position only if not at start
   - #e4fa3ea: few fixes
   - #e9bfd19: playback improvements
   - #a32173b: fixes/improvements
   - #85ff243: various fixes/improvements
   - #6d71267: video-related fixes/imp
   - #d4262bf: minor fixes
   - #6481bed: fixes & improvements with the new queue system
   - #8d2eb77: various fixes/improvements
   - #10bdb26: minor improvements
   - #468e749: catcher logs
   - #08486fb: various fixes & improvements
   - #6d9dd5b: various ui tweaks & improvements
   - #44eeed8: miniplayer seek ux improvements
   - #a14b474: theme updates fixes/improvements
   - #9e6a642: minor fixes
   - #2ac96fb: sorting .tolLowerCase()
   - #7c8fd64: extracting empty metadata fields from filename
   - #7844631: miniplayer seeking on tap
   - #95f7e7a: minor ui fixes/tweaks
   - #5bd32a7: minor changes duration of track class is in seconds now
   - #9451ea1: redesigned some menus
   - #5f387ed: hero animation for multiple images parallex

- fix:
   - #5db83ea: split config real-time update inside isolate
   - #da5288e: saving track last position on all possible occurrences
   - #29a8b31: color not updating properly after queue reorder

- core:
   - #f443ae0: switch to ffmpeg_kit critically needed due to crashes caused by media_metadata_retriever
   - #77d59d1: loading queue & history in chunks faster fetching but in cost of performance
   - #5e0593e: switch to better_player
   - #b83055b: dimensions internal logic change this fixes unexpected behavior, as it now calculates on demand not on navigating

- perf:
   - #09c8262: colors logic
   - #9f0a185: loading history/queues/initial files in isolates huge leap, isolates finally listening to me
   - #019f213: jumping to same queue item will not replay will only seek to start
   - #9191c5c: refactored language converters to single map
   - #6d8d539: im no longer limited by tech of my time switched waveform generation to amplituda
   - #8e8e448: yt history matching (tracks.length)x faster lookup when using link as a match type
   - #26b1496: prevent reduntant waveform rebuilds
   - #78ed75e: generating from moods logic rewrite
  
- hotfix:
   - #698eb4d: sleep timer for tracks
   - #4a10645: miniplayer unresponsive after removing track
   - #53f2deb: notification update

- code:
   - #51a59a5: refactor fixes smol issue with backup items
   - #2d575de: rewrite audio handler queue logic in preparation for future videos queue support
   - #595aee9: refactor
   - #f411684: minor refactor
   - #7168924: refactor track classes -> this addresses & fixes few issues and improve general readability
   - #0e07e86: video logic complete rewrite this comes with new metadata retriever (width, height, dur, fps, bitrate, etc..), support for continuing youtube downloads, and many other improvements
   - #08602c8: classes refactor
   - #73a8923: refactor tags dialogs
   - #3589305: massive refactor switching to faudiotagger significantly faster multiple tracks metadata editing


## 18/07/2023
### 🎉 New Features:
   - #b662691: support removing multiple tracks from playlist at once and other fixes
   - #026252a: import to history only between time range
   - #46cbe7c: handle adding queue while loading queues files
   - #c43ce52: favourite button for queues (soon will be used to auto-delete non-fav queues)
   - #5216a73: skip silence
   - #e57677e: generate tracks from similar release date
   - #c1b933c: toggle jumping to first track after finishing queue
   - #5b2a27e: preview track in trackInfoDialog
   - #f7813cb: notification when adding source to history
   - #185d0ed: jump to day inside history
   - #364c989: new playlists logic, history days, (history.length)x faster startup. startup will not wait for history, history is categorized by days which will sync load along with startup.
   - #8b95e6d: tapping inside scroll track will not scroll anymore
   - #2963885: tiles animation when changing grid count
   - #3daa560: button to scroll to track after go_to_folder
   - #ce03cca: option to seek by percentage

### 🛠️ Bug fixes & Improvements:
- fix:
   - #02d6501: miniplayer non-accurate seeking and other improvements
   - #dbf318e: latest queue not always being loaded + minor refactor and startup boost
   - #87b666e: dimensions
   - #b9028f9: Custom onWillPop for Dialogs
   - #daaffe9: cards dimensions not being updated for search page
   - #961b6c7: calculate all item extents in history for instant scrolling (ex. when tapping on listen)
   - #4c41945: ui bg fix when navigating
   - #9213142: media filter bar not hiding on close
   - #c66d40c: hide reorder icon for history & most played playlists

- chore:
   - #e0b8e20: display track number instead of index in album page
   - #e769829: minor refactor
   - #627b0fe: tweaks and fixes with navigation system & ui
   - #067ad9a: various fixes & improvements
   - #6aa1a8c: perf & ui fixes
   - #f162f35: various ui tweaks
   - #00d6596: fixes & perf improvements
   - #9576584: mostplayed sorted by last listen if listens are equal
   - #6f10e8c: support if history loading took more than 20s (â›â€¿â›)
   - #b7f2165: ui colors tweak
   - #bc199a9: disable staggered animation when changing grid size
   - #05a51e4: new color api (used, mix, palette). (opens the door for user choosen colors)
- code:
   - #97fc150: refactor buttons
   - #d966051: refactor tracks generator
   - #e11cc0b: refactor print functions
   - #5607cb2: refactor using new extensions
   - #4d35b4f: refactor, expose miniplayer and fixes exposing mp allowed for minimizing it while navigating
   - #48c92a5: refactor comparables
   - #dc7e3be: refactor searching & sorting
   - #4017575: artwork widget refactor & perf
   - #55b1de7: refactor, dimensions class & performance boost all calculations are done on demand, no more calc within cards/tiles
   - #3788866: refactor InkWell widgets
   - #4394d24: queues logic rework
   - #3791622: new return type for getTitleAndArtistFromFilename()
   - #cd9e677: project refactor using new extensions
   - #e0b0fc3: refactor ExpansionTile & ui fixes after upgrading flutter 3.10.5 broke some stuff
   - #1b91698: refactor search field controllers logic
   - #9fa7903: 21 new extensions
   - #5bb45d9: refactor + save scroll position for tabs
  
- core:
   - #9197176: various fixes & improvements selection container, adding to queue when empty, renaming playlist, and more
   - #9118031: various fixes and improvements history days are now accurate, faster startup, fixed recommended tracks algorithm
   - #e8fab4b: routes are now saved as reference, not real classes, this heavily boosts performance especially for pages with lots of tracks
   - #db78e13: migrated to Flutter 3.10.5 & Dart 3.0.5
   - #2cfedac: lazily initialized static methods
   - #42c3f9b: new navigation system & massive refactor i.e. performance boost

- perf:
   - #b42e1a0: histroy track listen navigation. going to a listen from within histroy page will only jump to it, no new route.
   - #a2c2f9a: improve recommended tracks generation algorithm
   - #82ed598: artwork won't rebuild redundantly


## 07/06/2023
### 🎉 New Features:
   - #0d12d94: remove source from history
   - #a072639: new sorts
   - #f514fc6: sleep icon on sleeping track inside track tile & performance imp
   - #6325045: new listen counter when seeking backwards
   - #de2fd57: restore last position (configurable)
   - #6e17e74: indexing no longer required for separators
   - #60ee548: long press image to save to storage
   - #99254f1: stats for each track & generate from rating
   - #319b2d3: generate tracks from modes
   - #aa8c461: total listens inside track info dialog
   - #fa61e7a: remove duplicates & insert after latest inserted
   - #634c41d: artist/genre separators blacklist (unsplit)
   - #5931032: info dialog for track
   - #d02328a: import lastfm history & yt match by title
   - #a7f5dee: support deleting queues
   - #0519a30: display audio format in miniplayer
   - #8dd6ffd: enable/disable auto play on next/previous
   - #886ff72: support playing multiple external files
   - #05405e2: track source for playlists
   - #10ba0cd: enable/disable scrolling navigation
   - #0522626: play android shared files
   - #3474ebc: display track number in album page
   - #47739ea: import youtube history to namida
   - #9bc80fc: search page completo
   - #822160f: generate tracks from time range
   - #65a79f1: youtube page & miniplayer
   - #aef4e3e: enable/disable miniplayer particles
   - #a1d00a9: share & play all in dialog
   - #62152b9: algorithm for generating related tracks
   - #4abb8b7: choose cached videos to delete
   - #a5b05b5: option to disable bottom nav bar
   - #3f6a537: dismissible queue tracks, stability & ui/ux improvements
   - #2f8a9ba: dismissible queue & playlist tracks
   - #43f49ec: search text cleanup option
   - #17a22ff: repeat mode (none, one, all)
   - #23df59f: tapping on pos/dur will seek forward/backward
   - #d43c421: shuffle queue & scroll to current track
   - #c902d4c: reorderable queue
   - #3dc20d8: select all now selects the current tracks
  
### 🛠️ Bug fixes & Improvements:
- chore:
   - #aa6876f: separator extension & refactor
   - #1471257: small refactor
   - #8646ca8: widgets rework & refactor
   - #5a90cae: pages improvements
   - #2795637: miniplayer improvements
   - #d9b56bb: massive improvements and refactoring
   - #c485dfe: constants variable names change
   - #49af0d2: moar fixes
   - #49ba554: small fixes
   - #766aefe: update dependencies
   - #c640461: fixes fixes fixes and refactor
   - #9d63ee6: new design for default playlists
   - #b57a543: folders logic wasnt perfecto so i perfecto
   - #276cd73: migrate to dart 3
   - #3a1c301: update dependencies
   - #1ff87eb: guide for youtube history import
   - #d568af4: refactor
   - #14deafa: improvements & fixes
   - #8d1a6e6: improvements & fixes
   - #bf19a46: switch to sembast
   - #5e7ed9c: folders logic perfecto
   - #62a5a9c: classes for media types
   - #1ae1c98: play-all buton for album card
   - #3f0d83f: fixes and improvements
   - #24724f6: improve auto extract tags from filename
   - #8d154da: improvements and fixes
   - #cb4f3fd: drawer more items & design improvement
   - #aec65a2: coloring & notification improvements
   - #cf19deb: improvements for video lookup & playback

- refactor:
   - #59f3cd6: separate file for converters extensions
   - #100bf3d: project refactor
   - #01e3c1a: code refactor
   - #40ba7ca: audio handler complete logic rework

- imp:
   - #99c424f: lastfm import handles missing dates
   - #7196cb6: playlist modified date + improved methods
   - #23e1be7: multiple tags edit rework with progress tracker

- perf:
   - #4ec032f: settings files min 3s between saves
   - #996079c: startup fast asfboiii
   - #5fd73ae: optimizations
  
- fix:
   - #d02e50d: deleting queue from storage
   - #a56d92c: a56d92c smol fix
   - #77665ad: keyboard hide decison
   - #1ff4a07: juuust a small fix
   - #42faa11: fixes & stability insurance
   - #3d49a5a: fixed static library tab not being retrieved

- dialog:
   - #b07cfb1: option to hide unknown fields - repeat for N times - insert after latest inserted - add more from this (media) - extract feat. & ft. artist - major refactor and core improvements - tons of work under the hood, lots and lots of performance improvement and drinking tea with buggies
- code:
   - #ccdd3e9: insertSafe() & insertAllSafe()
   - #06334ae: performance goes brrrrr (also adios sembast)




## 14/3/2023
### 🎉 New Features:
- Lyrics Support (currently fetched from google).
- Party mode for miniplayer, applies edge breathing effect, colors can be main color or the palette colors switching making a party-like effect.
- repeat mode (none, one, all).
- tapping on position/duration will seek forward/backward.
- reorderable queue, with shuffle & scroll to current track buttons. 
- "select all" now selects the tracks in the current page only.
- option to cleanup search text, symbols are spaces are neglected.
- auto extract tags from filename.
- set a minimum value (Seconds or Percentage) to count a track listen.
- fade effect on play/pause.
- History & Most Played Playlists.
- Track Play Mode, play (Selected track only, All Search Results, Track's Album, Track's Main Artist, Track's Main Genre).
- Drawer Navigation System.
- Option to Display Favourite button in media notification.

### 🛠️ Bug fixes & Improvements:
- Lots of performance & stability improvements.



## 28/2/2023
### 🎉 New Features:
- Animating Thumbnail, a cool feature where u get your thumbnail animating along with the music
- Peristent Queue System
- Multiple Tracks tag editing support
- you can now clear track related files (video, image & waveform cache)

### 🛠️ Bug fixes & Improvements:
- faster startup when there is lots of queue cache
- random playlist generation algorithm
- fixes for miniplayer dimensions
- fixed waveform, now it stays relative to screen width but more hotter and without cropping
- ux improvements
## 24/2/2023 [#e82f597](https://github.com/MSOB7YY/namida/commit/e82f597c6572f620a86206cbfba0da1e76cc3e08)

### 🎉 New Features:
- Added Miniplayer (thanks @55nknown).
- Audio Playback with background notification.
- Play Next & Play Last.
- Video Playback Support (Local and Youtube).
- Audio Tag Editor.
- Option to Respect .nomedia.
- Backup & Restore Settings:
  - with option to set custom location.
  - choose what exactly to backup.
  - Smart backup restoration, either applies the most recent backup, or lets u pick up a backup file. 

<br>
<br>
<br>

### 🛠️ Bug fixes & Improvements:
- code refactor.
- suggestion to set thumbnail size as height when enabling [Force Squared thumbnail].
- New initial set of actions in Track Popup Dialog to fit with the latest features.
- Lots of improvements and fixes (really)
