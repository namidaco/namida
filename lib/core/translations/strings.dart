// ignore_for_file: non_constant_identifier_names

import 'package:get/get.dart';

class Language {
  static Language inst = Language();

  /// Youtube Miniplayer:

  String get YOUTUBE => 'Youtube';
  String get USE_YOUTUBE_MINIPLAYER => 'Use Youtube Miniplayer';
  String get AGO => 'ago';
  String get SUBSCRIBER => 'Subscriber';
  String get SUBSCRIBERS => 'Subscribers';
  String get SHOW_MORE => 'Show more';
  String get REPLIES => 'Replies';
  String get COPY => 'Copy';
  String get GO_TO_CHANNEL => 'Go to channel';
  String get FROM_NOW => 'From Now';
  String get A_MOMENT => 'a moment';
  String get A_MINUTE => 'a minute';
  String get MINUTES => 'minutes';
  String get COMMENTS => 'Comments';
  String get LIKE => 'Like';
  String get DISLIKE => 'Dislike';
  String get REFRESH => 'Refresh';
  String get SUSSY_BAKA => 'Bruh no tracks';
  String get DONT_TOUCH => 'DON\'T TOUCH ANYTHING';
  String get PARSED => 'parsed';
  String get ADDED => 'added';
  String get IMPORT_YOUTUBE_HISTORY => 'Import Youtube History';
  String get GUIDE => 'Guide';
  String get IMPORT_YOUTUBE_HISTORY_GUIDE =>
      '1. Go to _TAKEOUT_LINK_\n\n2. Deselect All and select youtube only.\n\n3. Press "Multiple Formats" and beside "History" choose "JSON".\n\n4. Press "All Youtube data included", Deselect All and choose history only.\n\n5. Create Export, Download & Unzip.\n\n6. Choose "watch-history.json" from the next screen.';
  String get CORRUPTED_FILE => 'Couldn\'t parse file, it might be corrupted';
  String get ERROR => 'Error';
  String get COULDNT_PLAY_FILE => 'Couldn\'t play file';

