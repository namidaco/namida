// ignore_for_file: non_constant_identifier_names

import 'package:get/get.dart';

class Language {
  static Language inst = Language();

  /// Main
  String get EXIT_APP => 'Exit';
  String get EXIT_APP_SUBTITLE => 'Do you really want to exit?';
  String get STORAGE_PERMISSION => 'Storage Permission';
  String get STORAGE_PERMISSION_SUBTITLE => 'Storage Permission is required to read your music files';

  /// Stats
  String get STATS => 'Statistics';
  String get STATS_SUBTITLE => 'Here are some info about your library';
  String get TOTAL_TRACKS_DURATION => 'Total Tracks';

  /// [Setting Values]
  ///
  /// Theme
  String get THEME_MODE => 'Theme Mode';
  String get THEME_MODE_SYSTEM => 'System';
  String get THEME_MODE_LIGHT => 'Light';
  String get THEME_MODE_DARK => 'Dark';
  String get THEME_SETTINGS => 'Theme';
  String get THEME_SETTINGS_SUBTITLE => 'The overall vibe of your player';

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
  String get SEPARATORS_MESSAGE => 'Spaces are taken care of automatically, No need to insert them.';
  String get TRACKS_INFO => 'Tracks Info';
  String get ARTWORKS => 'Artworks';
  String get FILTERED_BY_SIZE_AND_DURATION => 'Tracks Filtered by size and duration';
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
  String get PREVENT_DUPLICATED_TRACKS => 'Prevent Duplicated tracks';
  String get PREVENT_DUPLICATED_TRACKS_SUBTITLE => 'Uses filename to uniqely identify tracks.';

  /// Customization Settings
  String get CUSTOMIZATIONS => 'Customizations';
  String get CUSTOMIZATIONS_SUBTITLE => 'Customize how your player looks, make it yours';
  String get ENABLE_BLUR_EFFECT => 'Enable Blur Effect';
  String get ENABLE_GLOW_EFFECT => 'Enable Glow Effect';
  String get BORDER_RADIUS_MULTIPLIER => 'Border Radius Multiplier';
  String get FONT_SCALE => 'Font Scale';

  /// Extras Settings
  String get EXTRAS => 'Extras';
  String get EXTRAS_SUBTITLE => 'Extra Settings to fine your experience';
  String get AT_LEAST_ONE_FILTER => 'Couldn\'t remove filter';
  String get AT_LEAST_ONE_FILTER_SUBTITLE => 'At least one filter should remain';

  /// Search
  String get FILTER_TRACKS_BY => 'Filter Tracks in Search List By';
  String get FILTER_TRACKS => 'Filter Tracks';
  String get FILTER_ALBUMS => 'Filter Albums';
  String get FILTER_ARTISTS => 'Filter Artists';
  String get FILTER_GENRES => 'Filter Genres';

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

  /// Extras
  String get DATE_TIME_FORMAT => 'Date Time Format';
  String get HOUR_FORMAT_12 => '12 Hour Format';

  /// Defaults
  String get ADD => 'Add';
  String get REMOVE => 'Remove';
  String get CLEAR => 'Clear';
  String get SAVE => 'Save';
  String get CONFIRM => 'Confirm';
  String get CANCEL => 'Cancel';
  String get OF => 'of';
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

  /// Other Settings
  String get ENABLE_FADE_EFFECT_ON_PLAY_PAUSE => 'Enable Fade Effect on Play/Pause';

  /// Advanced Settings
  String get ADVANCED_SETTINGS => 'Advanced Settings';
  String get ADVANCED_SETTINGS_SUBTITLE => 'Advanced Settings, don\'t touch';
  String get CLEAR_IMAGE_CACHE => 'Clear Image cache';
  String get CLEAR_IMAGE_CACHE_WARNING => 'Clearing Image cache will result in a library without images.\n\nUse it only in case you want to rebuild image cache.';
  String get CLEAR_WAVEFORM_DATA => 'Clear Waveform data';
  String get CLEAR_WAVEFORM_DATA_WARNING => 'Do you really want to wait all that time again?';

  /// Library
  String get TRACKS => 'Tracks';
  String get ALBUMS => 'Albums';
  String get ARTISTS => 'Artists';
  String get ALBUM_ARTISTS => 'Album Artists';
  String get GENRES => 'Genres';
  String get SETTINGS => 'Settings';

  /// Sort
  String get SORT_TRACKS_BY => 'Sort Tracks By';
  String get SORT_ALBUMS_BY => 'Sort Albums By';
  String get SORT_ARTISTS_BY => 'Sort Artists By';
  String get SORT_GENRES_BY => 'Sort Genres By';
  String get REVERSE_ORDER => 'Reverse Order';

  /// Track/Group Info
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
