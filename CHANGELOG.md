# Namida Changelog

## 08/07/2025
# v5.2.6

### 🎉 New Features:
   - be06693: redesign for widescreen support (landscape & desktop) and better library items scaling ref landscape #202 #457 #275 #255 desktop #14
   - 6a9731c: very cool side navbar for widescreen
   - 50e24ba: advanced sorting for tracks
   - 3d3d0ad: allow ignoring fetching lyrics if embedded lyrics started with "IGNORE"
   - de3612b: miniplayer is now optimized for all screen sizes & landscape - glad i made it out safe and sane.. ts was a nightmare
   - afed5ea: separated disc sections in album tracks page (when first sort is disc number)
   - da6b07e: update icon in appbar (shows latest version with changelog)
   - 77f0429: a button to select cached files that has a copy in local library - while choosing cached audios/videos to delete
   - 87de5e6: auto count per row based on screen size for grid layouts
   - 4385f6f: glow/ambient behind video option in fullscreen
   - 62cc47e: support EXTALBUMARTURL in m3u playlists ref #536
   - aa3dfd3: vibration modes (none, vibration, haptic feedback)

### 🛠️ Bug fixes & Improvements:

- fix:
   - 96c1652: empty queue view in miniplayer
   - abf1f6a: media session be tweaking since v4.9.8 ref #351, #531
   - 7146f15: not removing duplicates when playing yt history day
   - ea711a3: slight fade when restructuring queue (playing same item in another queue)
   - 860afe8: shorts not being hidden properly ref #548
   - acddf58: settings search not hiding after pressing a library tab
   - 5ca7bbb: ensure thumbnail file has no illegal characters
   - a59aab5: bottom search icon causing search menu and search bar not syncing
   - 3110aea: yt mp back button not respecting inner states
   - 3771b1f: long press for yt miniplayer action buttons
   - 21dae50: items visibilty decision in dialog
   - ad0204c: player sometimes not stopping while switching yt/local queues
   - 764c6a3: sorting in file browser now ignores letter case
   - 1cb2974: downloaded audio+video containing audio only
   - 238cf59: cool fixes ref #604
   - 46b9f45: smol fixes
   - 97f7cfb: smol fixes

- core:
   - 313904e: internal player improvements - https//github.com/MSOB7YY/just_audio/commit/1447b03eb494bb74c8d93fd165ec3478831b83aa (catch texture exception to prevent crashing & update media/ffmpeg extension versions to 1.5.1)
   - 20e1ca7: use `package:http_cache_stream` for cache & streaming - this allows using any player with disk caching, required for windows support with different player
   - 83d86b2: folders navigation system rewrite - finally works as intended and for both platforms ^^ (4th rewrite btw)
   - 6777590: refactor backup path resolving mechanism to support cross platform backups - and fix issues discovered along the way
   - 2b8004a: rework replay gain to use loudness enhancer by default - can be set to (none, default, loudness enhancer, volume)
   - 6547859: better yt download error handling & reporting

- chore:  
   - 53b3299: confirm before dislike
   - 0a14e1a: final cleanup & tweaks - center plain lyrics text - improve history jumping - fix wrong "play when ready" after removing item from queue - fix yt miniplayer wrong padding - others
   - bfe604a: use wallpaper accent or primary color instead of secondary scheme
   - 082d1e0: prevent accidental queue swipe up when performing home scween gesture
   - 7297467: tweaks for widescreen
   - ab2425b: more tweaks & fixes for widescreen
   - 60ec024: hide endcard after `200 ms` of pressing (not instantly)
   - 54e3a53: better artwork cache mechanism with better hero effect
   - c89052c: better count per row mechanism (with long press grid icon to show options)
   - fc7dffc: ui tweaks and fixes - better artwork fit in yt player - (windows) prevent display video by mistake in some case - proper width for theme modes container - disable button while removing sources from history - text overflow for bottom nav bar - (windows) better hit test for mouse region in some widgets
   - 7a25216: more responsive ui tweaks and fixes
   - 41b5b48: always apply my settings at startup rip my cached vids
   - e89e40c: more responsive ui tweaks
   - c9a8563: change default artwork cache from `0.8` to `0.9`
   - 077e0cd: display yt thumbnail icon only after image fetching fails
   - 16ccc99: allow unlimited queue length in all places (except pressing track tile in tracks page)
   - d4e401e: update packages/cleanup/fixes/etc
   - 2ee7e71: put empty mixes at end if found
   - 2dd584c: widescreen ui for channel subpage
   - bb8701b: auto fetch qualities when opening menu in local miniplayer
   - 286dcf1: ensure backup location exists before doing backup-related operations
   - cecea94: better immersive mode decisions
   - a6076e0: update edit multiple tracks logic to "disable" dismissed tracks instead of "removing" them
   - a67d7f1: final cleanup - fix ffmpeg windows logic not reporting failed executions - adjust RepaintBoundary here and there - more refinements for widescreen (subpages info box & channel subpage & dialogs) - replace `BackdropFilter` with `ImageFiltered` in many places (means performance goes brrr for blur effect) - don't clip glow so it looks cooler - tweak artwork glow to be enabled in more places - small design rework for mix dialog - prevent pull to refresh while dismissing track tile/etc and vice versa - add friction effect to fade dismissible widgets (swipe tile to action) - miniplayer performance improvement - other fixes/tweaks
   - 5df5bbf: dynamic page color for album/artist pages now follow "auto coloring" settings
   - bd531a5: album card design tweak (smaller font size & transparent button based on size)
   - 129a4ba: ui updates & optimize blur performance
   - 0444ed0: play live videos
   - 127bf19: dont limit speed in volume control page ref #605
   - 4b41293: display title/artist in lyrics fullscreen page
   - f89c4b5: allow editing multiple color palettes at once
   - faaadaf: detect takeouts inside zip files when importing history
   - d679d3e: minor changes
   - 0508dd5: tracks path inside m3u now have better relative path - obtained by finding common parent for all tracks, then removing it from each path
   - 5997fc5: percentage circle for cache videos info re-extraction
   - 663b136: better and more helpful playlist download page - fix not loading all videos before opening page - better error message - now displays which videos are already downloaded properly - automatically selects non-downloaded videos when opening/updating group name (unless changed selection manually)
   - 793658e: swipe actions now apply to yt notification card
   - a3adeb4: better download sheet loading shimmer handling
   - bd8fb5e: final adjustments
   - b424109: improve swipe up on video to enter fullscreen mechanism for yt miniplayer
   - 788c07f: improve stuff in fullscreen video (adjust image size/safe area/consistent padding/hide system volume/etc)
   - 84fb7bf: improve miniplayer items dimensions
   - 0d8d116: improve lrc view logic and boost its blur performance
   - 7721d19: improve account login ref #504, #559
   - 7ffd3ef: improve channel info resolving
   - 86384a6: improve yt link and id matching - now catches any smell yt related woof woof
   - 80b14fd: some ui updates/fixes
   - 38edc19: ui fixes/updates
   - 7fc6a4a: more adjusments & fixes
   - be1323e: small ui fixes
   - d35bb93: small tweaks ref #512
   - 13e30b4: minor tweaks
   - 801e846: some fixes and tweaks
   - d05b37e: minor fixes/changes 
   - 956ca5b: ui fixes and tweaks
   - 0a81442: more ui tweaks and fixes

- perf:
   - dede8e6: optimize loading circle opacity performance
   - 6a8746c: hide yt mp content when queue is fully expanded
   - b5f5208: use `packagerhttp` for network requests
   - 797351a: more efficient and reliable extracting paths key
   - 6db31c0: refactor `num.clamp` to deticated extensions
   - b8f1fc9: improve yt offline search speed (drastically)
   - b3b1333: slight improvement for yt thumbnail widget
   - 719e953: remove hero fade transition - this might cause slight image flicker while opening dialogs/pages but we will see later, currently it seems expensive
   - 22281ce: slight performance imp for miniplayer
   - 5041a6b: improve video endcards performance
   - 6c05699: major ui performance optimizations (miniplayers/glow effect/opacity everywhere)
   - 4612cac: optimize app blur when opening dialogs
   - 7c94afb: optimize yt miniplayer animation
   - 109d815: slight improvement for miniplayer animation - by not killing appbar & navbar when miniplayer is expanded
   - 5db0a8b: improve player color updates
   - 4c1b405: major performance optimization across app and startup time reduction
   - 1c403cf: improve latest queue saving


## 07/03/2025
# v5.0.4

### 🎉 New Features:
   - c92a8a3: headset buttons (single/double/triple)
   - 667e15a: notifications for windows with option to control download notifications ref #14
   - f1cbec6: show/hide keybaord when dragging upwards/downwards on search floating action button
   - ddd53e9: setting dim duration to 0 will keep miniplayer always dimmed
   - bb2b07a: system level brightness in fullscreen video player ref #155
   - cd432d1: simple data saver mode (wifi & mobile) - with icons to indicate why a video was not fetched (blocked by cache/no connection/data saver)
   - 934e438: basic home screen widget & quick settings tile ref #168, #243, #438, #468
   - 515f71d: gentle play, adds item next and play instead of assigning new queue - currently applied for yt section videos, mostly when pressing single video like in search/home/etc
   - 0fdf533: display years in history page that navigate to the same day in that year


### 🛠️ Bug fixes & Improvements:
- chore:
   - c5f82d4: video controls reactive bg color for light bg
   - 15da6b3: prefer lyrics with duration closer to track duration
   - 2f53fa8: show checkmark in playlist tile when adding tracks - and rework logic (both local & yt) to show active checkmark only when all tracks exist, offering a "remove" action when pressed, otherwise it will add normally and prompt actions if there was duplicates
   - d53f42a: dont copy info if not available (?)
   - 384b582: attempt fix filename of specific thumbnail types
   - 2b7240b: copied to clipboard design tweak (now uses rounded design with margin like others, instead of squared sticky)
   - ed933cc: attempt broadcast queue info ref #351, #157
   - 4794247: update app bar icons animation
   - 47664ce: smol refactor
   - 4b59e74: improve shimmer in yt miniplayer & download sheet
   - b6e722c: improve search matching ref #465
   - 6319418: allow content provider paths in extension filter (while picking files)
   - b131b1c: supress account/membership errors and display in pages instead if possible
   - c99232b: refactor lrc view & scale it bigger to avoid thin border effect again
   - ec5cdb1: hide endcard instantly on drag and reshow on drag finish - old behavior relied on miniplayer height percentage which wasnt too good
   - 1039ece: sort network lyrics only if track duration was not modified (nightcore/spedup)
   - f1e3906: faster route animation speed
   - 05f1ec8: artwork scale setting is now a simple slider
   - 29035fb: refactor wheel sliders
   - ad8c7d3: pressing plus icon in horizontal list view will open history page on the last item - and refactor for history listen jump
   - b627d0c: allow liking/disliking videos without membership
   - d07e426: refactor vibration methods
   - 6ef27b8: live format info in edit tags dialog
   - b0c1d0e: few tweaks - rely on "play when ready" instead of "is playing", results in more stability when skipping next/prev - remove refresh button in video widget -refactor snackbar duration & less duration for "added to queue" snackbar - use package to show time difference in about page
   - 7249a94: apply on swipe actions for yt cards as well - this took shitload of refactor, but improved perf so yey - ref #333
   - 58c4568: improve tags extraction and fallback ref #480
   - 84cf942: add "open info" as track tile swipe action
   - 9da9709: change default on swipe actions
   - a4522ca: fully rely on "play when ready" instead of "is playing"
   - 048895e: move android files
   - e59b6a3: assign low res thumbnail to notification until full res is fetched
   - 3e291e5: ensure yt player doesnt play old media while fetching info of new media ref #234
   - a90aeee: ensure play when ready is not modified after switching queues
   - cf6d474: ensure resuming after queue is restructured (playing same item in another playlist/etc)
   - 93b47aa: pause and play icons for qs tile
   - 46ca092: formatting & cleanup
   - 675dc79: light theme for home screen widget
   - 663e295: few fixes - and revert to dart 3.6.0 bcz new formatter getting annoying
   - 7c3424f: allow monochrome colors
   - 5d786d2: improve theme colors
   - 497413b: limit home widget code to android & ios
   - be09f3e: remove lyrics fullscreen button & add a note on how to enter fullscreen ref #499
   - 38cc211: add note to indexer folders while media store is enabled
   - a0ec475: auto skip item only if "play when ready" is enabled
   - ea972d4: ignore wakelock errors
   - 06b0c46: open shorts in fullscreen
   - 2a06f4c: white pull to refresh icon color
   - 3e487e4: disable writing tags to audio file after getting cached
   - 2c9fc7d: clean up plain lyrics tags
   - 65648e3: attempt play video stream for shorts (data saver off & medium)
   - b06b360: restore last played duration for yt section too
   - 0a14e1a: final cleanup & tweaks - center plain lyrics text - improve history jumping - fix wrong "play when ready" after removing item from queue - fix yt miniplayer wrong padding - others

- fix:
   - 6eb266e: downloads failing after app restart
   - ad92592: notification artwork not falling back to folder cover
   - 96c0604: lyrics blurred view thin white edge
   - b19f7be: loading circle showing once yt miniplayer is shown
   - 26acfe7: yt playback and allow setting custom visitor data & potoken
   - 59f4c60: dim related stuff
   - a80bfb4: error message when stopping downloads
   - 3494baf: keyboard focus/unfocus when swiping up/down search fab
   - fe20b79: double pressing app bar icons
   - ac56f8d: allow returning faulty info when extracting instead of dismissing all of it ref #469
   - 5d737d8: audio/video thumbnails not extracting/showing properly ref #461 #474
   - 73ca3eb: blocked play/pause touches when buffering in video player screen
   - 14bfc7e: non-persistent scroll offset for comments page ref #491
   - a48f1a4: play when ready related stuff
   - eec799f: not showing minus sign in lrc offset dialog
   - 8f9ec31: showing old error when reading tags in edit tags dialog
   - e192699: tapping yt most played opening history..
   - d0a1bad: crash when leaving app before player start (happened when trying to access "is playing" status for pip entering, all before player is initialized)
   - 23c63fe: ensure yt miniplayer has correct bottom padding
   - 42c1e2d: dialog using old color
   - 1fb4b7f: not playing local audio for yt when there is connection
   - 5fec286: cleanup group name too from possible illegal path characters
   - 65939a5: duplicated audio cache entries
   - 90f5448: properly backup databases to prevent being locked after restored

- code:
   - f641e02: home widget colors api
   
- core:
   - 78d00cd: upgrade to flutter v3.27.1 & dart v3.6.0
   - 627115a: disable impeller rendering engine
   - 1dcdf32: lrc positive offset now means lyrics will appear sooner ref #467
   - a6739fd: some changes - better support for remote controlling (android auto/etc) - fix duplicate shorts in home page & related videos - fix displaying artwork for albums with  in name in notification
   - f6861eb: support archiving for windows (for backup & restore)

- perf:
   - eb8b543: improve file io sink

- build:
   - 6898ac0: update windows build files
   - c963608: increase build memory to 4GB
   - 048214b: set minimum sdk level to 24 (android 7.0)
   - 7153b03: upgrade to flutter v3.29.0 and dart v3.7.0
   - a3d8d23: upgrade kotlin & gradle versions


## 01/01/2025
# v4.8.6

### 🎉 New Features:
   - 719ead3: set artwork for playlists ref #324
   - 062378b: sort playlist tracks for local & yt playlists
   - 3f3ffda: fetch square thumbnail for topic channel videos - when downloading or when fixing thumbnails ref #212
   - db4da91: cache videos priority system - this is mainly for the upcoming missing videos info retrieval, where it make sures cached stuff of deleted/privated videos are not automatically deleted
   - 9e45bee: retrieve and display info & thumbnails of deleted/privated videos
   - a0a0586: allow setting cache priority for videos/tracks with yt id - can also be used to disable track video fetching
  
### 🛠️ Bug fixes & Improvements:
- chore:
   - 5ca5793: play all (reverse) button for history days
   - dc835a0: use dark bg for splash screen when in dark mode
   - e0658f5: include missing info db for yt offline search
   - 1eba91b: faster search page fade animation
   - 0a6c306: prefer using app bg color for video fullscreen light bg when specified
   - 2edde23: long pressing video button in miniplayer will show search button instead of "check for more"
   - 4eb4af9: adjust button color in pitch black and tweak minimum size
   - 8c594ab: update downloadAudioOnly setting when enabling/disabling video stream in download sheet
   - 31914ea: allow changing download filename builder in single download sheet
   - de391a9: delete empty downloads-group db on startup
   - 9dd26ae: spirce for kuru custom display first listen date for me
   - 032701e: smol right padding for miniplayer info
   - 95b4588: disable "write upload date as file date" by default for downloads
   - 7d60760: dont refetch non-personalized related videos if already cached
   - ac66d2b: rely on `accurateDate` in some places
   - 6831c81: ui tweak for backup dialog
   - 1889967: update delete playlist/queue icons
   - b879eee: dont show "fav" by default in video card menus
   - 6edf11b: update clear cache icons
   - 221b653: properly show info of privated videos on cards & auto set priority to vip if the info is missing or title starts with link (privated)
   - 5c2294f: display js player version in yt flags
   - 2d4b912: improve info merging while importing history & displaying title on video cards for missing info
   - 6dcd499: treat 1980 as faulty date instead of 1970, when dealing with file added date etc
   - 13da4d4: improve missing info related stuff
   - d4290dd: setting icon in appbar is always on right
   - 627a810: unfocus keyboard when opening miniplayers
   - 2018c5f: smol fixes
   - 19666b8: show sleeping track icon only when repeat mode is all or none
   - 725dc5b: do the unfocus keyboard in miniplayer states switching
   - 8d13893: pass theme to snackbar
   - cc96856: improve unfocus keyboard logic