  ///
  String get REMOVE_WHITESPACES => 'Remove Whitespaces';
  String get MINIMUM_ONE_QUALITY => 'Couldn\'t remove quality';
  String get MINIMUM_ONE_QUALITY_SUBTITLE => 'At least 1 quality should remain';
  String get CHOOSE_WHAT_TO_CLEAR => 'Choose what to clear';
  String get SET_YOUTUBE_LINK => 'Set Youtube Link';
  String get COULDNT_OPEN => 'Couldn\'t open :(';
  String get COULDNT_OPEN_YT_LINK => 'No Youtube Link Available for this track.';
  String get WAVEFORM_DATA => 'Waveform data';
  String get WAVEFORMS_DATA => 'Waveforms data';
  String get CLEAR_TRACK_ITEM => 'Clear Track\'s';
  String get CLEAR_TRACK_ITEM_MULTIPLE => 'Clear _NUMBER_ Tracks\'';
  String get MULTIPLE_TRACKS_TAGS_EDIT_NOTE => 'You are about to edit these tracks,\nEmpty fields remains untouched.';
  String get DELETE_PLAYLIST => 'Delete Playlist';
  String get REMOVE_FROM_PLAYLIST => 'Remove From Playlist';
  String get GO_TO_ALBUM => 'Go to Album';
  String get GO_TO_ARTIST => 'Go to Artist';
  String get EDIT_ARTWORK => 'Edit Artwork';
  String get MIN_VALUE_TO_COUNT_TRACK_LISTEN => 'Minimum value to count a listen';
  String get SECONDS => 'Seconds';
  String get PERCENTAGE => 'Percentage';
  String get AUTO_EXTRACT_TAGS_FROM_FILENAME => 'Auto extract from filename';
  String get PLEASE_ENTER_A_NAME => 'Please enter a name';
  String get PLEASE_ENTER_A_DIFFERENT_NAME => 'This name already exists :(\nplease try another fancy name';
  String get PLEASE_ENTER_A_LINK => 'Please enter a link';
  String get PLEASE_ENTER_A_LINK_SUBTITLE => 'umm.. is this a youtube link?';
  String get UNDO => 'Undo';
  String get UNDO_CHANGES => 'Undo Changes?';
  String get UNDO_CHANGES_DELETED_TRACK => 'Undo deleted track';
  String get UNDO_CHANGES_DELETED_PLAYLIST => 'Undo deleted playlist';
  String get COLOR_PALETTES => 'Color Palettes';
  String get HOME => 'Home';
  String get SET_AS_DEFAULT => 'Set as Default';
  String get HISTORY => 'History';
  String get FAVOURITES => 'Favourites';
  String get MOST_PLAYED => 'Most Played';
  String get LYRICS => 'Lyrics';
  String get VIEW_ALL => 'View All';
  String get TRACK_PLAY_MODE => 'Play Mode';
  String get TRACK_PLAY_MODE_SELECTED_ONLY => 'Selected track only';
  String get TRACK_PLAY_MODE_SEARCH_RESULTS => 'Search Results';
  String get TRACK_PLAY_MODE_TRACK_ALBUM => 'Track\'s Album';
  String get TRACK_PLAY_MODE_TRACK_ARTIST => 'Track\'s Main Artist';
  String get TRACK_PLAY_MODE_TRACK_GENRE => 'Track\'s Genre';
  String get ENABLE_REORDERING => 'Enable Reordering';
  String get DISABLE_REORDERING => 'Disable Reordering';
  String get DISPLAY_FAV_BUTTON_IN_NOTIFICATION => 'Display Favourtie Button in Notification';
  String get DISPLAY_FAV_BUTTON_IN_NOTIFICATION_SUBTITLE => 'Thumbnail might get displaced.';
  String get REPEAT_MODE_ALL => 'Repeat All Queue';
  String get REPEAT_MODE_NONE => 'Stop on Last Track';
  String get REPEAT_MODE_ONE => 'Repeat Current Track';
  String get ENABLE_SEARCH_CLEANUP => 'Enable Search Cleanup';
  String get ENABLE_SEARCH_CLEANUP_SUBTITLE => 'All Symbols and Spaces will be ignored';
  String get ENABLE_BOTTOM_NAV_BAR => 'Enable Bottom Navigation Bar';
  String get ENABLE_BOTTOM_NAV_BAR_SUBTITLE => 'Items are inside the drawer bothways';
  String get NEW_TRACKS_ADD => 'Add Tracks';
  String get NEW_TRACKS_RECOMMENDED => 'Recommended';
  String get NEW_TRACKS_RECOMMENDED_SUBTITLE => 'Generate tracks you usually listened to with _CURRENT_TRACK_';
  String get NEW_TRACKS_RANDOM => 'Random';
  String get NEW_TRACKS_RANDOM_SUBTITLE => 'Pick up random tracks from your library';
  String get NO_TRACKS_IN_HISTORY => 'You don\'t have enough tracks in history.';
  String get GENERATE_FROM_DATES => 'Time Range';
  String get GENERATE_FROM_DATES_SUBTITLE => 'Generate tracks you listened to in a time range';
  String get NO_TRACKS_FOUND_BETWEEN_DATES => 'this timerange doesn\'t have any tracks.';

  /// Main
  String get EXIT_APP => 'Exit';
  String get EXIT_APP_SUBTITLE => 'Do you really want to exit?';
  String get PERMISSION_UPDATE => 'Permission Update';
  String get STORAGE_PERMISSION_DENIED => 'Permission Denied';
  String get STORAGE_PERMISSION_DENIED_SUBTITLE => 'Please allow access to be able to perform this action';
  String get CHOOSE_BACKUP_LOCATION_TO_EDIT_METADATA => 'In the next screen, please choose your backup location "_BACKUP_LOCATION_" in order to edit metadata';
  String get CHOOSE_BACKUP_LOCATION_TO_EDIT_METADATA_NOTE => 'In case you didn\'t, please go to settings and reset SAF Permission';
  String get METADATA_EDIT_FAILED => 'Failed to edit metadata';
  String get METADATA_EDIT_FAILED_SUBTITLE => 'Consider resetting SAF permission in the settings';

