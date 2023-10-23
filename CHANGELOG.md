# Namida Changelog

## 23/10/2023

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