- fix:
   - 90db311: artwork filename when "group by artwork" is enabled
   - 6a0ea28: parsing channel playlist tab at `packageyoutipie`
   - 45781b2: in folder tracks, update "index to scroll to" after sorting if was specified
   - 6c9bf3f: caching and retrieving of video description in `_YoutubeInfoUtils.getVideoDescription()`
   - a1e9dfe: possible empty first video id character when importing from playlists csv
   - ea5404b: theme colors of hosted playlists
   - 3354724: bottom icons padding in track/s popup dialog
   - bf116a3: not searching yt after entering offline search page and closing whole search
   - f3d069e: loading default group for download task and remove any leading dots while making new group
   - f7cf249: stuff caused by faster app load time
   - a151963: set replay gain for yt after enabling the setting
   - 95ce065: indices error while removing items from playlist
   - a3c3b16: displaying albums artwork having / in the name
   - 1f4d438: infinity loop eating battery
   - 3b15d89: merging download tasks after loading re 061deb0
   - 3d10050: not refreshing after toggling pitch black
   - 9fbb0fe: not refreshing lists after deleting tracks
   - da80a81: properly delete temp files in video clear dialog
   - b209c4f: saving/displaying wrong image in cache was noticeable with video playlist endcards
   - 6fd9394: video info card related stuff
   - 1ce99d2: duplicated offline search entires
   - 8c5ad42: empty search boxes
   - 18dd3c7: lyrics dynamic view timing (was reshowing late)
   - 55a197a: long pressing yt artwork wasnt actually saving it

- core:
   - e24898b: allow unlimited queue using any button except when pressing track tile - and remove duplicates when playing history ref #31, #245, #404
   - 4f69ed3: upgrade to `packageyoutipie` v4.2.0 - fixes playback issues and other stuff

- perf:
   - 161359a: avoid recolering the player whereas possible like when reordering items or when playing same item
   - 39d7aef: improve app startup time - by prepare most stuff concurrently on diff isolates - there is still overhead for copying data so the diff is not so huge thanks dart
   - 061deb0: no longer wait for download tasks to load
   - fab1f9c: auto close open databases after specific duration

- code:
   - 0cddbc1: refactor `_saveLatestQueueToStorage()`


## 22/11/2024
# v4.7.2

### 🎉 New Features:
   - dfaf5f5: local video library & playback this also includes - refactor for track duration to use as milliseconds not seconds - refactor for many indexing functions - rewrite of latest queue & other similar parts logic - use global `lastPlayedIndex` - improvements for home page loading - faster loading for latest queue (by disabling maximumItems check) - fix most played chips not being properly rebuilt - fix default color tiles not enabled/disabled properly - fix downloaded file not being added to library properly
   - 0280611: replay gain (normalize volume)
   - c0ace94: left & right swipe actions for track tile, ref #333
   - e210ece: use search floating button as submit beside closing search page (switches dynamically)
   - fe96401: option to disable personalized related videos
   - 7c6607c: show video endcards option, ref #227
   - 408a4ef: listen count & latest listen date in track tile info, ref #323
   - ff4632d: channel about page, ref #227
   - dec830f: recommended sorting when clearing video/audio cache files - follows a simple algorithm to sort based on both last access time and total listens
   - 8496541: yt downloads filename builder
   - 035a9e0: allow info builders for metadata tags too as well as filenames as earlier - added more parameters
   - 052bf9f: parse `description` & `synopsis` from metadata tags
   - 3ee9f43: basic windows support * includes - integrating ffmpeg/ffprobe executables - refactor `FFmpegExecuter`, `NamidaChannel`, `NamidaStorage` - rename `FAudioTaggerController` to `NamidaTaggerController` - refactor paths to use platform path separator - hide settings not meant for windows using `NamidaFeaturesVisibility` - small ui changes - build msix packaging instructions
   - e0cdb64: pressing "jump to day" icon will open with the current day at scroll position
   - cc09b8c: in history pages, display the nth listen on card top right, and cake when its first listen
   - 4ec2636: in homepage, pressing top recents or lost memories will now open the most played page with the actual date range
   - 884c126: auto extract download info for nightcore videos by relying on description, and add `genre` field for downloads
   - b5386d7: "first listen" as sort option & as optional info in track tile - and re-sort tracks list after history is loaded (if neccessary)
   - a364755: flag to add yt history to local history (merge) - and add icons for other flags
   - 3f524ab: option to specify delete or cancel for downloads (including groups)
   - d8f9b9f: folder tiles can display text if `.info.txt` file exists in the folder i made this one for myself >
   - 233da90: importing takeout playlists now supports whole directory with multiple takeouts, duplicated playlists are merged by default - also fix date extraction in playlists csv
   - 640bb62: yt channel tabs
   - 99eaea8: sort yt playlists, ref #227
   - 30521bf: add/edit/delete comments & replies, ref #227
  