  /// Playback
  String get PLAYBACK_SETTING => 'Playback';
  String get PLAYBACK_SETTING_SUBTITLE => 'Can be accessed directly in the player by long pressing the video button';
  String get AUDIO => 'Audio';
  String get VIDEO => 'Video';
  String get LOCAL => 'Local';
  String get VIDEO_CACHE => 'Video Cache';
  String get VIDEO_CACHE_FILE => 'Cached Video File';
  String get VIDEO_CACHE_FILES => 'Cached Video Files';
  String get ENABLE_VIDEO_PLAYBACK => 'Enable Video Playback';
  String get VIDEO_PLAYBACK_SOURCE => 'Video Source';
  String get VIDEO_PLAYBACK_SOURCE_AUTO_SUBTITLE => 'This will give priority to local videos, if not found then it falls back to youtube video';
  String get VIDEO_PLAYBACK_SOURCE_LOCAL => 'Local Videos';
  String get VIDEO_PLAYBACK_SOURCE_LOCAL_SUBTITLE => 'Checks if any video file (found inside the choosen folders list) has a filename that contains the filename of the track';
  String get VIDEO_PLAYBACK_SOURCE_LOCAL_EXAMPLE => 'Example';
  String get VIDEO_PLAYBACK_SOURCE_LOCAL_EXAMPLE_SUBTITLE => 'Alan Walker - Faded.m4a\nVideo Alan Walker - Faded (480p).mp4';
  String get VIDEO_PLAYBACK_SOURCE_YOUTUBE => 'From Youtube';
  String get VIDEO_PLAYBACK_SOURCE_YOUTUBE_SUBTITLE => 'Checks in track\'s filename & comment for any matching youtube link, videos are cached for later use.';
  String get VIDEO_QUALITY => 'Video Quality';
  String get VIDEO_QUALITY_SUBTITLE => 'Highest quality available will be picked.';
  String get VIDEO_QUALITY_SUBTITLE_NOTE => 'It\'s always good to keep more alternatives in case a quality isn\'t found, otherwise it will fallback to the worst quality';
  String get PLAY_FADE_DURATION => 'Play Fade Duration';
  String get PAUSE_FADE_DURATION => 'Pause Fade Duration';
  String get PLAY_AFTER_NEXT_PREV => 'Auto Play on Next/Previous';

  // String get PRESS_FOR_MORE_INFO => 'Press for more info';

  /// Stats
  String get STATS => 'Statistics';
  String get STATS_SUBTITLE => 'Here are some info about your library';
  String get TOTAL_TRACKS_DURATION => 'Total Tracks Duration';
  String get TOTAL_LISTEN_TIME => 'Total Listen Time';

  /// [Setting Values]
  ///
  /// Theme
  String get THEME_MODE => 'Theme Mode';
  String get THEME_MODE_SYSTEM => 'System';
  String get THEME_MODE_LIGHT => 'Light';
  String get THEME_MODE_DARK => 'Dark';
  String get THEME_SETTINGS => 'Theme';
  String get THEME_SETTINGS_SUBTITLE => 'The overall vibe of your player';
  String get AUTO_COLORING => 'Auto Coloring';
  String get AUTO_COLORING_SUBTITLE => 'Automatically pick player colors from current artwork';
  String get DEFAULT_COLOR => 'Default Color';
  String get DEFAULT_COLOR_SUBTITLE => 'Set a color to be used by the player';

  /// Indexer Settings
  String get INDEXER => 'Indexer';
  String get INDEXER_SUBTITLE => 'Manage your music Library';
  String get RE_INDEXING_REQUIRED => 'Requires Re-indexing';
  String get INDEX_REFRESH_REQUIRED => 'Do a Refresh after changing this';
  String get RE_INDEX => 'Re-index';
  String get RE_INDEX_SUBTITLE => 'Rebuild your music library from scratch';
  String get INDEXER_NOTE => 'Note: Incomplete Number of Artworks refers to the  duplicated & not found Artworks';
  String get RE_INDEX_WARNING => 'This process might take a while, depending on your library size.\n\nArtworks will not get re-indexed as long as they still exist';
  String get REFRESH_LIBRARY => 'Refresh Library';
  String get REFRESH_LIBRARY_SUBTITLE => 'Check for newly added or deleted music';
  String get TRACK_ARTISTS_SEPARATOR => 'Artists Separators';
  String get TRACK_GENRES_SEPARATOR => 'Genres Separators';
  String get SEPARATORS_MESSAGE => 'No need to insert spaces, unless you wanna use a letter (like x)';
  String get TRACKS_INFO => 'Tracks Info';
  String get ARTWORK => 'Artwork';
  String get ARTWORKS => 'Artworks';
  String get FILTERED_BY_SIZE_AND_DURATION => 'Tracks Filtered by size and duration';
  String get DUPLICATED_TRACKS => 'Duplicated Tracks';
  String get MIN_FILE_SIZE => 'Minimum File Size';
  String get MIN_FILE_SIZE_SUBTITLE => 'Only index tracks with size more than this';
  String get MIN_FILE_DURATION => 'Minimum Track Duration';
  String get MIN_FILE_DURATION_SUBTITLE => 'Only index tracks with duration more than this';
  String get ADD_FOLDER => 'Add Folder';
  String get LIST_OF_FOLDERS => 'List of Folders';
  String get MINIMUM_ONE_FOLDER => 'Couldn\'t remove folder';
  String get MINIMUM_ONE_FOLDER_SUBTITLE => 'There should be at least 1 folder, add more folders if you want to remove this one';
  String get EXCLUDED_FODLERS => 'Excluded Folders';
  String get NO_EXCLUDED_FOLDERS => 'You Don\'t have any excluded folders';
  String get NO_FOLDER_CHOSEN => 'You haven\'t chosen any folder';
  String get PREVENT_DUPLICATED_TRACKS => 'Prevent Duplicated tracks';
  String get PREVENT_DUPLICATED_TRACKS_SUBTITLE => 'Uses filename to uniqely identify tracks';
  String get RESPECT_NO_MEDIA => 'Respect .nomedia';
  String get RESPECT_NO_MEDIA_SUBTITLE => 'Don\'t include folders that has .nomedia';
  String get EDIT_TAGS => 'Edit Tags';

  /// Customization Settings
  String get CUSTOMIZATIONS => 'Customizations';
  String get CUSTOMIZATIONS_SUBTITLE => 'Customize how your player looks, make it yours';
  String get ENABLE_BLUR_EFFECT => 'Enable Blur Effect';
  String get ENABLE_GLOW_EFFECT => 'Enable Glow Effect';
  String get PERFORMANCE_NOTE => 'Might affect performance';
  String get BORDER_RADIUS_MULTIPLIER => 'Border Radius Multiplier';
  String get FONT_SCALE => 'Font Scale';
  String get FORCE_SQUARED_THUMBNAIL_NOTE => 'Thumbnail Size & Tile Height are NOT equal, Square-ish look will not be as expected, Do you wish to make them equal?';

  /// Extras Settings
  String get EXTRAS => 'Extras';
  String get EXTRAS_SUBTITLE => 'Extra Settings to fine your experience';
  String get AT_LEAST_ONE_FILTER => 'Couldn\'t remove filter';
  String get AT_LEAST_ONE_FILTER_SUBTITLE => 'At least one filter should remain';
  String get LIBRARY_TABS => 'Library Tabs';
  String get AT_LEAST_THREE_TABS => 'Couldn\'t remove Tab';
  String get AT_LEAST_THREE_TABS_SUBTITLE => 'At least 3 tabs should remain';
  String get LIBRARY_TABS_REORDER => 'You can reorder the activated tabs.';
  String get DEFAULT_LIBRARY_TAB => 'Default Library Tab';
  String get USE_COLLAPSED_SETTING_TILES => 'Use Collapsed Setting Tiles';
  String get ENABLE_FOLDERS_HIERARCHY => 'Enable Folders Hierarchy';
  String get ENABLE_SCROLLING_NAVIGATION => 'Enable Scrolling Navigation';
  String get ENABLE_SCROLLING_NAVIGATION_SUBTITLE => 'Swipe horizontally to navigate between pages';