### 🛠️ Bug fixes & Improvements:
- chore:
   - 1a34bbc: final cleanup
   - c1b3ad7: show original genre for track tile, ref #316
   - 85293ff: dont refetch pages after signing out
   - 580a36a: long press yt copy button to copy url with timestamp normal tap will copy url only
   - a2f2007: use monet icon for fallback notification & sidebar
   - 8582664: move "display remaining duration" setting to the bottom
   - fd8ba26: allow double tap lyrics gesture for yt while in local player
   - a244bae: fallback for channel id in yt miniplayer
   - 38215f1: auto set most played time to `allTime` only if `custom` was selected
   - 4595a7d: always show unavailable videos in playlists we may need to expose as a button later
   - fcee0ee: refactor internal playback to preprare for live videos (still not ready)
   - 6b825ac: small fixes - for track tile separator - nullable video stream duration
   - 00534b7: tweak popup menu animation
   - f7b6090: properly split moods using general splitter
   - c00c162: improve hiding controls mechanism for video container in yt miniplayer
   - 2c260f6: increase max video cache to 32gb & audio to 12gb
   - 29ba894: properly exit fullscreen for some endcards actions
   - 5aa8308: refactor opening video/playlists link - this came in need while implementing channel about page - added "autoVerify" for all intent filters in AndroidManifest.xml
   - 591581d: refactor views & subscribers to extensions
   - 3bf7c23: refactor settings related stuff to improve performance, now things that change frequently automatically are saved to separate file - fix 'dont show again' for battery optimization request - increase default video max cache to 8gb & audio to 4gb
   - 38ee6ac: few fixes
   - ec97084: allow precise speed/pitch/volume etc, ref #271
   - 4a71dd4: display multi language lyrics properly
   - ba5698f: big salsa - improve detection of short videos - recheck cached videos in quality menu after clearing cache - perf improve scrolling yt videos scrolling by not filtering existing files from cache map - fix reset _nextSeekSetVideoCache when needed - impeller disabled by default for now - improve stuff related to after deleting tracks - remove tags/rating/moods from ffmpeg tag editing while downloading - snackbar padding when there is a button - allow refreshing patreon/coupon & sign out & properly notify about expired token - add star history in readme
   - 0decad9: allow android auto to detect app * not tested
   - 9ee8f27: improve icons touch area, ref #192
   - 14f1bc1: fixes and cleanup
   - 1389d46: tracks generated by date range are now sorted by listen count in that range
   - 18279e6: allow opening info dialog for non-existing tracks
   - 81ce518: fixes tweaks fixes tweaks - enable replayGain by default - wont auto modify volume when playing (bcz replay gain with crossfade) - tag extraction not putting original path - use `fileSize()` instead of `sizeInBytes()` - missing tracks screen stuck bcz _m3uPlaylistsCompleter aint completing - fix m3u files with empty lines causing duplicates - thumbnails active request ids count not accurate (pls never use `value++` again for maps - sussy reset volume/pitch/speed not respecting replay gain - force home screen supremacy mix to be at least 10 tracks - reduce drawer tiles v padding - wrong video when playing yt notifications - refresh track tile when date/hour format changes
   - 3624300: rework track clear dialog this also includes - logic rework for managing and clearing video cache - add clearing cache tile in all video cards
   - 0df242c: some tweakies - fix resuming after interruption then pause manually - improve playback buffer - close video stream properly when selecting audio only mode - display full folder path when similar folders exist - code remove non-used landscape fns - improve onboarding screen glow bar - change default colors - improve miniplayer top right menu icon hit test - build add profile buildType - doc add replay gain to readme
   - 3e28717: add auto coloring as a performance factor
   - f6e9123: rename "kps" to "kbps"
   - f2d7d33: more checks for race conditions in `onItemPlaySelectable()`
   - 86cc911: show "share url" in all video cards
   - 7d0612a: migrate for `package:namico_db_wrapper` v2.5.0
   - 884f887: cleanup
   - 0d6bb55: hide "remove from playlist" in playlist dialog
   - cea3a3b: more horizontal allowance for pull to refresh
   - afc35fc: smol ui change - refreshState instead of setState to always update info in channel subpage - show tooltip on tap when pressing volume bar while replay gain enabled
   - 96ac21b: improved single download filename logic
   - a6a6804: add yt flag to force refresh js player
   - 4539ab4: allow adding/removing videos in a playlist & creating playlists without membership
   - 8efe0a6: refactor some parts
   - 30d9cc1: optimize and fix most played subpages + yt horizontal list & history not refreshing properly on startup
   - 75c3715: some ui changes
   - 0fe11f5: improved missing tracks loading progress details
   - f4d92ec: copy instead of share in video menu - press to copy video link - long press to copy different stuff - share icon in right part
   - 07b15fa: add clear cache button to snackbar when video error occurs
   - 146b3ac: ui tweaks
   - a648414: allow importing multiple history files at once (yt & lastfm)
   - 950447c: download group for single videos inside a playlist is set to playlist name by default
   - 1b87a20: save group download options across sessions
   - 42ecb21: cleanup & shi
   - 69c2b07: try split track/disc number before parsing it (like `2/16`)
   - 5b55900: when updating directory path, add it to indexer folders only if it or its parent doesn't exist
   - 555ddd7: fallback artwork to a yt thumbnail if exists
   - b499b43: sorting folders will prefer first number after `Music` in a pattern like `Music 12 - 2024` instead of the last number which would be 2024
   - 2e12e4d: tweak download sheet initial quality & group - video will be selected only if audioOnly disabled - for other video cards in a playlist, initial group will follow playlist name
   - 1302795: ui tweaks - maximum width for snackbar button - bigger buttons - in track info dialog, put gain info at end + adjust title padding so that text is aligned with the icon - adjust padding of expansion tile to align with list tile in dialogs/etc - dont re-light a dimmed miniplayer when changing tracks - adjust padding for video cards in channel home page/etc
   - eae8af0: change default client to web
   - 8146d51: fallback info for video page
   - 352b86e: fix info extraction from description and make it optional
   - e4080fa: dont depend on playing id for mix playlists in related videos
   - b541bfe: rename "flac" to "FLAC"
   - 636fcd9: more info about copied yt history to local
   - dab4226: ui tweaks - snackbar title-subtitle padding - snackbar padding with a button - history cards thumbnail padding
   - d842499: pressing play button when playback is already finished will now skip to next
   - b09c533: some fixes - using cached personalized related videos when acc is signed in (not the opposite) - m3u playlists path parsing - fix some equality checks - add delay for showing snack error when no network on `initState()` - failed tag edits will not cause the progress to stuck
   - 6cb8756: apply my settings on first start ^^ hehe
   - c4ffe59: disable media store artwork fallback when not using media store bcz it can generate non-accurate artworks
   - ecfbb7e: ui thingys
   - 92b81be: fallback info for yt miniplayer
   - 64f83d9: re-design yt offline search results to be horizontal - this also eliminates some code that differentiate between 3-result page & full results page, making everything unified and tied - increase timer to dispose offline search resources to 1 min
   - 14817d3: internally manage skipping to next when playback finished
   - 12c7d91: ui tweaks - yt notification separate title & channel - bigger expansion tile in some places - use yt thumbnail for cached items list
   - f4e706f: improve details extraction for yt playlists import
   - c05a630: dont display shimmer when info available in yt miniplayer
   - e898206: fallback for channel thumbnail in video cards
   - 1e9389d: refactor waveform scale map to list - allow offset for waveform scale list
   - ac8505d: rename default playlists when downloading
   - 5c14e30: ui fixes - duration not refreshing in miniplayer if required - yt miniplayer not having proper padding initially - video quality menu around whole tile in dl options dialog - show more format info in local miniplayer video streams - displaying that audio is cached even tho cache list is empty
   - 66cc92b: disable `jumpToFirstTrackAfterFinishingQueue` by default

- fix:
   - 312b12a: pull to refresh
   - b19e94d: lyrics not updating after coming from fullscreen
   - 7041dce: splitting artists/genres with blacklist the issue used to happen mostly when a blacklist is exactly the same as the artist/genre, with no additions etc
   - a8ee174: android 12 splash screen
   - 3021865: white screen when trying to reorder 2 items at the same time like bruh #315
   - 4e153b1: pull to refresh not detected
   - a9c5be4: sublists scrolling
   - e466fe5: pull to refresh stuck in some cases
   - bfefde5: getting yt account info after login
   - 2831fe6: include assets
   - 6204670: tapping album in go_to_album section
   - 84f561b: playback decisions with `_playWhenReady`
   - 6ca25fd: track tile `playCount` & `latestListenDate` not refreshing properly, ref #323
   - bfc574e: theme not refreshing after toggling pitch black setting
   - b6ec9a4: playing on next/prev when enabled
   - da6e3b3: keyboard showing after closing popup menus
   - 31b18b0: channel subpage overflow when displayed as fallback of video tab
   - 2040ae1: picking videos when source is specified
   - 8a756ee: track tile playcount not being refreshed, ref #323
   - d642e5e: allow opening external links on android 12+ - the universal wildcard is not accepted
   - 2acd505: history empty space when shorts are hidden - `package:youtipie` internal fix of shorts not extracting in some cases
   - 1d38cd0: broken js player code extraction in `package:youtipie`
   - 361963b: fallback artworks from the same folder they are now also more restricted, only known cover names will be picked instead of fuzzy matching, ref #338
   - 5263714: smol bugs
   - 889e9ff: displaying total duration on cards
   - 4cbc579: picking files with specific extensions using native file picker
   - e757eaf: description tag extraction fallback
   - b148aa6: not using dark color when auto coloring is off
   - 156742a: parsing relative paths in m3u playlist, ref #342
   - b4f6e86: pasting video id in yt offline search now brings the video
   - 365e68d: bottom padding in yt downloads page
   - ac434e6: albums in artist page are now sorted like the albums page
   - 8d598a3: false check of playback interrupted
   - 35bd5f6: refresh everything after indexer (separators/extract feat artists) change
   - 86faa34: playlist related stuff
   - c97e9b7: initial value for some ui parts like loudness enhancer
   - 044622c: volume mute when pausing and switching item quickly
   - 8a78327: not resuming after 7 seconds of track failed play dialog
   - cc3ba45: library sections (album/artist/etc) not ignoring text case
   - 38b4cc2: notification queue start index not accurate when there are comments this time we needed to check if the comment will affect the index or not while reversing the list
   - 5cc8731: auto sorting of recent listens in home page
   - 9c13272: channel subpages wont display empty items when failed to fetch new items
   - 0ad1425: fallback to low res thumbnail if failed
   - 424a36f: most played page not refreshing when changing time range
   - 0266cd5: possible wrong indices while downloading playlists
   - 68c7f88: download related issues - downloading after clearing group - pausing group and resuming causes to ignore audio_only setting - wrong playlist indices in some cases
   - 2be230f: some fixes - library pages sorting - sharing empty log file - yt local playlist items not being dismissible
   - 97a7651: make sure artists/genres etc are splitted when tags are edited
   - 96631aa: thumbnail fetching and no longer saving thumb copy while fixing ytdlp thumbnails
   - cbaca0b: channel subpage not loading the first time was caused by unintentional disposal of the page by replacing their global key
   - 55771bc: editing thumbnail for videos was removing the video stream
   - 9c5805d: folders searching
   - eb7b9bb: indexer stuck while indexing (hopefully), also - accurate path being extracted - properly dispose event channel on android side
   - dc8f331: non-accurate start day when opening "jump to day" dialog in history pages
   - 8024f5b: download related issues
   - 23d742d: channels suggestion in a channel homepage not showing
   - 8b29e7a: deleting history day/multiple tracks in a day
   - 0508392: attempt fix for thumbnail downloading partial data and saving if connection lost
   - 0089b43: yt sign in, ref #321
   - bc0074a: silly mistakes >.<
   - 13a9f5c: duplicate playlists dialog showing on startup when m3u playlists are being added

- core:
   - e155c4c: prefer using hardware decoders for efficient power usage this is a tweak for ffmpeg rendering introduced since v3.7.0
   - d597b02: rewrite yt playback behavior
   - 0222ad4: improve tags extraction, ref $294
   - f7cc288: properly extract & use embedded rating/moods along with app-specific rating/moods and allow editing - editing app-related stats now edits the tags too. and vice versa, ref #294
   - 55594fa: save video thumbnails to their folder
   - 1ec99ac: change how yt videos are matched from filename now only requires `v=video_id` or `id=video_id` in order to get matched
   - a0fc75e: various fixes & tweaks, ref #342, #343
   - 25a229f: add `animatedTheme` setting, editable by performance mode - with other smol perf boost
   - 5dcd5cf: allow mixed player queue * this does NOT address - unified ui tile for both local and yt item - mixed selections - mixed playlists - mixed history - mixed cross-session saved queues
   - 240d00a: refactor search related stuff - running search is managed by a single `int` - slight improve search page checks
   - fd01506: better management for duplicated tracks/playlists addition (which applies to yt playlists section too, instead of just adding the missing ones) - this was done while doing the new merge system of importing yt takeout playlists
   - a16152e: allow choosing whole directory when importing yt/lastfm history
   - ab05c51: migrate tracks.json to database - and 10000000x improve performance of `_addTheseTracksToAlbumGenreArtistEtc()`, this can be noticed while (editing tags/reindexing tracks/playing external files)
   - 38aa558: add flag setting to explicity allow experimental codecs like av1 & vp9 - now webm is prefered over av1 - the process is done using `List<VideoStream>.withoutWebmIfNeccessaryOrExperimentalCodecs()`
   - 0cdc56a: allow unlimited cache size this will eliminate cache checking at startup so cpu relief yeyy
   - 1d77806: force request playlist fetching
   - 1bd172f: enable/disable "include videos" option
   - 94fcc5f: replay gain for yt section

- perf:
   - 32414e3: break early when getting cached playable audios for a yt video
   - e3791da: faster app startup time by ~1 second achieved by using sync methods. since most of the functions are executed on startup only
   - f07a978: use context for all `Obx`, `ObxO` & `ObxOClass`
   - 8bdea1e: spam `RepaintBoundary` across app tehe ;p
   - e68a461: optimize file extensions lookup this includes refactor for many parts
   - 61ebeeb: faster history/playlists/queues & others loading using for-loops instead of for-in the initial benchmarks showed 3x improvement for 80k history entry, tho this might be due to jit compiler, assembly shows that there is a difference anyways we stay safe
   - 7063e7c: `StringBuffer` for building lrc obtained from search
   - a4b2f9e: async cache read for yt pages
   - 9eaefe6: migrate download tasks to a db
   - aadf432: refactor download tasks page to make it faster lists are now lazy built since we got rid of `ExpansionTile`
   - 2ef6cd7: migrate track stats to a db
   - 48149b7: smol optimizations for history importing
   - 694066a: faster playlist download page startup no longer calculating files count in each download subfolder
   - d51ad94: significant improve for indexer missing tracks page loading
   - c093e6e: use async db operations whereas possible
   - c55053b: elimiate possible lag for yt offline search & yt tracks generate dialog this was caused by huge backup info map being copied, now we load a new one in the isolate which takes longer ofc and fix searching after search thingy
   - c8aea7a: cache yt info functions like `getVideoName()`, `getVideoChannelName()`, `getVideoChannelID()`, etc.. usually they can be cached in `tempVideoInfosFromStreams` but this ensures that info obtained from database is cached, providing faster cards builds, etc
   - 721bf5a: rewrite `_addTheseTracksToAlbumGenreArtistEtc()` making it significantly faster and more reliable eliminating possible related issues
   - 4d1d9ff: use `RawReceivePort` in some places
   - 735d0d1: migrate video details to db - this also includes rewrite for cache checking parts and other functions making it more efficient

- code:
   - 341e5bd: refactor equality checks
   - 11597e3: refactor hashCodes
   - 3bad76c: use `Enum.name` instead of `Enum.convertToString`
   - bef2981: refactor `YTWatch` to use raw date millisecondsSinceEpoch
   - d993879: give PlaylistManager<T, E> what it wants

- core(windows):
   - b87cd4d: waveform support

- git:
   - dc78236: stop automatic build on push
   - 80a7674: improve issue templates

- build:
   - bc03ee3: upgrade to flutter v3.24.0
   - d592e7a: depend on package `lrc` fork, ref #294
   - 1a088c5: add windows directory
   - 49e98d6: bump version (v4.7.2)


## 05/08/2024
# v3.8.5
### 🎉 New Features:
   - 9e3a937: reactive folder scroll icon after pressing "go to folder"
   - 06be631: undo  player queue track dismiss
   - f4373fc: undo for yt queue dismiss
   - 8c450fd: custom dialog on pressing performance mode which also allows changing artwork cache multiplier
   - 31af954: lyrics for youtube (only when youtube-style miniplayer disabled)
   - a5badc2: sort folders ending with numbers manually this allows folders like `Music 2` and `Music 12` to be sorted properly based on number not text
   - 0647e83: long press favourites button to add to playlist in miniplayer, ref #223
   - dda4ca6: "go to channel" icon in track dialog when track has youtube id and channel id
   - 995eba0: add "mark_video_watched" as a flag in youtube settings
   - eb651ef: expose innertube client as a flag in yt settings
   - d1cdc2e: flag to enable white bg for videos
   - 6812f61: flag to disable dim in light mode
   - 4a1027a: support play alac/ac3/eac3/dca and other formats ffmpeg is now used to play (vorbis opus flac alac pcm_mulaw pcm_alaw mp3 aac ac3 eac3 dca mlp truehd)
   - 4006adb: allow importing m3u playlist as normal playlists - and expose auto importing of m3u playlists - this involves redesign of playlists page header closes #217
   - 9f521e9: delete tracks permanently from track advanced dialog, ref #66
   - 51f4f6a: always expanded searchbar option
   - 268ec9b: auto start radio when enabled, adds a mix playlist automatically when playing a single track
   - dfb5dc5: add mix playlist button in add_videos dialog in yt queue. this introduced new InsertionSortingType.none
- feat(yt):
   - e82f32a: comments sort (top, newest) this required redesign for comments header, which required Widget implementation for PullToRefresh
   - 938af52: description and comments native style
   - 098a604: youtube login support comes with subscription and fixed feed, ref #227
   - c3adcd1: user notifications, ref #227
   - 02c9d8a: display red line under video thumbnails with user watch percentage
   - f462bce: list user playlists, ref #227
   - 3391ac2: comments like/dislike, ref #227
   - 5fd9a90: comment replies, ref #227
   - c3b6742: video like/dislike - this forced yt local favourite button to be moved to video menu as "favourites" button & favourites playlist tile inside add-to-playlists bottom sheet - also "Liked" Playlist name is reverted to "Favourites"
   - 34a10fe: channel subscribe & notifications this comes with across-pages safety, hitting the button in a place temoprarely disables other active buttons so damn cool oh ye and a sneaky lil fix, ref #227
   - 0addb27: list user history (horizontal list in playlists page & dedicated vertical page) this includes improvements for lazy list & changes for main fetcher page, ref #227
   - 2d12b32: mark video as watched works flawlessly with connection issues & accounts switching
   - dfeb7d4: control showing of shorts and mixes in relative places
   - f8c09f6: add/remove in youtube playlists - supports bulk videos too hehe - a promt while adding bulk (add all & remove old ones, add everything) - create playlist while adding - getPlaylistsForVideo allowed without membership
   - f017377: show channel watermark in fullscreen (optional), ref #227
   - 51a818d: allow saving yt playlists to online library
   - a632fd4: edit yt playlists comes with rework of many yt playlist-related parts

### 🛠️ Bug fixes & Improvements:
- chore:
   - 244fdd8: allow m3u8 to open with namida
   - 4dacb21: some (many) fixes n tweakies
   - 1491f50: improvements for artist/title extraction from title
   - 6cd441d: some tweaks
   - 356d68b: prevent backup/restore while related things are runnning
   - d3d32e0: add mono icon for monet themes by @sujxl24
   - 3bb2e12: increase default max video cache to 4gb muhehe
   - 4d431db: smol fix for video comments while fetching next
   - 9eed0da: prevent opening indexer missing tracks if related process is running
   - ebcb12f: better ux when updating tracks/dir paths by disabling dialog tap to dismiss and confirm button while updating
   - 5e4c3e3: various fixes & tweaks
   - 7c750b3: favourite button in notification now works for youtube
   - f0cd073: fixes n tweaksss
   - 00cae0f: various fixes & tweaks - fix thumbnails in notification (hf) - fix initialization for pullToRefreshMixin - fix tracks search list not refreshing after sorting - properly show remaining duration in lrc fullscreen (if enabled) - ui tweaks for channel page & subpage - properly use PublishTime date as utc
   - 1f7b860: cutie fixes
   - 49e9c55: pull to refresh in yt playlists subpage & other tweaks
   - c746c82: improvements for notification info
   - 6ac49c7: various tweaks n fixes
   - 0ebbcd6: tweaks & refinements
   - 57d437c: 𝓼𝓸𝓶𝓮 𝓻𝓮𝓯𝓲𝓷𝓮𝓶𝓮𝓷𝓽𝓼 
   - 89ed743: remove failed icon in youtube thumbnail the top right 'danger' icon indicating that no thumbnail was found
   - 21a476a: open external playlists directly - no more dialog to prompt action, this also speeds up things since it doesnt wait till initial info is fetched - some tweaks for playlist cards too
   - 8df7c75: force video thumbnails obtained by url to be saved in "YTThumbnails" instead of "YTThumbnails Channels" which is for links (channels/playlists/etc) - this fixes missing notification artwork for these videos
   - 16cdb22: option to sort albums by record label
   - 9f48569: freaky adjustments
   - 0ad3722: allow yt download notifications to be dissmissible when paused
   - 68457aa: soomee some some
   - 9778f36: freaky ahh ui tweaks - remove namida logo from empty search menu - update notification heart button after updating inside app - dont display empty tooltips - disable hero effect when opening add_to_playlist dialog - pull_to_refresh animation only if mounted - other minor stuff
   - b3c08e6: remove stats button and move section to `settings > about` or `sidebar > namida`
   - 2133df3: various tweaks
   - 666ee1c: some fixes n tweakies - hide "go to channel" button for playing video menu in yt miniplayer - use network like button instead of local one for youtube videos in local style miniplayer - more items in menu of youtube local style miniplayer - fix cache related thingys - perf smol refactor for TrackTilePropertiesProvider
   - a8d5978: include channels in yt search
   - 8ce985a: save recently deleted tracks to a file
   - c5f19b4: apply "on notification tap" to yt miniplayer too previously it used to open local miniplayer or local miniplayer queue only, now it do the same for yt miniplayer also
   - b2c9534: re-arrange clients in yt flag settings

- fix:
   - f8d208c: splitting artists/genres with blacklist
   - e58be1c: faulty folder path while downloading multiple videos
   - 36adaee: root fix for yt download location thingies reverts e58be1c
   - 2433f30: albums & artists pages non-reactiveness
   - ed56dd7: ui related values
   - 446ac7f: m3u playlists path extraction
   - 784263c: dialog popping at startup causing black screen
   - 4db65a5: downloading video/audio when not needed
   - e869894: yt download bullshit
   - 5b2d098: patreon sign in with google
   - 0cd1510: yt thumbnails not showing for some videos
   - 71679c2: acc/membership related thingys - proper network fetching if connection was unstable - fix patreon login not redirecting back after authentication - depend internally on operation requires account - refetch current info on account changed
   - 867aac2: thumbnail related cache files
   - 3cc047d: build due to local libraries
   - 2afb697: hide shorts in horizontal history not normal history page
   - ef65992: fix yt downloads
   - 312b12a: pull to refresh

- core!:
   - 569d0c0: migrate some yt settings to their file

- perf:
   - dad2464: tooltips rework
   - c556cea: use splitFirst & splitLast methods
   - a9fb736: migrate to playlist_manager v1.2.0 new implementation for favourites playlist which depends on a lookup map
   - 43adcf3: detach reactive vars from `TrackTile` and provide using main provider for whole list and internal improvements for tracktile info builders

- chore(yt):
   - e62f47b: cache & data directories thingys
   - 554c40f: better channel/playlists streams management
   - 261d41b: fixes and tweaks
   - 8bf29ac: fixes etc fixes etc
   - 4ab32fd: change tabs header to icons cuz starting to get cluttered and hard to reach a page
   - d84bea7: some tweaks
   - dd1eb4a: display shorts in horizontal list in feed & related videos
   - a09eff8: confirm before removing video like
   - adea6db: show account header in yt playlists page
   - 38e7bae: confirm before removing video from playlist

- core(yt):
   - dc1d784: identify av1 & vp9 streams and present them separate cache file
   - 61bc5df: massive playback fixes & improvements - when playing cached video & streamed audio - adding video/audio info after they are cached - other silly fixes

- core:
   - ea571a8: upgrade to flutter 3.22.0 + drop getx + migrate to nampack + ReorderableList massive performance optimization + new custom Dismissible implementation + remove font multiplier and use global media query font scaler + no longer saving queue of all tracks as empty + remove search limiter + disable reordering when leaving playlist page + general changes & improvements (lazy to categorize) + more bugs
   - e4abf82: few fixes/tweaks
   - a937419: improve ffmpeg info parsing
   - 895fc4c: shortcut detect non-existing tracks when playing and some playback fixes
   - cc66282: migrate to youtipie, ref #227
   - 7d1c8bd: disable clean logs
   - e486433: hot sauce - notification artist fall back to channel name or 'unknown artist' - remembered to load yt settings lmoa - improved perf of translatePlaylistName() - hide app bar stuff in acc & membership subpages - app bar reorder icon for playlist not refreshing due to ghosts - finally properly refresh yt download reactive maps when needed - juust lil top padding for yt top comments card - feed will no longer automatically refresh. and refresh icon is shown after n seconds passed without refreshing - notification read status update properly on refresh - comment likes count increase if liked - channel subpage stuff not refreshing - hide shorts from horizontal youtube (cuz they are not really ordered and they look ugly)
   - 0d15636: no more slow video loading done by upgrading youtipie decipher & including throttling parameter & using same implementation of audio caching for the video this means excess video cache cleanup is managed manually now, ref #252
   - 402d358: refine track dialog, ref 262
   - 44b767e: manage queue reoder/remove lock mechanism internally & optimize reordering & shuffling all queue by using List.move() instead of removeAt() & insert() & shuffle ranged instead of removing current item, shuffle, put current item

- code:
   - 3cb5dc9: refactor NamidaPageRoute
   - 69334c6: refactor DoneButton
   - 2cbfe9f: refactor navigating to NamidaRouteWidget
   - a1136c3: organize imports
- build:
   - 8b42d4c: unified signature allows for good shi later, but for now users will have to uninstall & install
   - 07130b0: provide 2 beta versions (org & clone)
- docs:
   - ae907f5: update README with stable & beta downloads links
- git:
   - 2568167: generate beta changelog manually


## 22/05/2024
# v2.5.6
### 🎉 New Features:
   - a58231b: show loading circle while searching local tracks
   - 931c82d: play next/after/last when opening external yt link
   - 8426584: dynamic lyrics view, hides lyrics temprarily for empty lines
   - bb1dc7d: long press lyrics to enter fullscreen, ref #171
   - c838173: allow adding not found tracks as dummy tracks after importing lastfm/yt history

### 🛠️ Bug fixes & Improvements:
- chore:
   - db055a4: various fixes, tweaks & ui changes, ref #158 #176 #134 #132
   - 9a22c6f: home screen pull to refresh
   - 409d464: dynamic folders tile height, ref #152
   - 2010c46: allow plain text lyrics to open in fullscreen, ref #175
   - d7afa9a: separate lrc font size for miniplayer & fullscreen
   - c71ac05: various tweaks + close keyboard on long pressing (selecting) track tile (useful in search) + fix multi tags dialog keyboard padding + ui size-animating particles based on sound peaks + code miniplayer AnimtedTheme() -> Theme() + ui display `x` beside speed in video screen + ui fix empty lrc screen when lrc enabled but not available
   - 7b811ed: buttons for sound control sliders (pitch/speed/volume)
   - f77ec3f: button to rotate screen while in video fullscreen
   - 874d06c: more stable wheel slider
   - 116a093: ui improvements & fixes + empty tile while removing current track from queue and next is the same track + app bar redundant rebuilds + yt miniplayer sometimes stuck
   - 32a5c3a: improvements for yt offline search ui
   - ae6c2c3: stop saving history thumbnails to cache
   - bb27bf3: lyrics search improvements, ref #174
   - bf11761: various ui improvements + slightly bigger go_to_artist buttons + buffer color for yt seek bar + keyboard show/hide loop when yt miniplayer is active & trying to edit text field + other smol fixes
   - 502bda8: ui tweaks + pull to refresh + buffer bar color + smol refactor
   - 9eecbcb: few various fixes, ref #184
   - d3de40b: increase touch area of prev/next button, ref #81
   - 6861861: add indexing percentage in app bar
   - 3070cbc: yt download minor improvements
   - cadde11: general ui tweaks
   - 0b65560: lyrics improvements
   - a1ec555: general ui tweaks
   - 2e6b377: display if there is a new version available in about page this might be an entry for in-app-update
   - e2601dc: allow adding multiple tracks to favourite playlist
   - 698ef61: some tweaks
   - 535a476: more informative version section in about page
   - a7a7bd4: hide next/prev while queue is expanded
   - 6b4c591: better search for track replace dialog after importing lastfm/yt history & when replacing history track
   - 73b4236: few ui tweaks + bottom nav bar text overflow & indicator color + drawer tile text overflow + general pages expandable container text overflow + core clear filenames map properly
   - 5aede6e: few fixes

- core:
   - 17879c1: bump version script more feats
   - 6b27657: enhance extracted year tag
   - f8a3947: improvements for yt offline search
   - 18671d5: massive improvements & fixes for youtube downloads
   - f8892cf: delete excess temp yt thumbnails
   - 67f11e5: revert 1fbea99 & use clients was too unstable and same client couldnt be used again
   - 22f2e7e: improvements for playback execution limit
   - 1f63d95: playback improvements for crossfade
   - a8932c0: folders logic rewrite + deep directories extraction is now dropped, more convenient + pressing folder menu will show dialog with direct tracks only + long pressing folder tile or menu will show dialog with recursive tracks, ref #151

- fix:
   - 56b1471: selecting duplicated tracks in playlists, history, queues, etc
   - 4af9640: unknown font glyph boxes by setting global and per-style fallback closes #183
   - 196cd59: duplicated tracks after advanced reindex
   - ff64248: displaying track added date as 1970
   - b51c302: mismatch between search menu & search bar after going to a page while search bar is opened
   - 47c2351: lyrics decoding for non-latin chars, ref #188
   - 060ccef: lyrics view silliness
   - f59f23f: lyrics empty screen in some cases due to plain text recognized as synced
   - ca68161: resorting media tracks after history is prepared
   - 0b00181: fallback for faulty sd card path, ref #199
   - 87c59b0: queue related activity, ref #163

- perf:
   - 2fcfd1e: run auto-fetching-video download in isolate the video fetched for local tracks
   - 6c041c0: miniplayer & others ui performance/tweaks
   - 14a5fdf: limit color & audio playback rapid executions
   - e4c4583: improvements for deleting cached data
   - bd3bf05: run thumbnail downloading in isolate and generally improved api
   - 7a63a6e: run lyrics search and parsing in isolate + dio is now dropped
   - 1fbea99: use requests instead of clients to manager force aborting
   - 58ddd21: massive ui performance improvement by abandoning animatedtheme at top level and manually toggle animated depending on miniplayer animation


## 07/04/2024
# v2.0.6
### 🎉 New Features:
   - 752c3b4: clear audio cache in advanced settings
   - a3b2b58: allow deleting temp cache files
   - 044f010: pinch in/out to scale lrc font size, ref #128
   - a669ad4: use local track as a fallback youtube audio cache
   - 966818d: parse yt comments duration text
   - 15ec081: play youtube videos in local miniplayer option, closes #19
   - 81929ab: toggle artwork on lockscreen
   - d8d2a0f: broadcast session id for equalizer apps, closes #60
   - 4c4104e: queues cleaner
   - 00bd918: missing tracks page, closes #117
   - 7555298: new yt miniplayer gesture, drag down from right side to enter fullscreen
   - 39ec392: new in-app file picker with external picker logic rewrite
   - 92ba4cd: diacritic support, improves search by normalizing accent characters, closes #73
   - 9964839: lyrics source
   - 0efb32e: custom speeds
   - 9b8d27f: album artists & composers, closes #21

### 🛠️ Bug fixes & Improvements:
- core:
   - 57b3cea: better player error handling
   - 9261543: better video quality decisions
   - 0a17af1: tagger logic complete rewrite
   - 1285c2a: tagger fixes & improvements
   - 18c9cf7: inner drawer re-implementation
   - 5ee66a1: instant play/pause reflecting, this also prevents unwanted plays after pressing pause
   - 831258a: disable yt video stream switching if cached version was playing
   - 6a076fa: better playback decisions when played from cache
   - 6d9f5c4: fallback for storage directories
   - ab521f3: adaptive playlist csv import
   - 939ec2a: better logging & versioning
   - 1431cfa: fixes n tweaks
   - 3265b52: bump version script
- fix:
   - 88ba1f9: playing files on some phones after equalizer implementation
   - 7a8135a: pull to refresh in tracks page when no many tracks (no scroll notification)
   - ef9fdc6: show video grey bar in fullscreen
   - 250fb05: short loudness when preset is enabled
   - bae60f8: white dialog when no track artists, closes #126
   - 15de106: lrc controls overlapping in fullscreen, closes #128
   - a81763d: prevent editing tags again while editing, this prevents corrupted audio file if user pressed save multiple times, closes #129
   - 168d653: search matching for non-lowercase artists & genres
   - 9a9b25c: tagger stuck in some scenarios & other tagger fixes
   - 060dcb8: yt playlists/channels thumbnail not showing
   - 864749a: scrolling in some app parts
   - e97d7e0: applying default dark color on startup
   - 5987f77: playback on some devices
   - 8580464: searching letter l & I
   - 5203cb9: video player padding insets
- chore:
   - 8c13c38: play option for floating action button
   - 3c8bb30: video cache deleting tweakies
   - 2ab36da: sleep icon in yt queue
   - 613ff6e: fetch all channels videos since specific date
   - eccec09: remove - topic from video artist download tags
   - afa940b: ui fixes & others
   - 7a614c8: ui sauce
   - a6a3ebd: instant video controls showing, double tap to seek is detected only after second tap, instead of waiting
   - 509dd88: various ui & other tweaks
   - 04ee67a: lil bit faster startup
   - 7423e49: drawer ui fixes
   - 86edc2d: yt miniplayer drag tweaks
   - a5aed68: few tweaks/fixes
   - 3ad445e: use session id when opening system equalizer
   - 13c374c: fixes/tweaks
   - 1433488: tweaks/fixes + comment copy will parse html first + yt description duration tap will seek + smol tagger fallback issue + show buffering in miniplayer when not using yt-styled miniplayer + theme color dialog refreshing + perf app will not be painted when miniplayer expanded + fix queue item rebuild issue on reorder + drawer tweaks & others
   - 2fa656a: accurate current items being extracted in indexer settings page
   - 09301ec: various tweaks & fixes
   - 828ce5f: many performance & ui tweaks
   - 49a1aeb: pressing download item will open menu instead of playing
   - 63515d4: yt miniplayer bottom empty space when app bottom nav bar is disabled
   - 914e989: delete old auto backups (max 10 files) and fix empty auto backup file, ref #69
   - af841de: refactor & tweaks
   - b2c71ee: confirm before removing from yt playlist
   - 267e1a3: various tweaks & fixes, ref #142
   - a2dca2e: selectable video description
   - 0a83e58: expandable extracting paths in indexer page
   - 7d898e7: minor tweaks
   - ea8ff84: skipping failed plays properly if previous button pressed, we skip to previous if failed
   - 61ccf03: smol ui tweaks
   - 654f06a: playback tweaks
- build:
   - b5e8bf4: dynamic package versions
- code:
   - d3cb34b: refactor regex & link handling
   - 9e8b1da: refactor yt card dimensions
- perf:
   - 50163b1: ui refactor
   - 7b81c7c: migrate to TapDetector & LongPressDetector


## 14/02/2024
# v2.0.1
### 🎉 New Features:
- feat:
   - 09e8c11162582814bea765687c981b211fa11f84: Equalizer
   - 2bc89dcca989c47faaec9859788dc9e373e00080: new seekbar with functional ux + tap to seek + always ready to seek (yt miniplayer) + drag up to cancel + more buttons for video (copy url, repeat mode)
   - 241dcfaf46cb5e6d93eea86be69da30bb94c57a8: auto backups, ref #69
   - 62263d57d2fd889e494133010490d7495db165fd: fallback to folder cover, closes #122
   - fab509da9f10dc84f1ff6ac22ad490b964956df6: set music as ringtone, notification or alarm, closes #4
   - 18d4892a0daac72cc1c8adc11ed2355a91e80972: youtube queue generators and some redesign
   - b67fa6f9834f7869f5eb93da844dba0ccfa2e56f: previous button replays option, closes #112
   - c3338fab2082577f59c8f459c978bb7779f21c7d: resume playback if was paused for < specific duration + for interruption + for volume 0 pause & fix play button in notification not triggering in A14, fixes #102
   - 715b75b9021bf8db3e0b23836a738e32eb2ac106: copy lyrics to clipboard
   - 42285da53409082d3293f10cfc189b41a2665a73: refresh library on startup option, ref #111, #119
   - 5c832b02bde7f9250f3e4c5f7b1c84f37514ff4f: action when adding duplicated tracks to playlist + undo button, closes #120
   - 19bbf117ced7b4272ee2bee0fcf2c8082eafa5fc: pull to refresh m3u playlists for main playlists page and m3u playlist subpage, ref #125
   - a6e767ebd24908035699537f3c264fdc37bbc4a6: clear audio/video cache for playing yt item

### 🛠️ Bug fixes & Improvements:
- core!:
   - 6b147a2a59e755d1b561db8126c18f9b026e8b88: player settings refactor

- perf:
   - 961e8afa366b0f4bfd0975b42422006c41ddca34: sort initial history top items in isolate
   - f227d05df61d417656862242c638ebcd5aaec845: Directory.listAllIsolate() easier to allow multiple dir listing in the same isolate
   - 96a768b09f1779c5e8dd8d2c598fba5e389bce64: faster backup dialog opening by runnning calculations on isolates
   - 35b543fae2c6e552f18fa6ac0faf1d555c603946: accessing latest queue in O(1)
   - 397aa0e36796ac7eaa46cb89a80b62fc80af0e7f: close stream subscriptions manually
   - 26224d7c59abd1cde05cf4846931d66cc9d7dfa4: release resources after 5 min of inactivity
   - 69cb045371028bf7f95ebd721f717b260324a7fd: some ui tweakies + AnimatedSizedBox instead of AnimatedContainer

- chore:
   - 7380108604faa702b7baef6d83d221737d105e22: yt local search ui tweaks
   - 1c2bb1741a10ba6da982844ee2c7e0dad8b2232e: monitor clipboard only when search is active
   - 298082798b07010d1bce192b55f3fef564ca1c1f: semi transparent system nav bars when tapping video in fullscreen
   - 030f40b802c0df34fc25e5ac8b41759b301183d4: refactor miniplayer bottom row this allows for more icons without overlapping with text, closes #50
   - 1b889efaa17607806156dc76fe70ab48725bbc9b: various tweaks & fixes
   - 20610805419de99cc91cb3a11dfadcdcf7224f55: miniplayer dimensions tweaks
   - 889061c1a910d6555bf4af23f615371304d4e2af: ui thingys
   - 8c7b45f4ba4e8b7fc6fee9527d7318b0a25ae3f5: skip dummy videos in queue
   - 4cba1016d7c341e3594a2c798ef78ccb15498a11: dispose yt generator & search resources after a timer
   - 8cf0ed60ba2597093eea0cad47788f7a01fdaf5a: ui tweaks
   - 4333056a0480f37f61d574c6e4af464804a3470b: ui stuff
   - 531d9752664372324eb4291f8425c1d1de15bfba: some fixes
   - d163aca13c9b10b375a29140fa753174804ad8bf: increase hit area for some icons
   - d0aaf868300581040398680170d062a25e30f3d5: ui tweaks
   - 59a920cf400b08a823d932e31a0a1f8c4b7b67e7: faster video tap detecting now will only delay if pressed at seek areas
   - 31ee86d5dfe6c3d58ebd10e7a40c75fd8f49db07: more buttons for video card + play + shuffle + pause after this + play after
   - 9fd1c451eacce6d0141de7f71cca99893671fd99: scrolling steps for tracks page
   - 4d5c41c7592087e95f21cfe61abda5dea9846b45: menu for current yt video + repeat for n times button
   - 4177354497d5c9271e36d5914cbb064a10dc4adf: some tweakies
   - 47bc40748deb34bb7d6bfe0317ab49fb1b38cd58: some tweakies
   - 3aa0956efc6e2da44b1ce1dbf685390c687e5705: equalizer toggle tap to update button

- core:
   - 16aa9f5dee1661e404f74d75ea1c26941bff8818: video library rewrite + video playback is now properly a/v synced (ref #1) + pip mode is now stable
   - 4c4471eb9a5b62e72d602ddfb2ea14e5d2e9e07d: exclude webm & hidden files, ref #108
   - d7bb2bf2fdfd3a017eea691825e60bf6a0823e8a: wakelock logic rewrite
   - c7ad8832ca3b7232aaaaf6aff0dd66c383753a9e: allow audio only playback from cache when no internet

- fix:
   - 54aeac5ab8389f0f57bb7c00069ef407f69fc80d: default library tab name in settings, closes #104
   - 3c12410d677e7452ffb45b3a6d689bba7856998a: auto brightness always dark, closes #105
   - 1889ca850acb77c87accb7f980303ad90ba2e2ab: home screen items not playing
   - 6dc31fb17435fd7c5a9c1ebfd7dd853e82bcf365: tracks page grey screen due to animation controller not being reinitialized properly
   - 3700df07afad911cd1e8133e0f96766d2a7dbefe: yt miniplayer getting stuck after coming back from pip
   - 14ec3ed36cdb35ae2f7e492aa9b8bc80e576f601: yt miniplayer physics broken after pip
   - ed02698744de808e09ca1c8ef2b8d3750e90cf30: min track dur to restore pos not saving properly, ref #112
   - b675fc846e4e533954d6a56c8b1de1e1fcc7aa39: lyrics parsing in some cases this brings more advanced lrc parsing as a fallback
   - 52d485523f9c3e177b63e69ae5f218efa2bbbfb1: laggy tracks page scrolling this came after pull-to-refresh feat
   - 1f10167b40ff0bccd44b8a64fab84b9095059726: empty top history items on startup when set to specific period
   - f148dfb1d8171e02968ad2a12274bb9741a45bce: refresh doesnt detect new folders, fixes #119
   - 9d182a8d507b494a4aeecb1c165e46c4c1e6eb7e: comments line break
   - 2f1c9d819f6387b0fc184412d23cfec796d6988d: setting video last accessed for cache trimming
   - 7879155c61f55a4aea8e1636117ffdce7bf0a254: pip black screen

- code:
   - e2338cebc040d3e4cad20f73bddb0bdd36e4139f: project refactor
   - 69a93681c7799f591cfc6f9911b40bc67ee51e21: move audio_handler to lib/base


## 08/01/2024
# v1.9.3
### 🛠️ Bug fixes & Improvements:
- fix:
   - 962a1d8dda5829950f2b50e64f2acb826901407c: doubled tracks after refresh, closes #98
   - 0fbb759bb6cbf0a23d47637f035947be3dac52c8: stuck on startup due to latest queue casted as Map

- chore:
   - 5e1883bcc56292a6e358140df1863d54849eb050: go to channel button for comment cards
   - 8461fb13f33157937d3589062a237d0a316f3a5d: ui fixes

- build:
   - bd993d9fc5a8f755022cca4fd1a65237d832d920: change apk output filename


## 07/01/2024
# v1.9.2
### 🎉 New Features:
   - 447469fc94cbb487edd28fb3e6a0e0354cfbdfe7: offline search for youtube
   - a9a873913c2a50a71d49cc95dd3815315f887a65: youtube top comments
   - d60024b995a995ca1a7c3b9f4569b79bcd6b2e5a: channel subscriptions
   - 969339616d4a8ad956a85bfab7bd051180c4e381: import yt subscriptions from a takeout csv
   - 867f8038d304680c448e4b35fb6025ea502eb925: import youtube playlists #1
   - cc682302ac497173aa1a1515663a3e26c2b2dcf5: seamless transitioning when playing same item in another queue
   - 1528947573bf497f2fd8802eff0df9a7f90b3448: color palette for albums when groupArtworksByAlbum enabled
   - 7a4f21e743fb7ca1f56ec321d44d3a66b074ac43: sort yt playlists and smol fix while importing
   - 30fb059071717d0d21c44259862bdeaab80f5cfe: sort by most played and recently played, closes #90
   - ec57c1738b8e53a026b6d4824e50b9fc7d24512a: swipe down to refresh library #78
   - db22eaa70fbcb87e221ce1aa0e5b95479634f3e3: channel subpage view #1
   - 386c83126b197c5a285d737d9402beb86ccbeda0: sort hosted yt playlist videos + button to load all
   - 45c16d5976e1a41a80483aa9596467c24783b117: remove playlist duplicates, closes #87
   - 8b4c39524129bde1e2c6249e4d5e5701091285f7: restore latest yt queue on startup
   - 31486500a3c06d04f95543d1db88205528e7fe5e: yt queue chip, ref #1
   - ef7ab43ee1384519ae021e21a8b76927f3f841e4: reorderable youtube playlist videos, closes #97
   - 5bcf95525da32b9fe31a3c5d4afe17e720631d57: watch later yt playlist #1

### 🛠️ Bug fixes & Improvements:
- perf:
   - f02525f9cf4ef7e8d9ee01dd48d9d93f8f9226a1: skipping new queues process when playing from player queue (now will just skip to the item, no normal heavy checks of assignNewQueue())
   - 5220e7e09e4c9aff4c611ca3bad9e31f99e8b50b: search local tracks only when tab is active
   - 3362ba80f08da556fc01ea6325fc1cd188042e09: calculate history items extents only when needed
   - 2af3054ff2b05e4e61b2b485d0f97195aadc6139: close some streams manually and some other improvements
   - c0ed85076a577da875d65b13e1d453e038781328: dispose some TextEditingController manually
   - e9ba9c1176dd6145da00d4ca4264ba37edada66a: waveform improvements
   - a33dff060e3b41048f0038cfbaeed3ffa4426db5: assigning instead of ..clear()..addAll() and color extraction delay in home page
   - ba70591add4445dc69faec96bcde8e58d8df2cfc: significant ui performance improvement, achieved by - using child in AnimatedBuilder, smooth yt miniplayer & queue in normal miniplayer - keys for ArtworkWidget & YoutubeThumbnail, loading now only done in initState - using Container instead of ClipRRect - some refactor
   - ebd8d2247eb45c737aeaa8ef48e30feb5888574a: refactor to allow multiple children for AnimatedBuilder
   - ff7e78cc1820d082b7ac7617ace93613425583c2: artwork loading optimizations and overall steadier scrolling experience
   - dfb04bb3facb06fa636f1b3bbfdaa7c7c1b7be52: youtube thumbnail optimizations
   - 071d810873af2ff6abaa53a94625e6ee73831c56: artwork fading effect improvement
   - 63d3dc590fa0b481aeb0bf3fce89f8c8e6e1f5cc: run import lastfm history on isolate not so many benchmarks but at least 80% improvement + ui load is decreased
   - 260197991bb4cb35284c63855ccd56dfc677e422: run import yt history on isolate 60k entry in 10 seconds lmao
   - e67c281949b31f5f4f5b28dc2d8e9cb501b987d7: faster dialog opening comes by not waiting color extraction, instead extracts synchronously then rebuilds
   - 2c67645729806098325dd40571a8da4e6f2f501c: run all searches on isolate #61
   - 0aaba54c2b69664510819d1195894e6ac8b42837: save yt videos & channel videos in memory
   - e10ee0fa66d942bddc1bf3a8f73bc8b53b7cd0f3: faster video assigning at startup by attempting to assign one before checking for deleted/new videos in cache
   - a71db57b6f279dd44b4f47a123c0871ea2f9f7c5: home page & ytplaylistview improvements, closes #56

- chore:
   - f19e123f97b1179906699a057d743adca15ea9d7: always ask when opening external yt playlist
   - ad97bf20ebcfa8463aff5e411997220623bf6a58: option to open playlist videos page for external intents
   - 8a189412749372df111176e9602b661aff16fcf5: add as a new playlist button when opening external yt playlists
   - f937c5a5326d032363f6ef3adf2d46601a919cdf: auto detecting playlist link while searching
   - d182e77868d1e1fcb540de049bd853c936818c49: some goodies && tweaks
   - 628ba9b806004d145c6590bd53aeca995008d979: performance improvements and fixes
   - 5dea8b186031c378aa806c2820afef22c9717bed: refresh library icon in indexer card
   - a2f357ebda63847bd93fb3571d6e7fd99c7ecfef: new stratergy to mark field as changed
   - 01f0223e19983815dd88105bacbc8d51d59fa512: compact channel info in yt miniplayer
   - f30cff33d0b585daf27c2a27367600e0cc56a730: delete icon for queue when its empty
   - 8bdeec7dc30b5a774a3976a4acff322f31942992: sussy tweaks
   - 19f6b11d42fbfa944c93ad676f7c6cb638530dc0: minor fixed/tweaks + isInYTCommentsSubpage check when popping in yt miniplayer + longer doubleTapSeekReset (900ms) + image delay bug introduced in a33dff0 + unsorted yt history bug introduced in a33dff0
   - 6818a61b6e8441cbef13e3e36222270c3d3f3540: ui tweaks
   - 709febf252ff3ea14792cd582fe6fd7583400b23: toast when importing subs/playlists
   - d7797cc40fcbe721974510dcd6faf1046f46546a: display description/comment in yt playlist pages
   - 0dbf34198c33a749b4a8e7bf09f4f74988e8e62a: top comments true by default and smol fix
   - aa4391262b6bd821c4ea9974174120c7b05a0b8d: some tweaks
   - 8acfc81dc6bb1103d8d187db11c3417ef202c28b: temp workaround for playlists with hidden videos to stop fetching more items
   - db989eb39bbfa93f0c9c4917ac59eff053077073: history import refinements logic changes, should be a lot faster
   - 40fa46796b3daef69674d9b2e1f1893e328ed19c: shuffling all items will put current item at first #88
   - 0e02c15a8d7bf5c45e6422d0d74159fd38790dd4: improvements & fixes
   - db5642db691e33b8e6ebc32e6e651aedfb439aec: transparent system navbar
   - f5cdc2d5efb245fff2b33bf7ba39ce1b39bdfdec: some tweaks
   - 1266500f513650c315cc86aee79a9b367b56405c: add comment as track search filter
   - b1c9287163d3e28d3779496d324518090ecc0b73: allow separate listen time local tracks, youtube, local videos
   - 68a13953ff44506d1eae3265f4857f784ffaf726: restore yt active tab on startup
   - 12a6106b7f61cd0681613948985f4b26ccf44f73: go to channel button for video cards
   - 53d8d03efd2a6ca2bb44d4ef47096f2f86077fdc: expose yt download location, closes #93
   - 3731eeedc1d1feb161390e0af529f412b33518d3: stuff & stuff
   - 1431c81af7cef89baaa3bc438589159b2ef52b85: more stuff
   - 68fdade6f8e9246b427b221b7c7de783f57b25f7: av sync improvements

- fix:
   - 5939e3ab0050bddc128bcc52eeddec055a4c2444: not entering pip with yt videos
   - d9c1a30847e738e12dd7709ada646f83c91bae75: folder changing not being synced in playlist download page (top widget and the one in config dialog)
   - 5d2f877e4f258577bd22575107ba56263486a61e: listing non-existing directories
   - f7aadaed6bbee409d227030405fccdcfddd1c253: late initialization for miniplayer dimensions
   - cc8b3f04e4548bb2ca0a77cf77737711b9e02710: tapping the current item in queue will play/pause
   - e14ecac34ae31d05e655d9a05e11025b6a4bce11: possible fix for waveform being out of sync #34
   - 28035ebd954eb28e44213c6d5ee579cd1d977932: not pausing when jumping to first item when crossfade is disabled + stopping methods fix
   - 00387df0130846a1daa33f298b93da3b9e149161: yt comments not loading properly
   - bd1e40b8460e62c4718592fcb5a6c63823795ded: yt downloads will prefer not using webm format
   - 4703c96a6855df8cfc024e000134bee3510d0d5c: disable skipSilence for youtube causes desync and just not worth
   - 8b27462b114fd8636ca1591b8d9513838c060a83: gigantic artwork scale & waveform bars when bitrate is high
   - 3c703d424484d7dbd51bae4df238e265a59c0472: opening external youtube links
   - 9d6e4a043069ab569b80c8274e6b269ce724fac4: mis-aligned popup menu
   - 109a6d0ddcc3c91f2ad725765f7fa654c0a8bfe8: waveform bar width after coming back from landscape
   - 291df2030f9667aa40b80d9ca449f25623a26adb: video still downloads even after disabling video playback
   - 715405494027e4b4ae839acd580b98e93e91fdea: track tile items not being updated properly
   - 34c8a95da0bfaa9c97858714dc9e892ec2005191: removing notification after sleep timer this allows system to kill namida if needed, since no ongoing notification is attached
   - 17d917d7da881002dc07fe64427134eece7bc950: properly stop after sleep timer stops playback and kill notification, allows android to kill namida if needed
   - 5dd1b5d3dc804ab17994b4ac22cf924aff366c12: save track info file after updating duration
   - de3ee38f938bd318e5397b857d2af0063c132005: hero animation for history tracks while opening dialog
   - cc61d731fb781c1d6d85ee165441944ba5e9d4cf: possible fix for fake error message, closes #86
   - 9247543c6e455b039792738d6a410fcade102703: playback issues especially when failed to play files + properly kill service when stopping, closes #71, ref #92
   - 9c9136191aae2c6dcb8e468600d038006ead8ebc: stopping player on queue emptied
   - 717de50aab1e2150d7f629db4643f6f2e586123c: minSdk 21 (Android 5.0) & fix desguaring issues desugaring disabled was causing crash in retrieving channel videos methods

- core:
   - 5472b9ba070f9b94618131327f9b20f8e6ec2d5d: change yt images cache name logic
   - 439a8da692ac67121e3ecc7d46d99de7499a54f9: better search matching - order of words wont matter - u can use artist + title and still get a match
   - 97f5f69266cead3da218fc2e4d0d34bab936ad0b: enabling media store will disable respect .nomedia & folders to scan
   - a0a1c1397803d1720704199e5166260e939f6cc5: better yt local search matching
   - f7f20db5d3b24bd0e3ba41f38b60f93bdbd3d7e3: revert e10ee0f hehe, the updateCurrentVideo is already called inside player, calling it at first step wont matter, mostly the track wont be even ready also updateCurrentVideo will not return if still initializing

- code:
   - 0071a4cc80dcbc43deabd3e2cfffb56a6e0d3d2f: revert miniplayer to use single constant child multi children felt laggier in ebd8d22
   - bc50e85a55b6f3bc5dd86f4f4850d48556e03ebb: refactor thumbnail methods to ThumbnailManager
   - b2facdda7d2e76ac4b9e9834cf53249a1a65c8ea: refactor video info methods


## 03/12/2023
# v1.8.5
### 🎉 New Features:
   - 204d4da745ebc720b03431093e42f3805649b04d: search in settings
   - 302bfd6029b16101844f01b84b920d8215bff2ad: floating action button (none, search, shuffle)
   - 17bcf73f8f8edf084acc4636dd4366fd9a838a18: separate sorting for search tracks
   - 2031d74bb7c8f06f2c90bbf8ce434f99866d78e8: artwork gestures - zoom in to enter lrc fullscreen (always, when lrc is visible) - zoom in/out to scale artwork (config, when lrc is not visible) - double tap to toggle lyrics (config, only when lrc is not visible to prevent delaying)
   - 0caecd7fab757314bb21b0233d3ac466475c8a00: subpages sorting reverse order
   - 493800c28acf396a4ee557237e0fc3f648ade872: most played page for youtube
   - 73f9a24897699c31b0b4222f439d13f1991a2514: yt playlists support (normal, likes, most played, history)
   - a3a5d310b333aa1c6dbee0cbc7634e257ccd7f5c: dismissible youtube miniplayer, closes #52
   - 20ad7561a05e3fdb4426fda67249fb0e21bf9699: load language json dynamically
   - 01fbaaa2f669361e45dc288a0ff1e1d4f3f14a84: creation date for files (simulation)
   - 0c3e148ddcd6ab350550d9d64ecbceeb0c08e759: removeable yt videos from playlists
   - 9967af0e68e5512e32c01748d50803b5427ce91b: download yt videos logic + ui comes with pause/resume/stop, supports download groups & between sessions resuming
   - 090edbdab8bfe80b209b2d935f8cd55e55faec03: resume/stop for whole download group
   - 6903b323d56879ce35779589047f0694cf251386: jump to day inside yt history
   - a97b3150707868b354ba89095af98675ae8322ee: download filtering chips (all, ongoing, finished)
   - 4eb90dc8f5f5f07429fc6b0825451dce55cd091b: youtube playlists downloads
   - f7a37922ea12bdaa5dbc55027398b2896bda3268: ability to cancel downloads for groups
   - c8f5a3e2a9a808bfce434c01db8fd50499680064: downlaod yt playlists (hosted)
   - 575139962953a6b4fb6b9fc7674c819fc52fd93a: support downloading multiple external youtube links
   - 1c4e022a817ea4311728ae639d048b4f9da38f7c: zoomable playlist download page
   - 513a791575b33ce4666f8462383696341f8bbaf9: open-able external youtube playlists with default actions (download, play, addToPlaylist, alwaysAsk)
   - ea50869867804f0f508711ad6a8f60ceff58fdb7: playlist view (hosted) comes with cool stuff, revamped menu too
   - d14717005157b5e100fc8d6219c2f864ef47e037: toggle clipboard monitoring (disabled by default)
   - c6cb1343f1320b596734e8e485c144bedf270ecb: restore backups on first installation #69
   - 5c426a8ab764c3d818a4c5142d001653874d50fb: dismissible queues #69
   - eeb50c1f2902ec8507c5bc057b866ff1df94b9e3: parallel youtube downloads
   - 907e586bb3fe4130f19b015ab334b76117607041: sort downloading groups by last edited and few fixes
   - 555c8f4a521d8ca99006034b5c375abc3b063faf: separate editable download items in batch download
   - e500d93fb753aa3880baef703b994ef687bd1dbf: edit & rename download tasks
   - b942779cfc58925f88aff4d6be27134717ef4297: toggle clearing artwork while re-indexing

### 🛠️ Bug fixes & Improvements:
- chore:
   - fadffd894f3aec72cfbf6b7cd7841a15f31ebc58: various tweaks & fixes
   - 5189dec8ab3f32663d501f3613c21df12b85812d: ui fixes
   - 36b78c4d39f8f85e2e0cb48256c150d827317cef: downloaded yt music is force added to library replacing any old entry
   - bfdefa555b7fe597cb9966b3d697463de71c2314: max list tile title lines
   - 0f5670c8dcee78dcb0839501ea7d96d6ce4cea28: history import wont remove old listens in same time range and will only remove duplicates after finishing, extremely useful for when u already listened to videos in namida and want to import more
   - 0593c8675670a040dda9a27fc5ec426ddc67ed81: 200ms delay when searching, for steady feel, #61
   - 2afc16e41d27ae0c1d133b1cb79a703bf2ad739a: display if video is dowloaded in miniplayer
   - e6886da84a39d3adc46eca72433b89764d94877f: choose download folder group while downloading yt video
   - 4236835183cecfbf3420f485f496cf895d215d49: yt download task info dialog
   - 9e9cff0b3aedee6491fce01e7e2d337ec868e6a4: real-time like button for downloaded item info
   - 1e35ea6b26476b75d599cb580173874ef4153203: download confirm dialog (before delete, cancel or restart)
   - 6d484b738584b07497ec93f7457dee443436dac6: few tweaks
   - 726b8a8cc1650592eb11e3c3dee3af013a3728a0: more yt download item info inside info dialog
   - 39530133bf3a22a037abbf80fb8c372093abec6f: file size try-catch
   - 910e7ec43c573b5c9a9e4947187b254fa141dc5b: skipping if failed to play from youtube
   - a7efa12bdb2a591ae8276dc5f8a853373f2f093b: few tweaks & fixes
   - 32170610a542b03ff43b2441c97b0433f2ccee10: restoring backups manually no longer needs all_file_access permission only needed for automatic
   - fdf9237abfad1192e884ff7963f3a976d993f64d: abosrbers for dismissible queues, #69 to allow more space for swiping right to open drawer
   - c818f310cf976e05fdf23457026174c292cc8ced: download sheet loading ui rework
   - 7026a1e15b219e69a8f947dc09c94cb7dbeddcf4: in-between selection for batch download page (by long pressing the item)
   - 0031d46df4df2dc119bc0ab98e0a8bf92c03bed7: hide fab temp while scrolling tracks page and force show when search is opened
   - 1e9fc0ef0ebf65848403e5e6e2d5678cd7f447cf: few fixes & tweaks + lrc view now has wider hittest (while tapping on lyrics line to seek) + fix skipping multiple times when crossfade enabled + player should be killed after sleep timer
   - dc07003a5f517d877751f7c7fd297546b671aefe: disable crossfade for youtube still has some issues, and doesnt feel like its worth
   - ea5d4c25104dd614352426807bd1cbd474a6747f: assign downloads progresses on startup
   - 1390d8645520be064f389c70ad138b5ed0c0d6fb: persist audio-only playback for youtube
   - c4ce7b7c72fc876102617f58dfa36400852bf971: save playlist videos info to storage
   - d2ff8b311e2b0e3379a5d8faa43d68b4363982b9: some tweaks
   - fa8c53f4df60e8dd959922b8f162d7013beafaff: optionally remember audio-only mode
   
- perf:
   - ed91f91d87f151c60ce5eef47ed5787b092b2e1b: performance improvement using custom Opacity & MediaQuery.propertyOf()
   - 8395cdedf05c374493e730d09f01e4d8a31f1cf3: improve search speed by 10x-30x~, #61
   - 6e445edaa570759e7f57fe212843223d98fc72db: improve indexing speed by 38%~ this comes by dropping isolate, eliminating the need to serialize/deserialize data, reducing overhead & resulting in a more stable extraction
   - 57d375878a57a58e0bb2f41ac2dda0ecd385b9b6: listing backup dir on isolate (for auto restoring)
   - e22c22332a697549dafc38659620b73fa07f9c78: limit thumbnail requests to 4 at a time
   
- fix:
   - 59a7dcc391c01dcf6731db506723ec3538861290: playing after sleep mode paused playback
   - f2915759748483776fc5abe17fe9f49d0b15aa97: restoring backup now will re-initialize lists
   - a38e02b60ddbba502f07cc6ab3db1d64ef6b831b: onBoarding button overflow
   - ac117f51163b6998b168286d82b611375bc5d640: writing youtube metadata with quotes
   - 90dd7d457ee9a4f26ee8484716f2ebafb7a6a24d: resetting color when toggling pitch black while playing yt video
   - 8c5aa9f6134fabf431093825c41dac2c764d5e43: thumbnails not rebuilding
   - 4f8511664a375cb55b97bc21d1138b372938ee2c: time prefixes after switching language
   - 5079801572474284493ff3e4318108d3c6094e25: indexing stopping before starting just gave up on cancelation tokens, now will just display a snackbar and return
   - 2f41539b8798eb4b1d76f0699932eedeee3bb78b: clearing image cache
   - cdf7e1f0b6eb831b9094de01bd89c25f417b13f0: start up with search as default tab
   - cc30f78f3369a4a85a2944cafac00026b0b1a892: user backup location not being used, #70 tehe
   - fee447292c51081a0ef354d953cde4350bb4f665: dont display failed notification when pausing download (since pausing typically forces closes the http client)
   - 2fad41eccf15d9f738dde7840d50b099685dfeb2: pressing batch resume button won't restart downloaded ones (both resuming and restarting share the same logic, since the client is already closed, and we always resume downloads)
   - 1bc434a787af3d3d3aa2d252db0aba44f0a4146d: startup crash on some phones
   
- git:
   - dbff88d40b69fcafe7be730b95adf3d8bfff92bf: stop tracking language submodule
   
- code:
   - e7192159c80967830074f6ecad8fccc0bfad92d0: move ffmpeg quote refining to internal class
   - 8658713e7f85c871694da9a5799c9c98faff3926: delete pubspec.lock
   - 6c94265802aa6df569b95b9c3e47c20885977dc8: experimental AZScrollbar
   
- core:
   - b5eb4268cecd4c011319c4d9ff164acadd6dcb85: new language logic currently accesses the lang map directly, without needing to assign each key manually
   - d3a6c6fe291ff3b12f1d79affed1358945fcb252: now accepts multiple keys to add/remove
   - 6ddf894248d999435875d55b20ec43ac0318be06: downloading video extension is now auto assigned this is required for editing filename in batch downloads
   - 17bb0d871d6b0da476e46ae9dc933837dc1fa9d7: disable title & artist splitting when splitters are not separated by space


## 06/11/2023
# v1.6.8
### 🎉 New Features:
   - 1dda153b1d97d220de22a4d674334ba185301ef1: Crossfade support
   - 553523304b81749d7b336ff990fc895ad513f55d: Crossfade for youtube playback
   - 90651ae93f86e7cc9be6bb588f5d3661e635c62b: Media Store API Implementation
   - 8fe2959d6d6fe7bbaa29276860dc4bd9718632b4: Heatmap view for listens
   - 415ce4e48e2c88f70703821cee82598458c4052e: Dismissible Miniplayer
   - 02c356585653a19b0012af229e111acd594bb012: Swipe to open drawer option
   - 64cf448de51268f8bd76ec1fc232454c66d831ca: Immersive mode (Hides Status & Navigation bars while Miniplayer is expanded)
   - b7aa3255be5601b50cd64991c5d08f958a653807: Add filename to track search filters
   - b3e1ee11d928d8ce7be8732178649119f12a399b: Prioritize embedded lyrics option
   - 800965ce1a27b894d747197137b88b14130304b8: Kill player after app dismiss option
   - 0caecd7fab757314bb21b0233d3ac466475c8a00: Subpages sorting reverse order

### 🛠️ Bug fixes & Improvements:
- chore:
   - 5189dec8ab3f32663d501f3613c21df12b85812d: ui fixes
   - fadffd894f3aec72cfbf6b7cd7841a15f31ebc58: various tweaks & fixes
   - b0b33faa670e6652b64e280714261a5212da4476: display track path for missing track
   - 20cb6386baba1624167e90ce0a9fa8dfff168176: more local lrc file patterns #46
   - a26ddd07b9a00a9510494d8a19fa6bf1e870d59e: increase skip silence values (min 2 seconds, below 512 pcm)
   - 39d13c4b4cd6f1c9014c6bc6dd37e031eb813fe0: sorting by year (now parses the year first)
   - be452745511dfe6f02ad9266e14cff3b2445e6b7: KillAppMode.ifNotPlaying by default
   - 768f852fc070f384be0bcdbedcdc6220aff093c4: aborbers work only on horizontal drag
   - a532c97a01d0aaa74b3c5f13f96ee54fee257702: expose auto show status bar for fullscreen video (currently disabled)
   - da044896e684a86a7ad538fc7610588d53a9ea10: save m3u paths as relative instead of absolute, as long they exist with the parent m3u
   - 39d7fc8b5ad577e379709ea83977296dbb09c3f2: drop useless settings flag
   - e2250982cf5b1ca7e5471514d0c9b7c3e727e944: miniplayer ui tweaks
   - 983464c3854c91b42753bb39691e837945ac1625: lifecycle onDestroy
   - 0ab0292a436e68a72a76a7082552db1e9e6e4e27: save last played track index instead of path
   - d7610037d73b943ff3d374b4daf258ef8fae4de4: add sort by date added
   - e033629e9a76c54970979e9a0178fc919ef2695d: edge swipe absorbers for the whole app
   - df4c577ff8d159d52b1cf2ecbc52aea221630bc5: improvements
   - 20213948cea8c3982651506ba60ecfe5a8819a66: add language button
   - ad131eaac44f0b6b535cd9a5763561e96350eb68: performance improvements & fixes
   - ec568328ecbda4c8252a6a273a9e2694c81e2cff: skip tracks after 7 seconds when failed
   - ea7d5bb9a5df441c2a05d0c9b41ecdc9558d508b: dont show system volume ui
   - 28280cf066ab191fa93d34dfc33670b93ab86ef2: using local history for video cache total listens sort
- fix:
   - 3ed495f9df3717186efcc5e110b3da395c987120: jaudiotagger removed classes, this fixes all tagger issues reported before
   - d344461af32c59c757432f7519a0009b9fbd0189: lyrics not being updated properly, fixes #25
   - ef6e8090e506512b9ae442f7ed3882d74bedf5e4: playing files containing # or ? in filename
   - 49b1ec1a1da1da1646cda2d09436c020b68c5eed: swipe absorbers
   - 7a80567e598c554bdfdae22b6c352c13bc10984f: track total & disc total saved by ffmpeg
   - 312b2bc39f4432b35c9af6e91f7a8305567e4684: using failed google lyrics
   - e3f79bf8709f045109c576ae8d774658e7279555: empty queue while switching to yt queue
   - e84f15e8f7c2bccb60d27cd65787faf01e0fa2b0: folders search count
   - a38e02b60ddbba502f07cc6ab3db1d64ef6b831b: onBoarding button overflow
   - f2915759748483776fc5abe17fe9f49d0b15aa97: restoring backup now will re-initialize lists
   - 59a7dcc391c01dcf6731db506723ec3538861290: playing after sleep mode paused playback
- perf:
   - 4c41353d6007fd434758afdbc8fccc2154d06390: performance improvements & ui tweaks
   - 77a74817b9ffa5bc9836e98f4729a8db382a4148: perfomance optimizations
   - 7f77d6398f37190d0b526a6fe7a6d6fcb596cc27: youtube shimmer cards & scroll performance
   - b02bbed5007e782eb5e920c47c8a605bde13b468: main page loading
- core:
   - 0d24bf3594b64a785203f707d99d2117c5fccfe7: custom lifecycle controller logic
   - d1836550878d0b7b4496a061b43181253cbd238c: experimental mediaNotification()


## 23/10/2023
# v1.5.4
### 🎉 New Features:
   - dbf825608f799e708a2bd245cfdd667c4bce630a: pitch black theme
   - b82dce29d98b01f69fba1ea44bee7e131dd44a41: subpages tracks sorting
   - d918716416c35de858ed6371e7968bddd0e9c967: m3u playlists sync (auto import/auto modify)
   - da105cb75226610f27e726a2f3c4e8e32bc669d8: play external m3u files
   - 6b06adcebc9f744cb8b2384a5f8549811551b0f0: video view dim slider (not related to system brightness)
   - c59229f278f98af67169d7747faeca5abfc4ed5f: open fullscreen on double tapping video (local miniplayer)
   - 7d34cd195aad72485a16a9449487cec3cb021682: force track colors for miniplayer option
   - c9919cdbca38220495a23c105a7e7bca59c89fc9: display artist before title option for miniplayer

### 🛠️ Bug fixes & Improvements:
- chore:
   - df4c577ff8d159d52b1cf2ecbc52aea221630bc5: improvements
   - 20213948cea8c3982651506ba60ecfe5a8819a66: add language button
   - ad131eaac44f0b6b535cd9a5763561e96350eb68: performance improvements & fixes
   - ec568328ecbda4c8252a6a273a9e2694c81e2cff: skip tracks after 7 seconds when failed
   - ea7d5bb9a5df441c2a05d0c9b41ecdc9558d508b: dont show system volume ui
   - 28280cf066ab191fa93d34dfc33670b93ab86ef2: using local history for video cache total listens sort
   - c49c6b0ebfa2a5f526c61783b8e066d3210afeaf: display elapsed release time in track info dialog (ex: 2 years ago)
   - b799e4d505e3c7df7e00852f9a9114c3e3461d05: playback improvements
   - 059593215cc2f27e2726e6add793a8bcc0d981b8: ui tweaks
   - b935ef5777a69ed0fdeb8b832b148dc19a4cf07e: downloading notification rework
   - 9889c32acf628893c1622a30f58a6c481c9910c5: request battery optimizations when downloading
   - 16c226058aa0f1724bbd2af9fc132a5a6a4a3ef8: ui tweaks
   - c1dfb51fefdc0e7872f3e076bd86322e6299d3ec: minimum track duration to restore last position can be 0
   - 0378eb979743bf39645b181c431aaa99a1ae3281: faster playback start
   - fc0e44d7e66936810e11232e2bef5aa776bd9214: vertical video padding
   - 8f685523d3af05fc545db66dbf070235be915d53: add tagger logger
   - ad9445cf8096bb8b49a14b05d5fb388f6be291c1: ui improvements
   - 1ec35df66a66ddacf06eea8a6ca6b12d92142821: extraction improvements
   - e85cd6048cf3d03d46a65e4a03b4e04db29e9a64: more lyrics fetching search patterns
   - 0e8e1d5e87afcd2fead9c701686a149054324e1e: playback improvements
   - 123f3a1a121c904a08c213e43ae607561c2a4640: set landscape only if aspect ratio > 1
   - 455bb939d28444449cf3447c76e5d937ab4cfc7c: change default library tabs.. ppl are lazy to check settings
   - 0833d9f066061a44dfc26dd9c4091fb35da395d3: sort by listen count while clearing video cache
   - 55cf7f7c6bb4beffbe9873935e9e95668c57c966: few tweaks
- fix:
   - 3a6899c53bba984d7551365639688c75b423c672: not retrieving storage paths
   - 4707c3d3e5bcf88882ae46bf6901c18c4fe9d299: showing failed fetched lyrics
   - dcdf50fb98a42b49a9a4be4e12f460b5b733d1d7: plain lyrics padding
   - 509002cc312efd3b0313374e2a045433d964be69: text overflow with non-ASCII chars
   - 7ccd697d48b0c19bcff80158a81b48379917f295: album tracks sorting after editing tags
   - 906e10ff0b54433bf19560ebf26c2edd91835744: lyrics update in fullscreen
   - e5043ca3f23ab5ef82d9512c1e1a52f23612b183: download file name special char
- perf:
   - ebf002313aaa17796ce585fc45ef9ec72c69b20f: disable colors extraction on startup
   - 3bf0990ab3ffd76a28122cb1d399d6a059924305: cache videos checking on startup performance imp
   - 8054329547feb1332c7204d5927c2ec14dce461d: efficient scroll jumping animation
   - 0e32f1e3e3f3ce74f67a948ebaf7b52b6cf76de2: video files fetching at startup
   - 4c145d6a41a05075a7245a8af8ae37f4071aa05d: faster thumbnail loading
   - d637ed434e3338e9aedc62807f118ed639670340: disable videos extraction at startup, now will extract local vid info only when needed
- core:
   - 97c014041b6452372ef9f13142da091c227d42ce: support for more audio formats


## 16/10/2023
# v1.4.8
### 🎉 New Features:
   - 5b53f979bb9131185d776760f1fcb81eb40c8795: Full LRC Support (comes with synced view, fullscreen, lrc fetching, modifying, nightcore/spedup support)
   - 7d34cd195aad72485a16a9449487cec3cb021682: force track colors for miniplayer option
   - 662256a98e338db911e690d46ace4d0a0c82361a: onboarding screen for first startup
   - a3dcedcc1134ef3aa6c7ba28b6b92d5c7696ffa2: performance mode (highPerformance, balanced, goodLooking, custom)

### 🛠️ Bug fixes & Improvements:
- chore:
   - 1b1883a106c939f2f511ce7081709c5999cdecba: improvements & fixes
   - 261e46a7f2ee53ad75c94dcbefa9fcf418bc60e1: few fixes
   - 16e8375e63c89e4040c00bf48ff49a0870ed6276: add mood tag to (generate by mood) dialog
   - 95a7301f7c2806d6081d8942fc13b1016ecf0e45: sort album tracks by year or trackNo or title
   - 39bd4e8c9f1bf97b43109d09402b46ecd9c71c30: various improvements/fixes
   - d0b55d7ff6fee250f1c16092c1082b3de3159811: extraction improvements
   - ff1b1bb3b8772df0eab312f79afa2870ac058863: fallback duration extract
   - ecd451a83ca142fbd058995350dca94723298992: openable version page inside changelog sheet
- perf:
   - b9bec28c7bf518192e5d26c3059694f5244dddd1: scrolling performance improvement
   - 5ae0247a62046d03ce9cdf486f908a54ee085de7: improve indexing speed by 250%
- fix:
   - 850edcb1e7b26810723d128a7bd6604ce82499a2: pausing on volume 0
   - 1bcee8b12907f5da036bd71164a8dea8849e15ea: disabled save button for album identifiers
   - aca3df469e1d5e4575d1b762e6d13e96c4044966: not playing external file
   - d2953e238f1442309c70b46537e53866f04d96fb: empty shuffle queue & item skipping optimization
   - 6d43c26c0dc95b7160d223d9c818b8d0c741a05a: not playing tracks inside root folders (requires all_file_access permission)


## 10/10/2023
# v1.3.0
### 🎉 New Features:
- feat:
   - aabbff12c95c7a5478f98a840b64dce2a94c4356: add mood as tag field
   - 6e2159dc30940dbed30d878f221ed63859790c83: add downloaded music to library automatically
   - 07ab4cd52478b2e2e919954d9d00d5cb4b01d163: add youtube as a library tab
   - 3514ef12953b5a07196e4e2e3e4886b4dc26d7dd: image cache clear dialog rework, now can choose which directories to clear
   - edda4ea438d323a48207966985fae7e0fc9c80b0: yt audio language tracks support (this also includes caching)
   - 517a48410217fbdf8f5746086fa5d22f3e949f0d: on Youtube Link open (showDownload, play, addToPlaylist, alwaysAsk)
   - 149902c035ce1e9cce60611a0e87cd3c39f4a54f: clipboard auto paste & direct yt link open
   - ce481c787e2594d76bb03ca07d85cce00e1ec400: extract by ffmpeg if tagger failed
   - c9b9445ee8391ba7b06bcbdf3a2ce3b2857814c3: display video listen count & jump to listen for youtube videos
   - 3da20ce13c831a5aeab4b6d6da266a7ca099614b: share logs easily from within about page
   - 6888d8a2fb8b0fa57e0d2fbe04a332e3d363ad53: group artworks by album
   - 37a1fe5a74806b5ead308912e250930a7f93e0e7: album distinguish parameters
   - 9e82433e0c9e8b34e8a83f38b561736559667410: media type chips for searching, can now control which media to search for (tracks, albums, artists, genres, playlists, folders) 
   - 2d8413138551330e0939a70db8883a9134afb848: auto search option when setting youtube link

### 🛠️ Bug fixes & Improvements:
- chore:
   - 36273bb978b1d6a634456854f92c8b7de226c2e8: playback improvements
   - 584f733ab6f15c58ae63ed2a6c3c69f1bd2f3d93: display video info while clearing video cache
   - 1d070d95409cca311331c6e80c50b1c2fdc8d0e9: few ui fixes/improvements
   - e1889d65603aed53ec71501ac4ec1059dabdb80f: few tweaks
   - 822072e6b6ecf10ca70804183e5124f743084063: search cleanup is true by default
   - 9395a1a9ae3786efba1145ab155d68fa7ced29a6: try editing tags with ffmpeg if tagger failed
   - 032b3136242cb92c87e7fbffa287b30ff0ee2af2: suspend playing next while reordering queue
   - ca0312799ecb90c5f6ecccdfa47e71f438017ffb: some improvements
   - c60cd841ffde9c83e0070a1419c4b266d773aaf6: add yt miniplayer screenshot
   - ac6992571e719054ee22d5402df58f79602f03c3: few tweaks
   - 3953f53e87749d39f5149e772f1f910fd7cbdfac: few tweaks
   - ae424ac5ecb7357a190fc0fca4269507f6541388: prevent accidental triggers (android back & home gestures)
   - 461d045b0b0fc9fe15b88f5cec2067b5e2833c95: max image cache size
   - 973e8246e3145423471cb25608c5da194b238336: auto-coloring from device wallpaper (A12+)
   - d9a0aa1a28c5773a2245f92f3034b9b3cc86e374: display remaining duration instead of total
- fix:
   - ac9008114ef4d7965dddd6e020cc4475f2ebc99e: video playback sync for local music
   - f7487f404e083f2082e084e9e594819aa88e57aa: not fetching lower res yt images
- code:
   - 4c357779e791957548b3a1715d83a9522b438146: refactor snackbars
- core:
   - 19b60b94e1e06170b200dec3c5f643d91cfb0624: add yt history import to yt history too

## 03/10/2023
# v1.0.0
# first release
### 🎉 New Features:
- feat:
   - d9a0aa1a28c5773a2245f92f3034b9b3cc86e374: display remaining duration instead of total
   - 0d284774eb4cecb55d36c5b6edb036ba80040d6b: youtube settings section
   - db504f8e02d5dd7c8c56732dd95043d3c763fe61: expose parallax effect toggle
   - f501db37e5becc7a0047929c8bc408cc8ddeedb4: swipe up tp enter fullscreen
   - aa119349a8ceb9c7baca329803557d5b9d1d0994: open in youtube view for local tracks
   - 2a214c8c263aaa60e57cfc07b3c88dad968b558a: dim after inactivity for yt miniplayer (later to expose dim intenstiy and timer)
   - fab06ec3b9afe3516445f3e3839634dd05dcdc2f: option to keep cached downloaded versions
   - b7d972625837e1c139b734dc275a1b922e18ae5c: integrate yt search in main searchbar
   - b4404b070e1b40de1d5d85521f9819d8d1bee66f: Home View with History Page
   - 20a01597e6c6a6b9ede6325f9ed0668d79da525c: download notification
   - 0de852aea42406bcb802608075d3bcc85135ed64: max video cache option

### 🛠️ Bug fixes & Improvements:
- chore:
   - 92b0d7d59c0113523d1277632b50826880c2fb34: removed useYoutubeMiniplayer option [its being automatically controlled now]
   - 3953f53e87749d39f5149e772f1f910fd7cbdfac: few tweaks
   - ae424ac5ecb7357a190fc0fca4269507f6541388: prevent accidental triggers (android back & home gestures)
   - f021060c4115c9507c706e39df99b4b8d2b2ae21: add recentlyAdded as queue source
   - 196c140d14b44a2cd0500e580df3fdd4bf03de6f: some tweaks
   - 529dd1f476416aaca53984c1f7bfbe6a66d70aaf: move yt palette to separate folder
   - 331d8a4af85c424c7bb5fdb572b55d1f5b837f83: ui improvements
   - aa572bee1e3e40e8c04c688679915025f78ee404: some fixes
   - a6a1b942a013b060ced1a992ef7ccf8a60a5292f: audio & video buffered separately rendered
   - 4088621840abadabedd89f7f623eeb28dce9203a: write metadata to newly cached audio files (this allows playing them later without issues)
   - c07d210790f1af25e83ac264fe1b7c3687d059ef: ui refinements, progress bar for yt miniplayer
   - f59b865fd74b4b99f612751351e22b6b3861e797: smoother playback, fixes & cache status on card
   - 36bcae59daa7b6ac2587c1bd6d1acb918d261729: more seamless playback experience (will now try to play from cache before waiting to fetch info)
   - 000558501764c2c7403dc8317f3acb78d14543cc: volume sliding only from within safe area
   - 7bc6b98629e2f892f824cfbbeb1908439f361b70: some goodies
   - 69b020b11d59ff907ae9e9d4e3635aa0ffce117e: some improvements & fixes
   - d24238ad781091e071283551faa8b54ec7386a4f: about page, cleanup & prepare for publish
- core:
   - 19b60b94e1e06170b200dec3c5f643d91cfb0624: add yt history import to yt history too
- perf:
   - 4f2e581ba79ffdeb69a132bc26f0801cea3f99db: efficient image request
- repo:
   - 187c0335b43b2323cc6d91f0bc99f62d0c5f0cc8: move translations to separate submodule

## 27/09/2023
### 🎉 New Features:
- feat:
   - 6a11b5929f2a327842110b0bd4c0eb7069de465f: offline playback (consistent video caching, can now play without connection)
   - 068543292614c424d0c8ed7b835f9c6c626aef70: continuos seek on double tap
   - 082442fbe26cee2b34ae4e6f206db7e56240c1cc: full cache support, flawless video info, audio only mode
   - 74bfeace630e4fff1918a7e996fc9fc35dcad297: volume change on vertical swipe

### 🛠️ Bug fixes & Improvements:
- chore:
   - d24238ad781091e071283551faa8b54ec7386a4f: about page, cleanup & prepare for publish
   - a0275fb1a83b05bdaff477a6c43a33f11401248e: video stretch fixes & perf improvements
   - 9ed5c5a3d51480a31e7af102ebbc02aab05bffc1: upstream history_manager
   - 23a11a867d2b7957740081c697c8c21ea8f6aa70: update CHANGELOG.md with a new script to auto generate from commits
- chore(ui):
   - c778696cff25323881997156e4d57d929fb7e2c9: new yt channel card , playlist cards are playable now
- perf:
   - 61dc93b109bddd5c8cf26a3ac7fe5af02cf5d91c: backup dialog sizes computing
- license:
   - c054181c2fd17faa2261bf8e90f81e9fb1b242fc: use EULA License


## 21/09/2023
### 🎉 New Features:
   - dc8a038a2a4465d56b83545c271bea21781f64fd: expose video/audio download metadata tags
   - 74bfeace630e4fff1918a7e996fc9fc35dcad297: volume change on vertical swipe
   - 7618916839627953c21d05878b7479970bcb77bd: youtube history system
   - b8892ef53734cf6ac7cc7c4fb2bb9a30ba3fb9b9: option to write video upload date to downloaded files
   - e92e5ab947abb2d259111326fa14c6c342d0205b: Full Youtube Playback Support, this comes with refined controls, audio caching/downloading, new artist-title splitter, keepFeatKeywordsOnly for youtube scrobbling
   - e5b9f0d32a4d4b3e3123b2eb12e0b99aa78beafe: search navigation button
   - c625bb7c5b385061349a8732f017658a951ba862: youtube playlists
   - d1da50c2f60ac203e1276bb8b36c75f246dc8979: set player (volume, speed, pitch) from within minplayer
   - 75972d3dc352232e659f04d459fa421498f6b2de: onNotificationTap open (app, miniplayer, queue)
   - bea7840ef9dbeceda402fd4ddaad781639252a1e: open yt link from intent currently shows download dialog, later to be exposed
   - 7d1d57682e0ea33964bb272f9928625ad93edf34: option to match yt import by both link and title&artist
   - ea320fb19115bda17673017da641a5d2445d547b: expose infinity queue on next/prev
   - 5ff30db3cfdfea3126330788ae1b40972a843f3d: picture_in_picture (beta)
   - 91d8ccf5ee265403e683068887dbc961ea705e5c: youtube download
   - 020be502049c44bdbd421e319af6e74b7b02e9e5: option to keep file dates when editing tags
   - 4e336452bf3b1a62972e850773b48dba9cbaa506: youtube thumbnail/desc/comments caching, quality real-time choosing, initial video widget, focused menu, shimmer & other stuff
   - e28a79a457b92afd5bde0292c0a9d4f5bfdefcd9: auto skip timer when failing to play
   - e7e763bc6673f58b5f94da830821fbb25cbb288b: (mixes, recentListens, topRecentListens, lostMemories, recentlyAdded, recentAlbums, recentArtists, topRecentAlbums, topRecentArtists)
   - cfb3d40229c22e9992f8a1474247e54a23e1b0cc: separate static color for dark mode

### 🛠️ Bug fixes & Improvements:
- chore:
   - a0683ffd8967a476191a69f55250a628d6a1658f: intent & manifest improvements
   - 2908bbee34d0ffddc93d263389208bc0a40b73bd: av sync fixes
   - 32bb7928a615de2fb2b98d07d77b2c8e53968a54: open miniplayer upon playing a video
   - 4bcb165b40461d9d4936bc5f24758b19c681afd9: re-structure app directories yt stuff in root dir aint lookin gud
   - 20cbe889217204e869e6b72d31d777046a63f306: project files re-structure
   - f97a75269f203c2a9a71daa221e23696b60b1ee0: some ui fixes queue sleep icon & search icon in nav bar
   - ba75788e556f6fad21cc56dcc0bfd048abb3a344: expose searchbar functions this fixes not opening searchbar if pressed 2millis afar also for upcoming search nav button
   - 4d6a905c534b3f0c215b2d221996ea30a6c76d85: pip improvements
   - 1ce739682da2324a0b3e941029b838faf6e7ced5: some miniplayers magic
   - 3cd953bd606fc66caf9344a58cf5df8f9fbb4782: youtube pl cards design & other improvements
   - 247f20ca413f1bb5c48d7ac7549f8f42ad7affab: closing dialogs on pip entering
   - e87d30f735bd2928247d5dd460d0fa8c153ebec0: improve fade effect algorithm
   - 13efe4b3ec58f1ab53458e9c8a37a1c9afff5249: enter pip only with videos
   - 6a6f2796ccf4bb0109c816111092624ec3e34999: refactor toggling enum settings
   - a94ab289607514d65c0c01f2f744d3a7fbcf9e7e: yt download sheet looks saxier also more detailed status for download icon in yt miniplayer
   - 08b4a1d3b7d54ecbe7c92ab42a7691ba286abe38: play decision after removing from queue
   - 9d2270ef3a3426563fc1477f517d05556327e4f5: start pip only if playing
   - dd94450ab87527e4c4e70ed6210d41ce9c6dac9b: re-structure internal directory paths this mainly comes in preparation for video downloads
   - eaad25a01e80d0d18b158b2d1ec5498f4c5702b6: color generation improvements & others
   - 987659509b84effdfad4270d5be58d719491789f: generate all palettes by default on startup
   - 3c74a5e0c0767e2bad70cc0ae71e8326f0a01f65: fix queue scroll animation in some scenarios
   - 4acd110efbd3a235e3d8092209ff631e69b3a732: yt miniplayer refines
   - 740866c403bc8043735ddbac4a1ace5eec007bd0: icon in miniplayer when no connection
   - 9e3ca95657623d2b09b23d4f2fb662ddf8fedbec: chips for sorting cache videos
   - f8dd83c30a785bab47f7981809749b56ee602519: ui tweaks
   - 09100399c2c090e8df37cd31d5d2507691fedb82: some improvements/fixes

- fix:
   - 4f7b399c82e9aebf13acfe1f54f137a1e685c1fc: strecthed video in landscape
   - 2b665a5f4fea245c0d21b63efd1dd6d95ba219b9: downloading cached versions
   - bd691467ca68df5012d5372b4c19033b1db594a7: removed number from queue
   - 8f10894d60a87e1a83dd1ab7cef9077274de5b3e: keep cached version when downloading same version by default it was being deleted
   - 061338d15d27779d5799095ccf7049bbdce8e12b: queue favourite button
   - c5894601c78feb1f7fa271fd3834b39736907adb: folders onWillPop
   - 2813aca5853160b8ef97ca649f5f768c9e2a5624: artwork rebuild
   - 90d419d228e110f359bc7375062d9df18d76aa83: yt-dlp thumbnail fix improvements (wont move file back if failed)
- code:
   - c9fe5d1ce1357b764ef894036ade7eda65167e95: move history logic to separete mixin this comes for youtube & local videos history
   - 96f46fcffe88ee290f34db49333d39583f7d27d2: yt miniplayer custom implementation
   - b95cb58a9ca937f6e558cb4ab7d2af138e90b7a3: refactor playlist class to mixin this comes for the upcoming youtube playlists
   - df92c31a72f27e901fc85237b7f8cdad45fe7508: refactor unknown tag fields
   - 7cda5e648ed888ef0d2e42ff31a5a51d86a54924: refactor app dirs & paths
   - 398ce616295bf260c34697821448931e0290dd83: refactor AnimatedCrossFade this also includes the fix for jumping animation
- chore(lang):
   - 58773e34f2416a4dd4dfe480a8643cb7b890b97d: update translations
   - 85aaa50aa32153234f32196ce156ed2f5a2182d0: update lang keys
- perf:
   - 4ef3888475f7272db25ac9735ddf185b6844a59f: run some function in isolate
   - 9ec1ccec78d4b71ceaffed7a5eaa1116c6172904: move search to isolate


## 20/08/2023
### 🎉 New Features:
   - 2db0a933ec9fc8c4d443c461eec01d272bd822c7: expose video matching algorithm
   - 852403209435edd9aae73b26b110001347a39c67: advanced option to fix yt-dlp big-sized thumbnails
   - c7b6815076fa44ed4fe503c8d7b70bd67e3bfafb: option to compress images
   - 1d3d2652b1592744b5675e854ee753b2615e890e: time ranges for most played playlist (day,3 days, week, month... etc)
   - ec8bd40489fca22cc8f5601c3237beace37c5ed6: history import report with missing entries and ability to manually add them
   - 6343789257b26ce90f664df9410f3d817bbea65a: advanced option to replace history listens
   - 66b54ffa21d0f83415835b0eb3e895e556456b5b: advanced option to update directory path extremely useful if the directory has been moved, also optional check to replace only missing tracks
   - a1a8d7d01d8553b533cad1615d32dd4cd22d037c: manage queue generation options exposing insertion parameters like (tracksNo, insertNext, sortBy) for each insertion type
   - c59eb1f954883c90b614fe7ab076f0c5623005db: display more video info in miniplayer
   - 27925363f107a9901079ed63fca1d56e6aba78f3: expose interruption events (pause, duck, do nothing)
   - 0f9108df6d1d3f72d87d21c830f55fd4fcd9d94a: option to pause/play on volume 0
   - 71a0a8239b898b5f59cc9ac6395276c104d20ce6: some other ui improvements
   - 55fd12e571c61c425e31baf44f726556b0e9c629: empty playlist page design
   - 583dba589d4eb44f227edcb40685ac6acc8681ea: new sort: shuffle
   - 76c955c47b564c0f10b0bd483a981fc40b7ca5e9: option to shuffle all tracks or next only (as default)
   - bacda78fe9358d6c9c8a7c74d49adb9ef7491538: saving youtube stats when importing yt history this comes in preparation for future full youtube support
   - 85716488f2130d05d67c0e8d1ed80c9e5c24b896: option to match all tracks when importing history
   - 002167516c6662f9e0a98c11ceda37036ba45823: expose track palette for customizing
   - 49d68818af0e9c98fdf273fe6ca022f88f00bdb4: display duration difference while seeking
   - 388beda87efd364c727620b1450fe11932f98c0d: script to automatically add language keys
   - d1357894b0979f769e4ad32213386c05fd9936b0: localization support
   - 783ca13781bd410d8bd17224e64f5f17a2785b27: animating icon while refreshing library
   - 2f6692e064c775ea1ee4627ab49f5e47e2f24620: advanced sub-dialog in track dialog this comes in preparation for exposing color palette to edit
### 🛠️ Bug fixes & Improvements:
- chore:
   - e84698b36b83985129b9e6b2de8e747505da533e: smol ui tweak (yt download)
   - 2e7eb7a87c403b0a3980ac9d4564a64f07db39cc: restoring last position only if not at start
   - e4fa3ea9966a819ce865ae4a34338f6afccc185c: few fixes
   - e9bfd19594855b3896808d292dfc99f8d96cf6df: playback improvements
   - a32173b05ae70b4dad036bb2634bd03ff681d15c: fixes/improvements
   - 85ff243b75c56d6049f30ffd3577f2a609481513: various fixes/improvements
   - 6d712679293ecebdd75a86ba03f4ebeffb1865f6: video-related fixes/imp
   - d4262bf27f3fc6c7afb1585e62e50f601e554fc3: minor fixes
   - 6481bed47cc8df65d19609be890dcb3789e40f0b: fixes & improvements with the new queue system
   - 8d2eb7773da44ebe0dd299517b22fdc65f66c2c6: various fixes/improvements
   - 10bdb2633c517790831d4bf3dcbb4e87c31f1b03: minor improvements
   - 468e749e357bfd12f8817f4319d707312d5b2b90: catcher logs
   - 08486fb677e8eefb0393e7540a91903862e20c04: various fixes & improvements
   - 6d9dd5b0c06ca6cd98f535ccad7a9e648576bf62: various ui tweaks & improvements
   - 44eeed809c17826c44344283783459342bb241ad: miniplayer seek ux improvements
   - a14b474527a5cf2c5172d4d88c45b8f1bb72b63f: theme updates fixes/improvements
   - 9e6a6429c19ae9ec1e2644e9d39022c1ece6546d: minor fixes
   - 2ac96fb229d3b1ded78bf03d51d2f05760687837: sorting .tolLowerCase()
   - 7c8fd641cf794b88660875d96364e34962f0015d: extracting empty metadata fields from filename
   - 7844631560890f0328a957bbea0b177ec2692b58: miniplayer seeking on tap
   - 95f7e7a1b86df81dcefcda1fcb9f05760c9f10c8: minor ui fixes/tweaks
   - 5bd32a7e1ee891431662f688c3b53c7b1db6991b: minor changes duration of track class is in seconds now
   - 9451ea1b0a2c23086c306cd8e2f1ee951c481edb: redesigned some menus
   - 5f387ed925b37011b45877ba45c19447fd9cfd71: hero animation for multiple images parallex

- fix:
   - 5db83eaa2aa6ba4fe6ee9dff03a8a438107fd48e: split config real-time update inside isolate
   - da5288e22e48a98e908c5378322e053d65dba5cd: saving track last position on all possible occurrences
   - 29a8b31160cc781744dad92d074d8c1dc72a7df2: color not updating properly after queue reorder

- core:
   - f443ae06ad181c2c6811f6cb916cc9a16a6f864d: switch to ffmpeg_kit critically needed due to crashes caused by media_metadata_retriever
   - 77d59d101a8689c96d848a81bbc17765d2f0ed36: loading queue & history in chunks faster fetching but in cost of performance
   - 5e0593e1eb840d6fa119c567a352f1c27754c502: switch to better_player
   - b83055bc540b9dc0ed98fbf91544931779e6e5be: dimensions internal logic change this fixes unexpected behavior, as it now calculates on demand not on navigating

- perf:
   - 09c82629fa74963b6414bafa67910efd64926df7: colors logic
   - 9f0a185ea15afc9d2c13a776e7523b0aa14aac1d: loading history/queues/initial files in isolates huge leap, isolates finally listening to me
   - 019f21367b7bcf5ea975dff42605852db8379dab: jumping to same queue item will not replay will only seek to start
   - 9191c5c68da33ab6c4b7598db0e418b50b2e2421: refactored language converters to single map
   - 6d8d5399b6ea63ead2312e2ea1da28bfc2beb2d7: im no longer limited by tech of my time switched waveform generation to amplituda
   - 8e8e448c39c77a3ae55c3edad8f269cedb91f45d: yt history matching (tracks.length)x faster lookup when using link as a match type
   - 26b1496db6c1dc05a37955927cf2b2635d4991b6: prevent reduntant waveform rebuilds
   - 78ed75e863416a30b42b7578836ed998df4b2ba6: generating from moods logic rewrite
  
- hotfix:
   - 698eb4d4b7a5fd00049162248ebfecf9ee4e021f: sleep timer for tracks
   - 4a106458eaef58d91eb5ff59df10acd74db4b3c0: miniplayer unresponsive after removing track
   - 53f2debe487078e9b3fa82443470c99f4d4a3d49: notification update

- code:
   - 51a59a5eea20db8c4b58d1b0134ca88ceb2406df: refactor fixes smol issue with backup items
   - 2d575de2258bf39da5c45f7f4fa9d268fd5a65bd: rewrite audio handler queue logic in preparation for future videos queue support
   - 595aee95294af4696b8d3e82be497c5c5c461743: refactor
   - f4116848802336ca2f2b6a3f266df51d00f6ef8b: minor refactor
   - 7168924663c924f36488a26e0d9081eabd4324cc: refactor track classes -> this addresses & fixes few issues and improve general readability
   - 0e07e86bca52ef8e831609da41aceaf37c0c6280: video logic complete rewrite this comes with new metadata retriever (width, height, dur, fps, bitrate, etc..), support for continuing youtube downloads, and many other improvements
   - 08602c883cc8eecffa27ea9f4c1ebd5feb8536ef: classes refactor
   - 73a8923fcdde010f288e8549ee14e040eca8f262: refactor tags dialogs
   - 35893052ff9e485342273f13ed07ddb21a0aac2d: massive refactor switching to faudiotagger significantly faster multiple tracks metadata editing


## 18/07/2023
### 🎉 New Features:
   - b662691603109f11a7b7ba7addd843d6fa566829: support removing multiple tracks from playlist at once and other fixes
   - 026252ad4c9acedfdc2b04375c0773cc2125bd19: import to history only between time range
   - 46cbe7c5b4a43763a09ddd70114e02195344e3c2: handle adding queue while loading queues files
   - c43ce52bbcfd67edab9b3d2e772a906cd64d1ae0: favourite button for queues (soon will be used to auto-delete non-fav queues)
   - 5216a7353c337e32e2fceef53445446437b56a71: skip silence
   - e57677e51e8be029b7b7af7280ad22f0b8a21984: generate tracks from similar release date
   - c1b933c2e496c55e86689acd2060606b441c48bf: toggle jumping to first track after finishing queue
   - 5b2a27e0d514c5b794ef936de46e946a406ec64d: preview track in trackInfoDialog
   - f7813cbef6fe7e82054607736e5f3fc742122b86: notification when adding source to history
   - 185d0ed4920a87f09216e6f95b3a2c76253d4b89: jump to day inside history
   - 364c9898003f958744950ffd192595d03c5d9634: new playlists logic, history days, (history.length)x faster startup. startup will not wait for history, history is categorized by days which will sync load along with startup.
   - 8b95e6d2866763e1ed07c0a3dfc9bbed48fb0c0a: tapping inside scroll track will not scroll anymore
   - 2963885e7c0549406c781b858b3698207e19dd97: tiles animation when changing grid count
   - 3daa560f10266920193e4b341b3cfb28efafac71: button to scroll to track after go_to_folder
   - ce03cca7b908299f2e7a248e9b105d5e31d70966: option to seek by percentage

### 🛠️ Bug fixes & Improvements:
- fix:
   - 02d650180a116580b76c4de251107fa0fa47716b: miniplayer non-accurate seeking and other improvements
   - dbf318ee864ef2aafe614c1d308e09cf4d4e622c: latest queue not always being loaded + minor refactor and startup boost
   - 87b666e89ce33cca63c48bccad1915306b9d512c: dimensions
   - b9028f9400c82fae599022386cfef70e364bba56: Custom onWillPop for Dialogs
   - daaffe91316247de464dd27392fff86d502e0432: cards dimensions not being updated for search page
   - 961b6c7cc1b8dcf7d6587dbc72ee160882428708: calculate all item extents in history for instant scrolling (ex. when tapping on listen)
   - 4c419459dd9b3299abf3f79d07c1f1a97d966314: ui bg fix when navigating
   - 92131422fd4990ff2bcd1479330b19a71b931245: media filter bar not hiding on close
   - c66d40c9a49ef54cbdf991e768e1c56f12db8a8d: hide reorder icon for history & most played playlists

- chore:
   - e0b8e20ef662de6d8334b1591034e06271dcd064: display track number instead of index in album page
   - e76982916ed9d9467a5357299f325bf2ad3d2cb1: minor refactor
   - 627b0feac567c1d13b97bd71cc7bf506cae591e9: tweaks and fixes with navigation system & ui
   - 067ad9a36c8b4ff80b6b4da2bedf267d5a5ef1ed: various fixes & improvements
   - 6aa1a8cdc3799e1b65c48ff495dc44561dc113b0: perf & ui fixes
   - f162f35f11f2c9d5414980e7e82d46603b58035a: various ui tweaks
   - 00d65960c46d77a2b01881cfe60a22b96d0fb8f7: fixes & perf improvements
   - 9576584dc0fad31d2c6ba33e4c92c33220b6fe65: mostplayed sorted by last listen if listens are equal
   - 6f10e8ca63ce5f9ed2fa50f64d253adc95679538: support if history loading took more than 20s (â›â€¿â›)
   - b7f21659b0cdfaca92fe77e8b8dc80c783f91f55: ui colors tweak
   - bc199a9a6c7f71b3f1115f5fa92985c445cb5f31: disable staggered animation when changing grid size
   - 05a51e45aa793abc0f97c509c73bce22b416d584: new color api (used, mix, palette). (opens the door for user choosen colors)
- code:
   - 97fc15010c143390575ef02076586e6efae53de8: refactor buttons
   - d9660517f0c699eca947b19b7a20a7776db8b39e: refactor tracks generator
   - e11cc0b09fdb7fcdea48cb4b2c7a244a2614e5ac: refactor print functions
   - 5607cb20520228029633e7aacf9434c7de17ef37: refactor using new extensions
   - 4d35b4fe7d825689326f2362d321c1cd9000bb0b: refactor, expose miniplayer and fixes exposing mp allowed for minimizing it while navigating
   - 48c92a53c6f3040c77bcd29024d48e07821f1974: refactor comparables
   - dc7e3be3afc828429455ac983223cde7a6da9f20: refactor searching & sorting
   - 4017575bd53ae08705d713816ea1e179e9ed0fee: artwork widget refactor & perf
   - 55b1de75658a620d60455c7c833d4a44bb1e4ae1: refactor, dimensions class & performance boost all calculations are done on demand, no more calc within cards/tiles
   - 3788866279defbb9419530e293d9f33ad6e281ed: refactor InkWell widgets
   - 4394d24d5d62b8aecdcf00478cfe6f9577a7cb16: queues logic rework
   - 3791622b42a1bd4bae7d22cf86b2dabd727b3e16: new return type for getTitleAndArtistFromFilename()
   - cd9e6771287c85cfd14fd947f8b8edc725942d69: project refactor using new extensions
   - e0b0fc36d02deedcf76bf77a8bac282979608a76: refactor ExpansionTile & ui fixes after upgrading flutter 3.10.5 broke some stuff
   - 1b9169898cf4bf6e1f8e124a7c89d316097250bb: refactor search field controllers logic
   - 9fa7903c114f101b34187b1bca5b6be7fd81d847: 21 new extensions
   - 5bb45d97ccf2dfd6f8b60f0e9054359e1255e2bf: refactor + save scroll position for tabs
  
- core:
   - 9197176d822cc7ed82520c3e6d92e066ada48eec: various fixes & improvements selection container, adding to queue when empty, renaming playlist, and more
   - 91180319b48080bf75aa8a175a824bc1d1a81ebe: various fixes and improvements history days are now accurate, faster startup, fixed recommended tracks algorithm
   - e8fab4bab2b88ba53609303ffca966e0a6622598: routes are now saved as reference, not real classes, this heavily boosts performance especially for pages with lots of tracks
   - db78e13c74877c59bc25d384b352190dc3b3d58b: migrated to Flutter 3.10.5 & Dart 3.0.5
   - 2cfedacaa1e1de1912579ccfac5acc8e237c69d7: lazily initialized static methods
   - 42c3f9b8dfaf0403c68c2657ce6096946dae48ce: new navigation system & massive refactor i.e. performance boost

- perf:
   - b42e1a0238bb05baaa7e92abf1b7f69bf8677265: histroy track listen navigation. going to a listen from within histroy page will only jump to it, no new route.
   - a2c2f9aaa09e84e8cba2fe93a5c31369fcc9a85e: improve recommended tracks generation algorithm
   - 82ed59842d6afb944db6baeccdc03d06bcd954d4: artwork won't rebuild redundantly


## 07/06/2023
### 🎉 New Features:
   - 0d12d94fac18a55f2a4a2dfa27fdf3532cd8353a: remove source from history
   - a0726391ce28f6ad94f2ed35014dca41adb8131b: new sorts
   - f514fc632718583e8123e87d4225f682d8fea39b: sleep icon on sleeping track inside track tile & performance imp
   - 6325045b9846c67d84b955093370d731e115fe9f: new listen counter when seeking backwards
   - de2fd57d3a5b840a81f377a4e5b90f53f18468cf: restore last position (configurable)
   - 6e17e740e603de58bd616be7caf02496627cbe43: indexing no longer required for separators
   - 60ee548a964eeb309599c4d896c51d0f17126201: long press image to save to storage
   - 99254f18daa873e6317426defe2e29524dcb478c: stats for each track & generate from rating
   - 319b2d3de346722bf9e421a32394d08eaf3e5a89: generate tracks from modes
   - aa8c461188869e3813cf4bf3a36133ce2804d217: total listens inside track info dialog
   - fa61e7a113004fb3969ddd9ca1855c5f013ec55c: remove duplicates & insert after latest inserted
   - 634c41df18636e896303d558308176e9656c3645: artist/genre separators blacklist (unsplit)
   - 59310328fd4ab40e0c0d298d2b0880b8f340a2bd: info dialog for track
   - d02328aa6a31a97aeba7c0dd33b800aeaf034a36: import lastfm history & yt match by title
   - a7f5deee344b4786bc8075add0245265ca082f4b: support deleting queues
   - 0519a302bd48706910abe6b937a6c1a00f6d08f9: display audio format in miniplayer
   - 8dd6ffdf1b990cb7c5fc0384ce2d9ed22fdf483a: enable/disable auto play on next/previous
   - 886ff72f88afc501e65b155cd39db9bb90b3139d: support playing multiple external files
   - 05405e24a58e1747732299d1cc25604de5d2c7ae: track source for playlists
   - 10ba0cd19b800964274873b236e20a3dae8ee7b5: enable/disable scrolling navigation
   - 05226261d93235e5d4ef6f809862ea4f6bce4969: play android shared files
   - 3474ebcbff5408c16b4925eadef5200a0d27bafc: display track number in album page
   - 47739ea7f2c7787931b0f8a117e71b5460050e37: import youtube history to namida
   - 9bc80fc8f5bcd5872f200e95bf7362944881f342: search page completo
   - 822160f31527db1f702c9763f40df773e448a206: generate tracks from time range
   - 65a79f1b97a96ad517cd4cc4ded3d49d10f46174: youtube page & miniplayer
   - aef4e3eaf220a7e471488b42b269d1b50131ebd7: enable/disable miniplayer particles
   - a1d00a972208130e1959412d59b8a10fd534e84e: share & play all in dialog
   - 62152b97169cf7ecb9b716688c0c9445bcf4d573: algorithm for generating related tracks
   - 4abb8b74b9928f0af900bf1208cbd64becbc8310: choose cached videos to delete
   - a5b05b5442ede4a988eb94dfd844c2bbff3d3f81: option to disable bottom nav bar
   - 3f6a5375cc6719f26583b4443d23ab057da8d7a0: dismissible queue tracks, stability & ui/ux improvements
   - 2f8a9bad8200bf6851f2db9203b721af7fdf15ee: dismissible queue & playlist tracks
   - 43f49ec19880e16cbbc494475943fb7ed2e02205: search text cleanup option
   - 17a22fffd0cc7425328b89f68422d59f468f6476: repeat mode (none, one, all)
   - 23df59f4186703dc767a759e1561c88a9adfd45f: tapping on pos/dur will seek forward/backward
   - d43c4217d8e9f47d264978a14156f96638dc0841: shuffle queue & scroll to current track
   - c902d4c8ca12146b83056681ca92baa656d5d706: reorderable queue
   - 3dc20d863d6365f7e9fb29bc913a33a88dafdb5b: select all now selects the current tracks
  
### 🛠️ Bug fixes & Improvements:
- chore:
   - aa6876f9155253461e524971cd2a4c75e5d79df3: separator extension & refactor
   - 14712578eeb00c042f1a1b2271408e5a307a43bc: small refactor
   - 8646ca8c4367cb61f8f0e372a7073399cd9dc771: widgets rework & refactor
   - 5a90cae8bd9e895264d9c5856e0f3d9349d477a0: pages improvements
   - 2795637ac927d4998e98f73d0506cb0b7e8d8c1c: miniplayer improvements
   - d9b56bbe0fbeb5805aa3470356450f393e3302b2: massive improvements and refactoring
   - c485dfe48b38be18093cc3acec6c551f6c562819: constants variable names change
   - 49af0d2e85af15507d01aa2fd6442123e4e08b75: moar fixes
   - 49ba5547962335f2927e7b1bf8f0c20532e211d7: small fixes
   - 766aefe03ff0c67affd069c4c7674877ef0391aa: update dependencies
   - c64046120d6eb7132a26e7d8f1ac982c8818669c: fixes fixes fixes and refactor
   - 9d63ee63e966f76c59adef106254278461c7c8fe: new design for default playlists
   - b57a5439944f64dc6fb86f178de82f659416ccf9: folders logic wasnt perfecto so i perfecto
   - 276cd7371f436bfe19e62f7bcaf0e5e61877655b: migrate to dart 3
   - 3a1c301b876d227893d0a46a01fdb88c4cd60793: update dependencies
   - 1ff87eb36bfbf36fe428ee97f4196542e3947ab4: guide for youtube history import
   - d568af4aaa45d80036af7c3e407a6b9188d96573: refactor
   - 14deafa774068a9dcd166171520921b37e386454: improvements & fixes
   - 8d1a6e6ecaf58e931a6c3cb9bc5ea1f5be5573c0: improvements & fixes
   - bf19a46a80fa9fdad227bc8f2a5f4dbcd95f1c2a: switch to sembast
   - 5e7ed9c8f4f2ad3d8a04b7ddd02bec34852cb9e0: folders logic perfecto
   - 62a5a9c51dbac4b58143114165a2cadb4897b35f: classes for media types
   - 1ae1c9800fbf29cfe1a918f19e82e5efdf708e5c: play-all buton for album card
   - 3f0d83ff37bc60b8766299812e641c4fc4b710eb: fixes and improvements
   - 24724f6133ab3847b09f4af3310c577306bf7ae1: improve auto extract tags from filename
   - 8d154da3ce9a598cc52bd1ab7a380372b520e385: improvements and fixes
   - cb4f3fd165dc22e10ba5090e79c3bb8eeaa5c79f: drawer more items & design improvement
   - aec65a2a99296441b6d35d009efc2af536a73e75: coloring & notification improvements
   - cf19debba7f38f74adbc067e7611d3f59f69f600: improvements for video lookup & playback

- refactor:
   - 59f3cd68b312034d7137b5bb143380dac9db5d1d: separate file for converters extensions
   - 100bf3d7c917ce5b08d1abf48c60e91a7515ca43: project refactor
   - 01e3c1a69ae5b24171fa2229ce1445f464c664ac: code refactor
   - 40ba7caae666c2c80becfcfea495d828382057c9: audio handler complete logic rework

- imp:
   - 99c424fe7aadd9966eceab98fa879589ce48fa96: lastfm import handles missing dates
   - 7196cb684a134d1c2a09f6e39e9832834e38aa4f: playlist modified date + improved methods
   - 23e1be72bcee950e5dea52725e668c76ce05ea31: multiple tags edit rework with progress tracker

- perf:
   - 4ec032f6d4b3901b20089b93c36dad1a9fadd06d: settings files min 3s between saves
   - 996079cb8d5cba9d1d625b5ea5e8ba8b82dbca44: startup fast asfboiii
   - 5fd73ae2368f42e2d02602da39b62502ea9403cd: optimizations
  
- fix:
   - d02e50d0699771e83fa372b3142b3becb888054c: deleting queue from storage
   - a56d92c3a56a079bf50c0c70856c3885cccde995: a56d92c smol fix
   - 77665ad3c89576ce453f5dec7b9c6b5797d4485b: keyboard hide decison
   - 1ff4a07d49dc46cc0b6092ded4c2edbf5e4b154e: juuust a small fix
   - 42faa11e14948d1ac32bc596e520595c04ab8c8e: fixes & stability insurance
   - 3d49a5ab64f9748d48ef76d0b0a6915ae51914f3: fixed static library tab not being retrieved

- dialog:
   - b07cfb13d2bfe960901060d43602c4979e25a036: option to hide unknown fields - repeat for N times - insert after latest inserted - add more from this (media) - extract feat. & ft. artist - major refactor and core improvements - tons of work under the hood, lots and lots of performance improvement and drinking tea with buggies
- code:
   - ccdd3e90c924f94a91dfe2ba95528283608f32e8: insertSafe() & insertAllSafe()
   - 06334ae1233688a0a7a90e432013dcaabbb13b23: performance goes brrrrr (also adios sembast)




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