  /// Backup & Restore

  String get BACKUP_AND_RESTORE => 'Backup & Restore';
  String get BACKUP_AND_RESTORE_SUBTITLE => 'Backup your database and settings';
  String get DEFAULT_BACKUP_LOCATION => 'Default Backup Location';
  String get CREATE_BACKUP => 'Create Backup';
  String get RESTORE_BACKUP => 'Restore Backup';
  String get AUTOMATIC_BACKUP => 'Automatic';
  String get AUTOMATIC_BACKUP_SUBTITLE => 'Automatically applies the most recent backup file found inside backup location';
  String get MANUAL_BACKUP => 'Manual';
  String get MANUAL_BACKUP_SUBTITLE => 'pick up a specific file';
  String get CREATED_BACKUP_SUCCESSFULLY => 'Created Backup';
  String get CREATED_BACKUP_SUCCESSFULLY_SUB => 'Backup file has been created successfully';
  String get RESTORED_BACKUP_SUCCESSFULLY => 'Restored Backup';
  String get RESTORED_BACKUP_SUCCESSFULLY_SUB => 'Backup file has been restored successfully';

  /// Search
  String get FILTER_TRACKS_BY => 'Filter Tracks in Search Lists By';
  String get FILTER_TRACKS => 'Filter Tracks';
  String get FILTER_ALBUMS => 'Filter Albums';
  String get FILTER_ARTISTS => 'Filter Artists';
  String get FILTER_GENRES => 'Filter Genres';
  String get FILTER_PLAYLISTS => 'Filter Playlists';

  /// Player
  String get PLAY => 'Play';
  String get PLAY_ALL => 'Play All';
  String get PLAY_NEXT => 'Play Next';
  String get PLAY_LAST => 'Play Last';
  String get SHUFFLE => 'Shuffle';

  /// 1. Track Tile Customization
  String get TRACK_TILE_CUSTOMIZATION => 'Track Tile Customization';
  String get FORCE_SQUARED_TRACK_THUMBNAIL => 'Force Squared Track Thumbnail';
  String get TRACK_THUMBNAIL_SIZE_IN_LIST => 'Size of Track Thumbnail';
  String get HEIGHT_OF_TRACK_TILE => 'Height of Track Tile';
  String get DISPLAY_THIRD_ROW_IN_TRACK_TILE => 'Display Third Row';
  String get DISPLAY_THIRD_ITEM_IN_ROW_IN_TRACK_TILE => 'Display Third Item in each Row';
  String get DISPLAY_FAVOURITE_ICON_IN_TRACK_TILE => 'Display Favourite Button';
  String get TRACK_TILE_ITEMS_SEPARATOR => 'Items Separator';

  /// 2. Album Tile Customization
  String get ALBUM_TILE_CUSTOMIZATION => 'Album Tile Customization';
  String get DISPLAY_TRACK_NUMBER_IN_ALBUM_PAGE => 'Display Track number in Album Page';
  String get DISPLAY_TRACK_NUMBER_IN_ALBUM_PAGE_SUBTITLE => 'Display a small box containing the track number in the album page';
  String get DISPLAY_ALBUM_CARD_TOP_RIGHT_DATE => 'Album Card top right date';
  String get DISPLAY_ALBUM_CARD_TOP_RIGHT_DATE_SUBTITLE => 'Display Album date at Album Card top right';
  String get FORCE_SQUARED_ALBUM_THUMBNAIL => 'Force Squared Album Thumbnail';
  String get STAGGERED_ALBUM_GRID_VIEW => 'Staggered Album Gridview';
  String get ALBUM_THUMBNAIL_SIZE_IN_LIST => 'Size of Album Thumbnail';
  String get HEIGHT_OF_ALBUM_TILE => 'Height of Album Tile';

  /// 3. Miniplayer Customization
  String get MINIPLAYER_CUSTOMIZATION => 'Miniplayer Customization';
  String get ANIMATING_THUMBNAIL_INTENSITY => 'Thumbnail Animation Intensity';
  String get ENABLE_PARTY_MODE => 'Enable Party Mode';
  String get ENABLE_PARTY_MODE_SUBTITLE => 'Apply fancy edge breathing effect';
  String get EDGE_COLORS_SWITCHING => 'Edge Colors Switching';
  String get ENABLE_MINIPLAYER_PARTICLES => 'Enable moving particles';
  String get ANIMATING_THUMBNAIL_INVERSED => 'Inverse Animations';
  String get ANIMATING_THUMBNAIL_INVERSED_SUBTITLE => 'High peaks will cause the thumbnail to get smaller';
  String get WAVEFORM_BARS_COUNT => 'Waveform Bars Count';

  /// Extras
  String get DATE_TIME_FORMAT => 'Date Time Format';
  String get HOUR_FORMAT_12 => '12 Hour Format';

  /// Advanced
  String get GENERATE_ALL_WAVEFORM_DATA => 'Generate All Waveform data';
  String get EXTRACT_ALL_COLOR_PALETTES => 'Extract All Color Palettes';
  String get EXTRACT_ALL_COLOR_PALETTES_SUBTITLE => 'Extract Remaining _REMAINING_COLOR_PALETTES_?';
  String get FORCE_STOP_COLOR_PALETTE_GENERATION => 'Force stop extracting color palettes? you can still continue it later';
  String get GENERATE_ALL_WAVEFORM_DATA_SUBTITLE =>
      'You currently have _WAVEFORM_CURRENT_LENGTH_ waveforms generated out of _WAVEFORM_TOTAL_LENGTH_.\n\nThis is a heavy process and generating for all tracks at once will take quite a while, proceed?';
  String get FORCE_STOP_WAVEFORM_GENERATION => 'Force stop generating waveforms? you can still continue it later';
  String get RESET_SAF_PERMISSION => 'Reset SAF Permission';
  String get RESET_SAF_PERMISSION_SUBTITLE => 'Use it only in case tag editing is not working';
  String get RESET_SAF_PERMISSION_RESET_SUCCESS => 'SAF Permission has been reset successfully';
  String get CLEAR_VIDEO_CACHE => 'Clear Video Cache';
  String get CLEAR_VIDEO_CACHE_SUBTITLE => 'Delete _CURRENT_VIDEOS_COUNT_ Videos Representing _TOTAL_SIZE_?';
  String get CLEAR_VIDEO_CACHE_NOTE => 'You can choose what to delete.';

  /// Defaults
  String get ADD => 'Add';
  String get CREATE => 'Create';
  String get REMOVE => 'Remove';
  String get CLEAR => 'Clear';
  String get CHOOSE => 'Choose';
  String get SAVE => 'Save';
  String get DONE => 'Done';
  String get SHARE => 'Share';
  String get SEARCH => 'Search';
  String get CONFIRM => 'Confirm';
  String get CANCEL => 'Cancel';
  String get OF => 'of';
  String get OR => 'or';
  // String get IN => 'in';
  String get AUTO => 'Auto';
  String get DEFAULT => 'Default';
  String get NAME => 'Name';
  String get NOTE => 'Note';
  String get STOP => 'Stop';
  String get RANDOM => 'Random';
  String get MORE => 'More';
  String get GENERATE => 'Generate';
  String get AUTO_GENERATED => 'Auto Generated';
  String get EXTRACT => 'Extract';
  String get GRANT_ACCESS => 'Grant Access';
  String get RESTORE_DEFAULTS => 'Restore Defaults';
  String get VALUE => 'Value';
  String get RESET_TO_DEFAULT => 'Set to';
  String get RESTART => 'Restart';
  String get RESTART_TO_APPLY_CHANGES => 'Restart to apply changes';
  String get WARNING => 'Warning';
  String get EMPTY_VALUE => 'Empty Value';
  String get ENTER_SYMBOL => 'Please Enter a Symbol';
  String get VALUE_BETWEEN_50_200 => 'Value should be between 50% and 200%';
  String get ITEM => 'Item';
  String get EXIT => 'Exit';

  ///
  String get CREATE_NEW_PLAYLIST => 'Create new Playlist';
  String get ADD_TO_PLAYLIST => 'Add to Playlist';
  String get SET_MOODS => 'Set moods';
  String get SET_MOODS_SUBTITLE => 'Use commas (,) to separate between them';

  /// Other Settings
  String get ENABLE_FADE_EFFECT_ON_PLAY_PAUSE => 'Enable Fade Effect on Play/Pause';

  /// Advanced Settings
  String get ADVANCED_SETTINGS => 'Advanced';
  String get ADVANCED_SETTINGS_SUBTITLE => 'Advanced Settings, don\'t touch';
  String get CLEAR_IMAGE_CACHE => 'Clear Image cache';
  String get CLEAR_IMAGE_CACHE_WARNING => 'Clearing Image cache will result in a library without images.\n\nUse it only in case you want to rebuild image cache.';

  String get CLEAR_WAVEFORM_DATA => 'Clear Waveform data';
  String get CLEAR_WAVEFORM_DATA_WARNING => 'Do you really want to wait all that time again?';

  /// Library
  String get DATABASE => 'Database';
  String get TRACKS => 'Tracks';
  String get ALBUMS => 'Albums';
  String get ARTISTS => 'Artists';
  String get ALBUM_ARTISTS => 'Album Artists';
  String get GENRES => 'Genres';
  String get PLAYLISTS => 'Playlists';
  String get FOLDERS => 'Folders';
  String get QUEUE => 'Queue';
  String get QUEUES => 'Queues';
  String get SETTINGS => 'Settings';
  String get WAVEFORMS => 'Waveforms';

  /// Sort
  // String get SORT_TRACKS_BY => 'Sort Tracks By';
  // String get SORT_ALBUMS_BY => 'Sort Albums By';
  // String get SORT_ARTISTS_BY => 'Sort Artists By';
  // String get SORT_GENRES_BY => 'Sort Genres By';
  // String get SORT_PLAYLISTS_BY => 'Sort Playlists By';
  String get REVERSE_ORDER => 'Reverse Order';

  /// Track/Group Info
  String get FILE => 'File';
  String get FILES => 'Files';
  String get FOLDER => 'Folder';
  String get PLAYLIST => 'Playlist';
  String get TRACK => 'Track';
  String get ALBUM => 'Album';
  String get ARTIST => 'Artist';
  String get ALBUM_ARTIST => 'Album Artist';
  String get GENRE => 'Genre';
  String get TITLE => 'Title';
  String get YEAR => 'Year';
  String get COMPOSER => 'Composer';
  String get DURATION => 'Duration';
  String get DATE_MODIFIED => 'Date Modified';
  String get BITRATE => 'Bitrate';
  String get DISC_NUMBER => 'Disc Number';
  String get FILE_NAME => 'File Name';
  String get SAMPLE_RATE => 'Sample Rate';
  String get NUMBER_OF_TRACKS => 'Number of Tracks';
  String get SIZE => 'Size';
  String get NONE => 'None';
  String get CHANNELS => 'Channels';
  String get COMMENT => 'Comment';
  String get DATE_ADDED => 'Date Added';
  String get CLOCK => 'Clock';
  String get DATE => 'Date';
  String get FILE_NAME_WO_EXT => 'Filename without extension';
  String get EXTENSION => 'Extension';
  String get FOLDER_NAME => 'Folder Name';
  String get FORMAT => 'Format';
  String get PATH => 'File Full Path';
  String get TRACK_NUMBER => 'Track Number';
}
