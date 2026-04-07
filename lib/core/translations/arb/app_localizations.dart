import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_af.dart';
import 'app_localizations_ar.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_bs.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_eo.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_fi.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ro.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_sl.dart';
import 'app_localizations_sr.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_uk.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'arb/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('af'),
    Locale('ar'),
    Locale('bn'),
    Locale('bs'),
    Locale('de'),
    Locale('en'),
    Locale('eo'),
    Locale('es'),
    Locale('es', 'CO'),
    Locale('fa'),
    Locale('fi'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('nl'),
    Locale('pl'),
    Locale('pt'),
    Locale('ro'),
    Locale('ru'),
    Locale('sl'),
    Locale('sr'),
    Locale('ta'),
    Locale('tr'),
    Locale('uk'),
    Locale('vi'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addAccount;

  /// No description provided for @addAll.
  ///
  /// In en, this message translates to:
  /// **'Add all'**
  String get addAll;

  /// No description provided for @addAllAndRemoveOldOnes.
  ///
  /// In en, this message translates to:
  /// **'Add all and remove old ones'**
  String get addAllAndRemoveOldOnes;

  /// No description provided for @addAsANewPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add as a new Playlist'**
  String get addAsANewPlaylist;

  /// No description provided for @addAudioToLocalLibrary.
  ///
  /// In en, this message translates to:
  /// **'Add audio to local library'**
  String get addAudioToLocalLibrary;

  /// No description provided for @addFolder.
  ///
  /// In en, this message translates to:
  /// **'Add Folder'**
  String get addFolder;

  /// No description provided for @addLanguage.
  ///
  /// In en, this message translates to:
  /// **'Add Language'**
  String get addLanguage;

  /// No description provided for @addLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help translating Namida to your own language'**
  String get addLanguageSubtitle;

  /// No description provided for @addLrcFile.
  ///
  /// In en, this message translates to:
  /// **'Add LRC file'**
  String get addLrcFile;

  /// No description provided for @addMoreFromThisAlbum.
  ///
  /// In en, this message translates to:
  /// **'Add more from this Album to queue'**
  String get addMoreFromThisAlbum;

  /// No description provided for @addMoreFromThisArtist.
  ///
  /// In en, this message translates to:
  /// **'Add more from this Artist to queue'**
  String get addMoreFromThisArtist;

  /// No description provided for @addMoreFromThisFolder.
  ///
  /// In en, this message translates to:
  /// **'Add more from this Folder to queue'**
  String get addMoreFromThisFolder;

  /// No description provided for @addMoreFromToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add more from {media} to queue'**
  String addMoreFromToQueue({required String media});

  /// No description provided for @addOnlyMissing.
  ///
  /// In en, this message translates to:
  /// **'Add only missing'**
  String get addOnlyMissing;

  /// No description provided for @addToFavourites.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get addToFavourites;

  /// No description provided for @addToPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Add to Playlist'**
  String get addToPlaylist;

  /// No description provided for @addTracksAtTheBeginning.
  ///
  /// In en, this message translates to:
  /// **'Add tracks at the beginning'**
  String get addTracksAtTheBeginning;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'added'**
  String get added;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @advancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedSettings;

  /// No description provided for @advancedSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings, don\'t touch'**
  String get advancedSettingsSubtitle;

  /// No description provided for @alarm.
  ///
  /// In en, this message translates to:
  /// **'Alarm'**
  String get alarm;

  /// No description provided for @album.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get album;

  /// No description provided for @albumArtist.
  ///
  /// In en, this message translates to:
  /// **'Album Artist'**
  String get albumArtist;

  /// No description provided for @albumArtists.
  ///
  /// In en, this message translates to:
  /// **'Album Artists'**
  String get albumArtists;

  /// No description provided for @albumIdentifiers.
  ///
  /// In en, this message translates to:
  /// **'Album Identifiers'**
  String get albumIdentifiers;

  /// No description provided for @albumThumbnailSizeInList.
  ///
  /// In en, this message translates to:
  /// **'Size of Album Thumbnail'**
  String get albumThumbnailSizeInList;

  /// No description provided for @albumTileCustomization.
  ///
  /// In en, this message translates to:
  /// **'Album Tile Customization'**
  String get albumTileCustomization;

  /// No description provided for @albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albums;

  /// No description provided for @albumsCount.
  ///
  /// In en, this message translates to:
  /// **'Albums Count'**
  String get albumsCount;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTime;

  /// No description provided for @alreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Already Exists'**
  String get alreadyExists;

  /// No description provided for @always.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get always;

  /// No description provided for @alwaysAsk.
  ///
  /// In en, this message translates to:
  /// **'Always ask'**
  String get alwaysAsk;

  /// No description provided for @alwaysDim.
  ///
  /// In en, this message translates to:
  /// **'Always Dim'**
  String get alwaysDim;

  /// No description provided for @alwaysExpandedSearchbar.
  ///
  /// In en, this message translates to:
  /// **'Always Expanded Searchbar'**
  String get alwaysExpandedSearchbar;

  /// No description provided for @alwaysRestore.
  ///
  /// In en, this message translates to:
  /// **'Always restore'**
  String get alwaysRestore;

  /// No description provided for @animatingThumbnailIntensity.
  ///
  /// In en, this message translates to:
  /// **'Thumbnail Animation Intensity'**
  String get animatingThumbnailIntensity;

  /// No description provided for @animatingThumbnailInversed.
  ///
  /// In en, this message translates to:
  /// **'Inverse Animations'**
  String get animatingThumbnailInversed;

  /// No description provided for @animatingThumbnailInversedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'High peaks will cause the thumbnail to get smaller'**
  String get animatingThumbnailInversedSubtitle;

  /// No description provided for @anotherProcessIsRunning.
  ///
  /// In en, this message translates to:
  /// **'Another process is already running.'**
  String get anotherProcessIsRunning;

  /// No description provided for @appIcon.
  ///
  /// In en, this message translates to:
  /// **'App Icon'**
  String get appIcon;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersion;

  /// No description provided for @artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get artist;

  /// No description provided for @artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artists;

  /// No description provided for @artwork.
  ///
  /// In en, this message translates to:
  /// **'Artwork'**
  String get artwork;

  /// No description provided for @artworkGestures.
  ///
  /// In en, this message translates to:
  /// **'Artwork Gestures'**
  String get artworkGestures;

  /// No description provided for @artworks.
  ///
  /// In en, this message translates to:
  /// **'Artworks'**
  String get artworks;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @audioCache.
  ///
  /// In en, this message translates to:
  /// **'Audio Cache'**
  String get audioCache;

  /// No description provided for @audioOnly.
  ///
  /// In en, this message translates to:
  /// **'Audio Only'**
  String get audioOnly;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @autoBackupInterval.
  ///
  /// In en, this message translates to:
  /// **'Auto backup interval'**
  String get autoBackupInterval;

  /// No description provided for @autoColoring.
  ///
  /// In en, this message translates to:
  /// **'Auto Coloring'**
  String get autoColoring;

  /// No description provided for @autoColoringSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically pick player colors from current artwork'**
  String get autoColoringSubtitle;

  /// No description provided for @autoExtractTagsFromFilename.
  ///
  /// In en, this message translates to:
  /// **'Auto extract from filename'**
  String get autoExtractTagsFromFilename;

  /// No description provided for @autoExtractTitleAndArtistFromVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto extract Title & Artist from video title'**
  String get autoExtractTitleAndArtistFromVideoTitle;

  /// No description provided for @autoGenerated.
  ///
  /// In en, this message translates to:
  /// **'Auto Generated'**
  String get autoGenerated;

  /// No description provided for @autoSkip.
  ///
  /// In en, this message translates to:
  /// **'Auto Skip'**
  String get autoSkip;

  /// No description provided for @autoSkipOnce.
  ///
  /// In en, this message translates to:
  /// **'Auto Skip Once'**
  String get autoSkipOnce;

  /// No description provided for @autoStartRadio.
  ///
  /// In en, this message translates to:
  /// **'Auto start radio'**
  String get autoStartRadio;

  /// No description provided for @autoStartRadioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically adds a mix playlist when playing a single track'**
  String get autoStartRadioSubtitle;

  /// No description provided for @automaticBackup.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get automaticBackup;

  /// No description provided for @automaticBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically applies the most recent backup file found inside backup location'**
  String get automaticBackupSubtitle;

  /// No description provided for @backupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupAndRestore;

  /// No description provided for @backupAndRestoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backup your database and settings'**
  String get backupAndRestoreSubtitle;

  /// No description provided for @balanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get balanced;

  /// No description provided for @beta.
  ///
  /// In en, this message translates to:
  /// **'Beta'**
  String get beta;

  /// No description provided for @betweenDates.
  ///
  /// In en, this message translates to:
  /// **'Between Dates'**
  String get betweenDates;

  /// No description provided for @bitrate.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get bitrate;

  /// No description provided for @blacklist.
  ///
  /// In en, this message translates to:
  /// **'Blacklist'**
  String get blacklist;

  /// No description provided for @borderRadiusMultiplier.
  ///
  /// In en, this message translates to:
  /// **'Border Radius Multiplier'**
  String get borderRadiusMultiplier;

  /// No description provided for @cache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get cache;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @canceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get canceled;

  /// No description provided for @changed.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get changed;

  /// No description provided for @changelog.
  ///
  /// In en, this message translates to:
  /// **'Changelog'**
  String get changelog;

  /// No description provided for @changelogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See what\'s newly added/fixed inside Namida'**
  String get changelogSubtitle;

  /// No description provided for @channel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get channel;

  /// No description provided for @channels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channels;

  /// No description provided for @check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// No description provided for @checkForMore.
  ///
  /// In en, this message translates to:
  /// **'Check for more'**
  String get checkForMore;

  /// No description provided for @checkList.
  ///
  /// In en, this message translates to:
  /// **'Check List'**
  String get checkList;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided for @chooseWhatToClear.
  ///
  /// In en, this message translates to:
  /// **'Choose what to clear'**
  String get chooseWhatToClear;

  /// No description provided for @claim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get claim;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @clearAudioCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Audio Cache'**
  String get clearAudioCache;

  /// No description provided for @clearImageCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Image cache'**
  String get clearImageCache;

  /// No description provided for @clearImageCacheWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: will result in a library without images, Use only to rebuild image cache.'**
  String get clearImageCacheWarning;

  /// No description provided for @clearTrackItem.
  ///
  /// In en, this message translates to:
  /// **'Clear Track\'s'**
  String get clearTrackItem;

  /// No description provided for @clearTrackItemMultiple.
  ///
  /// In en, this message translates to:
  /// **'{number, plural, one{Clear Track\'s} other{Clear {number} Tracks\'}}'**
  String clearTrackItemMultiple({required int number});

  /// No description provided for @clearVideoCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Video Cache'**
  String get clearVideoCache;

  /// No description provided for @clearVideoCacheNote.
  ///
  /// In en, this message translates to:
  /// **'You can choose what to delete.'**
  String get clearVideoCacheNote;

  /// No description provided for @clock.
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get clock;

  /// No description provided for @colorPalette.
  ///
  /// In en, this message translates to:
  /// **'Color Palette'**
  String get colorPalette;

  /// No description provided for @colorPaletteNote1.
  ///
  /// In en, this message translates to:
  /// **'Long press a color to remove it'**
  String get colorPaletteNote1;

  /// No description provided for @colorPaletteNote2.
  ///
  /// In en, this message translates to:
  /// **'Tap on a mix to use as a default color'**
  String get colorPaletteNote2;

  /// No description provided for @colorPalettes.
  ///
  /// In en, this message translates to:
  /// **'Color Palettes'**
  String get colorPalettes;

  /// No description provided for @comment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get comment;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @composer.
  ///
  /// In en, this message translates to:
  /// **'Composer'**
  String get composer;

  /// No description provided for @compress.
  ///
  /// In en, this message translates to:
  /// **'Compress'**
  String get compress;

  /// No description provided for @compressImages.
  ///
  /// In en, this message translates to:
  /// **'Compress Images'**
  String get compressImages;

  /// No description provided for @compressionPercentage.
  ///
  /// In en, this message translates to:
  /// **'Compression percentage'**
  String get compressionPercentage;

  /// No description provided for @configure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get configure;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @confirmRefresh.
  ///
  /// In en, this message translates to:
  /// **'Confirm Refresh?'**
  String get confirmRefresh;

  /// No description provided for @convertToM3UPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Convert to M3U Playlist'**
  String get convertToM3UPlaylist;

  /// No description provided for @convertToNormalPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Convert to Normal Playlist'**
  String get convertToNormalPlaylist;

  /// No description provided for @copiedArtwork.
  ///
  /// In en, this message translates to:
  /// **'Copied Artwork'**
  String get copiedArtwork;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to Clipboard'**
  String get copiedToClipboard;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @corruptedFile.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t parse file, it might be corrupted'**
  String get corruptedFile;

  /// No description provided for @couldntOpen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open :('**
  String get couldntOpen;

  /// No description provided for @couldntOpenYtLink.
  ///
  /// In en, this message translates to:
  /// **'No Youtube Link Available for this track'**
  String get couldntOpenYtLink;

  /// No description provided for @couldntPlayFile.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play file'**
  String get couldntPlayFile;

  /// No description provided for @couldntRenamePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t rename playlist'**
  String get couldntRenamePlaylist;

  /// No description provided for @couldntSaveImage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save image'**
  String get couldntSaveImage;

  /// No description provided for @countAlbumArtists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} Album Artist} other{{count} Album Artists}}'**
  String countAlbumArtists({required int count});

  /// No description provided for @countAlbums.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} Album} other{{count} Albums}}'**
  String countAlbums({required int count});

  /// No description provided for @countArtists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} Artist} other{{count} Artists}}'**
  String countArtists({required int count});

  /// No description provided for @countComposers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} Composer} other{{count} Composers}}'**
  String countComposers({required int count});

  /// No description provided for @countDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} Day} other{{count} Days}}'**
  String countDays({required int count});

  /// No description provided for @countFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} File} other{{count} Files}}'**
  String countFiles({required int count});

  /// No description provided for @countFolders.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} Folder} other{{count} Folders}}'**
  String countFolders({required int count});

  /// No description provided for @countGenres.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} Genre} other{{count} Genres}}'**
  String countGenres({required int count});

  /// No description provided for @countMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} Month} other{{count} Months}}'**
  String countMonths({required int count});

  /// No description provided for @countPlaylists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} Playlist} other{{count} Playlists}}'**
  String countPlaylists({required int count});

  /// No description provided for @countSubscribers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} Subscriber} other{{count} Subscribers}}'**
  String countSubscribers({required int count});

  /// No description provided for @countSubscribersShort.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} Subscriber} other{{count} Subscribers}}'**
  String countSubscribersShort({required int count});

  /// No description provided for @countTracks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} Track} other{{count} Tracks}}'**
  String countTracks({required int count});

  /// No description provided for @countVideos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} Video} other{{count} Videos}}'**
  String countVideos({required int count});

  /// No description provided for @countViews.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} View} other{{count} Views}}'**
  String countViews({required int count});

  /// No description provided for @countViewsShort.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} View} other{{count} Views}}'**
  String countViewsShort({required int count});

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @coupon.
  ///
  /// In en, this message translates to:
  /// **'Coupon'**
  String get coupon;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createBackup.
  ///
  /// In en, this message translates to:
  /// **'Create Backup'**
  String get createBackup;

  /// No description provided for @createNewPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create new Playlist'**
  String get createNewPlaylist;

  /// No description provided for @createdBackupSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Created Backup'**
  String get createdBackupSuccessfully;

  /// No description provided for @createdBackupSuccessfullySub.
  ///
  /// In en, this message translates to:
  /// **'Backup file has been created successfully'**
  String get createdBackupSuccessfullySub;

  /// No description provided for @crossPlatformSync.
  ///
  /// In en, this message translates to:
  /// **'Cross-Platform Sync'**
  String get crossPlatformSync;

  /// No description provided for @crossfadeDuration.
  ///
  /// In en, this message translates to:
  /// **'Crossfade duration'**
  String get crossfadeDuration;

  /// No description provided for @crossfadeTriggerSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, one{Trigger Crossfade automatically in the last {seconds} second} other{Trigger Crossfade automatically in the last {seconds} seconds}}'**
  String crossfadeTriggerSeconds({required int seconds});

  /// No description provided for @crossfadeTriggerSecondsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Do not trigger crossfade automatically'**
  String get crossfadeTriggerSecondsDisabled;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @customizations.
  ///
  /// In en, this message translates to:
  /// **'Customizations'**
  String get customizations;

  /// No description provided for @customizationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize how your player looks, make it yours'**
  String get customizationsSubtitle;

  /// No description provided for @dataIsProvidedByName.
  ///
  /// In en, this message translates to:
  /// **'Data is provided by: {name}'**
  String dataIsProvidedByName({required String name});

  /// No description provided for @dataSaver.
  ///
  /// In en, this message translates to:
  /// **'Data Saver'**
  String get dataSaver;

  /// No description provided for @dataSaverMode.
  ///
  /// In en, this message translates to:
  /// **'Data Saver Mode'**
  String get dataSaverMode;

  /// No description provided for @database.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get database;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @dateAdded.
  ///
  /// In en, this message translates to:
  /// **'Date Added'**
  String get dateAdded;

  /// No description provided for @dateCreated.
  ///
  /// In en, this message translates to:
  /// **'Date Created'**
  String get dateCreated;

  /// No description provided for @dateModified.
  ///
  /// In en, this message translates to:
  /// **'Date Modified'**
  String get dateModified;

  /// No description provided for @dateTimeFormat.
  ///
  /// In en, this message translates to:
  /// **'Date Time Format'**
  String get dateTimeFormat;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get days;

  /// No description provided for @defaultBackupLocation.
  ///
  /// In en, this message translates to:
  /// **'Default Backup Location'**
  String get defaultBackupLocation;

  /// No description provided for @defaultColor.
  ///
  /// In en, this message translates to:
  /// **'Default Color'**
  String get defaultColor;

  /// No description provided for @defaultColorSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set a color to be used by the player'**
  String get defaultColorSubtitle;

  /// No description provided for @defaultDownloadLocation.
  ///
  /// In en, this message translates to:
  /// **'Default Download Location'**
  String get defaultDownloadLocation;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @defaultLibraryTab.
  ///
  /// In en, this message translates to:
  /// **'Default Library Tab'**
  String get defaultLibraryTab;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteFileCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Delete {count} file representing {totalSizeText}?} other{Delete {count} files representing {totalSizeText}?}}'**
  String deleteFileCacheSubtitle({required int count, required String totalSizeText});

  /// No description provided for @deleteNTracksFromStorage.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete {numberText} from your storage'**
  String deleteNTracksFromStorage({required String numberText});

  /// No description provided for @deletePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Delete Playlist'**
  String get deletePlaylist;

  /// No description provided for @deleteTempFiles.
  ///
  /// In en, this message translates to:
  /// **'Delete temp files'**
  String get deleteTempFiles;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @development.
  ///
  /// In en, this message translates to:
  /// **'Development'**
  String get development;

  /// No description provided for @didYouMean.
  ///
  /// In en, this message translates to:
  /// **'Did you mean'**
  String get didYouMean;

  /// No description provided for @dimIntensity.
  ///
  /// In en, this message translates to:
  /// **'Dim Intensity'**
  String get dimIntensity;

  /// No description provided for @dimMiniplayerAfterSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, one{Dim miniplayer after {seconds} second of inactivity} other{Dim miniplayer after {seconds} seconds of inactivity}}'**
  String dimMiniplayerAfterSeconds({required int seconds});

  /// No description provided for @directoryDoesntExist.
  ///
  /// In en, this message translates to:
  /// **'Directory doesn\'t exist'**
  String get directoryDoesntExist;

  /// No description provided for @disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// No description provided for @disableAll.
  ///
  /// In en, this message translates to:
  /// **'Disable All'**
  String get disableAll;

  /// No description provided for @disableReordering.
  ///
  /// In en, this message translates to:
  /// **'Disable Reordering'**
  String get disableReordering;

  /// No description provided for @disableSearchCleanup.
  ///
  /// In en, this message translates to:
  /// **'Disable Search Cleanup'**
  String get disableSearchCleanup;

  /// No description provided for @discNumber.
  ///
  /// In en, this message translates to:
  /// **'Disc Number'**
  String get discNumber;

  /// No description provided for @discNumberTotal.
  ///
  /// In en, this message translates to:
  /// **'Disc Total'**
  String get discNumberTotal;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @dislike.
  ///
  /// In en, this message translates to:
  /// **'Dislike'**
  String get dislike;

  /// No description provided for @dismissibleMiniplayer.
  ///
  /// In en, this message translates to:
  /// **'Dismissible Miniplayer'**
  String get dismissibleMiniplayer;

  /// No description provided for @displayActualPositionInsteadOfDifferenceWhileSeeking.
  ///
  /// In en, this message translates to:
  /// **'Display actual position instead of difference while seeking'**
  String get displayActualPositionInsteadOfDifferenceWhileSeeking;

  /// No description provided for @displayAlbumCardTopRightDate.
  ///
  /// In en, this message translates to:
  /// **'Album Card top right date'**
  String get displayAlbumCardTopRightDate;

  /// No description provided for @displayAlbumCardTopRightDateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display Album date at Album Card top right'**
  String get displayAlbumCardTopRightDateSubtitle;

  /// No description provided for @displayArtistBeforeTitle.
  ///
  /// In en, this message translates to:
  /// **'Display artist before title'**
  String get displayArtistBeforeTitle;

  /// No description provided for @displayArtworkOnLockscreen.
  ///
  /// In en, this message translates to:
  /// **'Display artwork on lockscreen'**
  String get displayArtworkOnLockscreen;

  /// No description provided for @displayAudioInfoInMiniplayer.
  ///
  /// In en, this message translates to:
  /// **'Display Audio Info'**
  String get displayAudioInfoInMiniplayer;

  /// No description provided for @displayFavButtonInNotification.
  ///
  /// In en, this message translates to:
  /// **'Display Favourite Button in Notification'**
  String get displayFavButtonInNotification;

  /// No description provided for @displayFavButtonInNotificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Thumbnail might get displaced.'**
  String get displayFavButtonInNotificationSubtitle;

  /// No description provided for @displayFavouriteIconInTrackTile.
  ///
  /// In en, this message translates to:
  /// **'Display Favourite Button'**
  String get displayFavouriteIconInTrackTile;

  /// No description provided for @displayRemainingDurationInsteadOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Display remaining duration instead of total'**
  String get displayRemainingDurationInsteadOfTotal;

  /// No description provided for @displayStopButtonInNotification.
  ///
  /// In en, this message translates to:
  /// **'Display Stop Button in Notification'**
  String get displayStopButtonInNotification;

  /// No description provided for @displayThirdItemInRowInTrackTile.
  ///
  /// In en, this message translates to:
  /// **'Display Third Item in each Row'**
  String get displayThirdItemInRowInTrackTile;

  /// No description provided for @displayThirdRowInTrackTile.
  ///
  /// In en, this message translates to:
  /// **'Display Third Row'**
  String get displayThirdRowInTrackTile;

  /// No description provided for @displayTrackNumberInAlbumPage.
  ///
  /// In en, this message translates to:
  /// **'Display Track number in Album Page'**
  String get displayTrackNumberInAlbumPage;

  /// No description provided for @displayTrackNumberInAlbumPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display a small box containing the track number in the album page'**
  String get displayTrackNumberInAlbumPageSubtitle;

  /// No description provided for @doNothing.
  ///
  /// In en, this message translates to:
  /// **'Do nothing'**
  String get doNothing;

  /// No description provided for @donate.
  ///
  /// In en, this message translates to:
  /// **'Donate'**
  String get donate;

  /// No description provided for @donateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If you think it deserves'**
  String get donateSubtitle;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @dontAskAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask again'**
  String get dontAskAgain;

  /// No description provided for @dontDim.
  ///
  /// In en, this message translates to:
  /// **'Don\'t Dim'**
  String get dontDim;

  /// No description provided for @dontRestorePosition.
  ///
  /// In en, this message translates to:
  /// **'Don\'t restore'**
  String get dontRestorePosition;

  /// No description provided for @dontResume.
  ///
  /// In en, this message translates to:
  /// **'Dont resume'**
  String get dontResume;

  /// No description provided for @doubleTapToToggleLyrics.
  ///
  /// In en, this message translates to:
  /// **'Double tap to toggle lyrics'**
  String get doubleTapToToggleLyrics;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloadingWillOverrideIt.
  ///
  /// In en, this message translates to:
  /// **'Downloading will override it'**
  String get downloadingWillOverrideIt;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @downloadsMetadataTags.
  ///
  /// In en, this message translates to:
  /// **'Downloads Metadata tags'**
  String get downloadsMetadataTags;

  /// No description provided for @downloadsMetadataTagsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Extract artist, title & album from video info by default'**
  String get downloadsMetadataTagsSubtitle;

  /// No description provided for @dragToSeek.
  ///
  /// In en, this message translates to:
  /// **'Drag to seek'**
  String get dragToSeek;

  /// No description provided for @duckAudio.
  ///
  /// In en, this message translates to:
  /// **'Duck audio'**
  String get duckAudio;

  /// No description provided for @duplicatedItemsAdding.
  ///
  /// In en, this message translates to:
  /// **'You are trying to add some items that already exist in this playlist'**
  String get duplicatedItemsAdding;

  /// No description provided for @duplicatedTracks.
  ///
  /// In en, this message translates to:
  /// **'Duplicated Tracks'**
  String get duplicatedTracks;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @edgeColorsSwitching.
  ///
  /// In en, this message translates to:
  /// **'Edge Colors Switching'**
  String get edgeColorsSwitching;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editArtwork.
  ///
  /// In en, this message translates to:
  /// **'Edit Artwork'**
  String get editArtwork;

  /// No description provided for @editTags.
  ///
  /// In en, this message translates to:
  /// **'Edit Tags'**
  String get editTags;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emptyNonMeaningfulTagFields.
  ///
  /// In en, this message translates to:
  /// **'you have fields with empty/non-meaningful values, make sure you really want to edit them'**
  String get emptyNonMeaningfulTagFields;

  /// No description provided for @emptyValue.
  ///
  /// In en, this message translates to:
  /// **'Empty Value'**
  String get emptyValue;

  /// No description provided for @enableArtworkCache.
  ///
  /// In en, this message translates to:
  /// **'Enable Artwork Cache'**
  String get enableArtworkCache;

  /// No description provided for @enableArtworkCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Faster loading and improved performance, but uses more storage'**
  String get enableArtworkCacheSubtitle;

  /// No description provided for @enableBlurEffect.
  ///
  /// In en, this message translates to:
  /// **'Enable Blur Effect'**
  String get enableBlurEffect;

  /// No description provided for @enableBottomNavBar.
  ///
  /// In en, this message translates to:
  /// **'Enable Bottom Navigation Bar'**
  String get enableBottomNavBar;

  /// No description provided for @enableBottomNavBarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Items are inside the drawer bothways'**
  String get enableBottomNavBarSubtitle;

  /// No description provided for @enableClipboardMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Enable Clipboard Monitoring'**
  String get enableClipboardMonitoring;

  /// No description provided for @enableClipboardMonitoringSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Allows pasting links and texts inside searchbar on the go'**
  String get enableClipboardMonitoringSubtitle;

  /// No description provided for @enableCrossfadeEffect.
  ///
  /// In en, this message translates to:
  /// **'Enable Crossfade Effect'**
  String get enableCrossfadeEffect;

  /// No description provided for @enableFadeEffectOnPlayPause.
  ///
  /// In en, this message translates to:
  /// **'Enable Fade Effect on Play/Pause'**
  String get enableFadeEffectOnPlayPause;

  /// No description provided for @enableFoldersHierarchy.
  ///
  /// In en, this message translates to:
  /// **'Enable Folders Hierarchy'**
  String get enableFoldersHierarchy;

  /// No description provided for @enableGlowEffect.
  ///
  /// In en, this message translates to:
  /// **'Enable Glow Effect'**
  String get enableGlowEffect;

  /// No description provided for @enableM3uSync.
  ///
  /// In en, this message translates to:
  /// **'Enable M3U Sync'**
  String get enableM3uSync;

  /// No description provided for @enableM3uSyncNote1.
  ///
  /// In en, this message translates to:
  /// **'M3U Sync allows saving playlist changes to the original M3U file'**
  String get enableM3uSyncNote1;

  /// No description provided for @enableM3uSyncNote2.
  ///
  /// In en, this message translates to:
  /// **'If anything went wrong, a backup of this playlist will be found in {playlistsBackupPath}'**
  String enableM3uSyncNote2({required String playlistsBackupPath});

  /// No description provided for @enableM3uSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If Denied, all changes done in this playlist will be lost on restart'**
  String get enableM3uSyncSubtitle;

  /// No description provided for @enableMiniplayerParticles.
  ///
  /// In en, this message translates to:
  /// **'Enable moving particles'**
  String get enableMiniplayerParticles;

  /// No description provided for @enableParallaxEffect.
  ///
  /// In en, this message translates to:
  /// **'Enable Parallax Effect'**
  String get enableParallaxEffect;

  /// No description provided for @enablePartyMode.
  ///
  /// In en, this message translates to:
  /// **'Enable Party Mode'**
  String get enablePartyMode;

  /// No description provided for @enablePartyModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Apply fancy edge breathing effect'**
  String get enablePartyModeSubtitle;

  /// No description provided for @enablePictureInPicture.
  ///
  /// In en, this message translates to:
  /// **'Enable Picture-in-Picture'**
  String get enablePictureInPicture;

  /// No description provided for @enableReordering.
  ///
  /// In en, this message translates to:
  /// **'Enable Reordering'**
  String get enableReordering;

  /// No description provided for @enableReturnYoutubeDislike.
  ///
  /// In en, this message translates to:
  /// **'Enable Return Youtube Dislike'**
  String get enableReturnYoutubeDislike;

  /// No description provided for @enableSearchCleanup.
  ///
  /// In en, this message translates to:
  /// **'Enable Search Cleanup'**
  String get enableSearchCleanup;

  /// No description provided for @enableSearchCleanupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All Symbols and Spaces will be ignored'**
  String get enableSearchCleanupSubtitle;

  /// No description provided for @enableSponsorblock.
  ///
  /// In en, this message translates to:
  /// **'Enable SponsorBlock'**
  String get enableSponsorblock;

  /// No description provided for @enableVideoPlayback.
  ///
  /// In en, this message translates to:
  /// **'Enable Video Playback'**
  String get enableVideoPlayback;

  /// No description provided for @enterSymbol.
  ///
  /// In en, this message translates to:
  /// **'Please Enter a Symbol'**
  String get enterSymbol;

  /// No description provided for @equalizer.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get equalizer;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @errorFetchingVideoList.
  ///
  /// In en, this message translates to:
  /// **'Error fetching video list'**
  String get errorFetchingVideoList;

  /// No description provided for @errorPlayingTrack.
  ///
  /// In en, this message translates to:
  /// **'Error playing track'**
  String get errorPlayingTrack;

  /// No description provided for @excludedFodlers.
  ///
  /// In en, this message translates to:
  /// **'Excluded Folders'**
  String get excludedFodlers;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @exitAppSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap again to exit'**
  String get exitAppSubtitle;

  /// No description provided for @expandedMiniplayer.
  ///
  /// In en, this message translates to:
  /// **'Expanded Miniplayer'**
  String get expandedMiniplayer;

  /// No description provided for @exportAsM3u.
  ///
  /// In en, this message translates to:
  /// **'Export as M3U'**
  String get exportAsM3u;

  /// No description provided for @extension.
  ///
  /// In en, this message translates to:
  /// **'Extension'**
  String get extension;

  /// No description provided for @externalFiles.
  ///
  /// In en, this message translates to:
  /// **'External Files'**
  String get externalFiles;

  /// No description provided for @extract.
  ///
  /// In en, this message translates to:
  /// **'Extract'**
  String get extract;

  /// No description provided for @extractAllColorPalettes.
  ///
  /// In en, this message translates to:
  /// **'Extract All Color Palettes'**
  String get extractAllColorPalettes;

  /// No description provided for @extractAllColorPalettesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{number, plural, one{Extract Remaining {number}?} other{Extract Remaining {number}?}}'**
  String extractAllColorPalettesSubtitle({required int number});

  /// No description provided for @extractFeatArtist.
  ///
  /// In en, this message translates to:
  /// **'Extract feat. artists from title'**
  String get extractFeatArtist;

  /// No description provided for @extractFeatArtistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Extracts (feat. X) and (ft. X) artists, as a new artist entry.'**
  String get extractFeatArtistSubtitle;

  /// No description provided for @extractingInfo.
  ///
  /// In en, this message translates to:
  /// **'Extracting Info'**
  String get extractingInfo;

  /// No description provided for @extras.
  ///
  /// In en, this message translates to:
  /// **'Extras'**
  String get extras;

  /// No description provided for @extrasSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Extra Settings to fine your experience'**
  String get extrasSubtitle;

  /// No description provided for @extreme.
  ///
  /// In en, this message translates to:
  /// **'Extreme'**
  String get extreme;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @failedEdits.
  ///
  /// In en, this message translates to:
  /// **'Failed Edits'**
  String get failedEdits;

  /// No description provided for @favourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get favourites;

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided for @fetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching'**
  String get fetching;

  /// No description provided for @fetchingOfAllVideos.
  ///
  /// In en, this message translates to:
  /// **'Fetching of all videos'**
  String get fetchingOfAllVideos;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @fileAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'File already exists'**
  String get fileAlreadyExists;

  /// No description provided for @fileBasedServerWarning.
  ///
  /// In en, this message translates to:
  /// **'Files will be temporarily downloaded for indexing, Make sure your connection is stable.\nWi-Fi is recommended to avoid high data usage.'**
  String get fileBasedServerWarning;

  /// No description provided for @fileName.
  ///
  /// In en, this message translates to:
  /// **'File Name'**
  String get fileName;

  /// No description provided for @fileNameWoExt.
  ///
  /// In en, this message translates to:
  /// **'Filename without extension'**
  String get fileNameWoExt;

  /// No description provided for @filenameShouldntStartWith.
  ///
  /// In en, this message translates to:
  /// **'Filename shouldn\'t start with'**
  String get filenameShouldntStartWith;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @filler.
  ///
  /// In en, this message translates to:
  /// **'Filler'**
  String get filler;

  /// No description provided for @filterAlbums.
  ///
  /// In en, this message translates to:
  /// **'Filter Albums'**
  String get filterAlbums;

  /// No description provided for @filterArtists.
  ///
  /// In en, this message translates to:
  /// **'Filter Artists'**
  String get filterArtists;

  /// No description provided for @filterGenres.
  ///
  /// In en, this message translates to:
  /// **'Filter Genres'**
  String get filterGenres;

  /// No description provided for @filterPlaylists.
  ///
  /// In en, this message translates to:
  /// **'Filter Playlists'**
  String get filterPlaylists;

  /// No description provided for @filterTracks.
  ///
  /// In en, this message translates to:
  /// **'Filter Tracks'**
  String get filterTracks;

  /// No description provided for @filterTracksBy.
  ///
  /// In en, this message translates to:
  /// **'Filter Tracks in Search Lists By'**
  String get filterTracksBy;

  /// No description provided for @filtered.
  ///
  /// In en, this message translates to:
  /// **'Filtered'**
  String get filtered;

  /// No description provided for @filteredBySizeAndDuration.
  ///
  /// In en, this message translates to:
  /// **'Tracks Filtered by size and duration'**
  String get filteredBySizeAndDuration;

  /// No description provided for @finished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get finished;

  /// No description provided for @finishedUpdatingLibrary.
  ///
  /// In en, this message translates to:
  /// **'Finished Updating Library'**
  String get finishedUpdatingLibrary;

  /// No description provided for @firstListen.
  ///
  /// In en, this message translates to:
  /// **'First listen'**
  String get firstListen;

  /// No description provided for @fixYtdlpBigThumbnailSize.
  ///
  /// In en, this message translates to:
  /// **'Fix yt-dlp big thumbnail size'**
  String get fixYtdlpBigThumbnailSize;

  /// No description provided for @floatingActionButton.
  ///
  /// In en, this message translates to:
  /// **'Floating Action Button'**
  String get floatingActionButton;

  /// No description provided for @folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// No description provided for @folderName.
  ///
  /// In en, this message translates to:
  /// **'Folder Name'**
  String get folderName;

  /// No description provided for @folders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folders;

  /// No description provided for @fontScale.
  ///
  /// In en, this message translates to:
  /// **'Font Scale'**
  String get fontScale;

  /// No description provided for @forceMiniplayerFollowTrackColors.
  ///
  /// In en, this message translates to:
  /// **'Force miniplayer to follow track colors'**
  String get forceMiniplayerFollowTrackColors;

  /// No description provided for @forceSquaredAlbumThumbnail.
  ///
  /// In en, this message translates to:
  /// **'Force Squared Album Thumbnail'**
  String get forceSquaredAlbumThumbnail;

  /// No description provided for @forceSquaredThumbnailNote.
  ///
  /// In en, this message translates to:
  /// **'Thumbnail Size & Tile Height are NOT equal, Square-ish look will not be as expected, Do you wish to make them equal?'**
  String get forceSquaredThumbnailNote;

  /// No description provided for @forceSquaredTrackThumbnail.
  ///
  /// In en, this message translates to:
  /// **'Force Squared Track Thumbnail'**
  String get forceSquaredTrackThumbnail;

  /// No description provided for @forceStopColorPaletteGeneration.
  ///
  /// In en, this message translates to:
  /// **'Force stop extracting color palettes? you can still continue it later'**
  String get forceStopColorPaletteGeneration;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get fullscreen;

  /// No description provided for @gaplessPlayback.
  ///
  /// In en, this message translates to:
  /// **'Gapless Playback'**
  String get gaplessPlayback;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @generateFromDates.
  ///
  /// In en, this message translates to:
  /// **'Time Range'**
  String get generateFromDates;

  /// No description provided for @generateFromDatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate tracks you listened to in a time range'**
  String get generateFromDatesSubtitle;

  /// No description provided for @generateRandomPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Generate random Playlist'**
  String get generateRandomPlaylist;

  /// No description provided for @genre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get genre;

  /// No description provided for @genres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get genres;

  /// No description provided for @goToAlbum.
  ///
  /// In en, this message translates to:
  /// **'Go to Album'**
  String get goToAlbum;

  /// No description provided for @goToArtist.
  ///
  /// In en, this message translates to:
  /// **'Go to Artist'**
  String get goToArtist;

  /// No description provided for @goToChannel.
  ///
  /// In en, this message translates to:
  /// **'Go to channel'**
  String get goToChannel;

  /// No description provided for @goToFolder.
  ///
  /// In en, this message translates to:
  /// **'Go to Folder'**
  String get goToFolder;

  /// No description provided for @goodLooking.
  ///
  /// In en, this message translates to:
  /// **'Good looking'**
  String get goodLooking;

  /// No description provided for @grantStoragePermission.
  ///
  /// In en, this message translates to:
  /// **'Grant Storage Permission'**
  String get grantStoragePermission;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @groupArtworksByAlbum.
  ///
  /// In en, this message translates to:
  /// **'Group Artworks by Album'**
  String get groupArtworksByAlbum;

  /// No description provided for @guide.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get guide;

  /// No description provided for @hapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'Haptic Feedback'**
  String get hapticFeedback;

  /// No description provided for @heightOfAlbumTile.
  ///
  /// In en, this message translates to:
  /// **'Height of Album Tile'**
  String get heightOfAlbumTile;

  /// No description provided for @heightOfTrackTile.
  ///
  /// In en, this message translates to:
  /// **'Height of Track Tile'**
  String get heightOfTrackTile;

  /// No description provided for @hideSkipButtonAfter.
  ///
  /// In en, this message translates to:
  /// **'Hide skip button after'**
  String get hideSkipButtonAfter;

  /// No description provided for @highMatches.
  ///
  /// In en, this message translates to:
  /// **'High matches'**
  String get highMatches;

  /// No description provided for @highPerformance.
  ///
  /// In en, this message translates to:
  /// **'High performance'**
  String get highPerformance;

  /// No description provided for @highlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get highlight;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @historyImportMissingEntriesNote.
  ///
  /// In en, this message translates to:
  /// **'These entries couldn\'t be found inside library, if you believe they exist, please consider adding them manually'**
  String get historyImportMissingEntriesNote;

  /// No description provided for @historyListensReplaceWarning.
  ///
  /// In en, this message translates to:
  /// **'{listensCount, plural, one{{listensCount} listen for {oldTrackInfo} will be replaced with {newTrackInfo}, confirm?} other{{listensCount} listens for {oldTrackInfo} will be replaced with {newTrackInfo}, confirm?}}'**
  String historyListensReplaceWarning({required int listensCount, required String newTrackInfo, required String oldTrackInfo});

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @hook.
  ///
  /// In en, this message translates to:
  /// **'Hook'**
  String get hook;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @hourFormat12.
  ///
  /// In en, this message translates to:
  /// **'12 Hour Format'**
  String get hourFormat12;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// No description provided for @iReadAndAgree.
  ///
  /// In en, this message translates to:
  /// **'I read & agree'**
  String get iReadAndAgree;

  /// No description provided for @ifNotPlaying.
  ///
  /// In en, this message translates to:
  /// **'If not playing'**
  String get ifNotPlaying;

  /// No description provided for @ignoreBatteryOptimizationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads can be throttled when the app is battery restricted'**
  String get ignoreBatteryOptimizationsSubtitle;

  /// No description provided for @ignoreCommonPrefixesWhileSorting.
  ///
  /// In en, this message translates to:
  /// **'Ignore common prefixes while sorting'**
  String get ignoreCommonPrefixesWhileSorting;

  /// No description provided for @ignores.
  ///
  /// In en, this message translates to:
  /// **'Ignores'**
  String get ignores;

  /// No description provided for @imageSource.
  ///
  /// In en, this message translates to:
  /// **'Image source'**
  String get imageSource;

  /// No description provided for @immersiveMode.
  ///
  /// In en, this message translates to:
  /// **'Immersive Mode'**
  String get immersiveMode;

  /// No description provided for @immersiveModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide Status & Navigation bars while Miniplayer is expanded'**
  String get immersiveModeSubtitle;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @importAll.
  ///
  /// In en, this message translates to:
  /// **'Import all'**
  String get importAll;

  /// No description provided for @importLastFmHistory.
  ///
  /// In en, this message translates to:
  /// **'Import LastFm History'**
  String get importLastFmHistory;

  /// No description provided for @importLastFmHistoryGuide.
  ///
  /// In en, this message translates to:
  /// **'1. Go to {lastfmCsvLink}\n\n2. Type your username, fetch and download csv file.\n\n3. Choose the file from the next screen.'**
  String importLastFmHistoryGuide({required String lastfmCsvLink});

  /// No description provided for @importTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Import time range'**
  String get importTimeRange;

  /// No description provided for @importYoutubeHistory.
  ///
  /// In en, this message translates to:
  /// **'Import Youtube History'**
  String get importYoutubeHistory;

  /// No description provided for @importYoutubeHistoryGuide.
  ///
  /// In en, this message translates to:
  /// **'1. Go to {takeoutLink}\n\n2. Press \"Multiple Formats\" and beside \"History\" choose \"JSON\".\n\n3. Press \"All Youtube data included\", Deselect All and choose history only.\n\n4. Create Export, Download & Unzip.\n\n5. Choose \"watch-history.json\" from the next screen.'**
  String importYoutubeHistoryGuide({required String takeoutLink});

  /// No description provided for @importedNChannelsSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'{number, plural, one{Imported {number} channel successfully} other{Imported {number} channels successfully}}'**
  String importedNChannelsSuccessfully({required int number});

  /// No description provided for @importedNPlaylistsSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'{number, plural, one{Imported {numberText} playlist successfully} other{Imported {numberText} playlists successfully}}'**
  String importedNPlaylistsSuccessfully({required int number, required String numberText});

  /// No description provided for @includeVideos.
  ///
  /// In en, this message translates to:
  /// **'Include videos'**
  String get includeVideos;

  /// No description provided for @indexRefreshRequired.
  ///
  /// In en, this message translates to:
  /// **'Do a Refresh after changing this'**
  String get indexRefreshRequired;

  /// No description provided for @indexer.
  ///
  /// In en, this message translates to:
  /// **'Indexer'**
  String get indexer;

  /// No description provided for @indexerNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Incomplete Number of Artworks refers to the duplicated & not found Artworks'**
  String get indexerNote;

  /// No description provided for @indexerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your music Library'**
  String get indexerSubtitle;

  /// No description provided for @infinityQueueOnNextPrev.
  ///
  /// In en, this message translates to:
  /// **'Infinity Queue on Next/Previous'**
  String get infinityQueueOnNextPrev;

  /// No description provided for @infinityQueueOnNextPrevSubtitle.
  ///
  /// In en, this message translates to:
  /// **'pressing next while playing the last item will jump to first, and vice versa'**
  String get infinityQueueOnNextPrevSubtitle;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @inserted.
  ///
  /// In en, this message translates to:
  /// **'inserted'**
  String get inserted;

  /// No description provided for @instantlyApplies.
  ///
  /// In en, this message translates to:
  /// **'Instantly Applies'**
  String get instantlyApplies;

  /// No description provided for @interactionReminder.
  ///
  /// In en, this message translates to:
  /// **'Interaction Reminder'**
  String get interactionReminder;

  /// No description provided for @intro.
  ///
  /// In en, this message translates to:
  /// **'Intro'**
  String get intro;

  /// No description provided for @invertSelection.
  ///
  /// In en, this message translates to:
  /// **'Invert Selection'**
  String get invertSelection;

  /// No description provided for @issues.
  ///
  /// In en, this message translates to:
  /// **'Issues'**
  String get issues;

  /// No description provided for @item.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get item;

  /// No description provided for @jump.
  ///
  /// In en, this message translates to:
  /// **'Jump'**
  String get jump;

  /// No description provided for @jumpToDay.
  ///
  /// In en, this message translates to:
  /// **'Jump to Day'**
  String get jumpToDay;

  /// No description provided for @jumpToFirstTrackAfterQueueFinish.
  ///
  /// In en, this message translates to:
  /// **'Jump to first track after finishing queue'**
  String get jumpToFirstTrackAfterQueueFinish;

  /// No description provided for @keepCachedVersions.
  ///
  /// In en, this message translates to:
  /// **'Keep cached versions'**
  String get keepCachedVersions;

  /// No description provided for @keepFileDates.
  ///
  /// In en, this message translates to:
  /// **'Keep file dates'**
  String get keepFileDates;

  /// No description provided for @keepScreenAwakeMiniplayerExpanded.
  ///
  /// In en, this message translates to:
  /// **'Miniplayer is Expanded'**
  String get keepScreenAwakeMiniplayerExpanded;

  /// No description provided for @keepScreenAwakeMiniplayerExpandedAndVideo.
  ///
  /// In en, this message translates to:
  /// **'Miniplayer is Expanded and a Video is Playing'**
  String get keepScreenAwakeMiniplayerExpandedAndVideo;

  /// No description provided for @keepScreenAwakeNone.
  ///
  /// In en, this message translates to:
  /// **'Don\'t keep screen awake'**
  String get keepScreenAwakeNone;

  /// No description provided for @keepScreenAwakeWhen.
  ///
  /// In en, this message translates to:
  /// **'Keep screen awake when'**
  String get keepScreenAwakeWhen;

  /// No description provided for @killPlayerAfterDismissingApp.
  ///
  /// In en, this message translates to:
  /// **'Kill player after dismissing app'**
  String get killPlayerAfterDismissingApp;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @learnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get learnMore;

  /// No description provided for @leftAction.
  ///
  /// In en, this message translates to:
  /// **'Left Action'**
  String get leftAction;

  /// No description provided for @legacyAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Legacy Authentication'**
  String get legacyAuthentication;

  /// No description provided for @libraryTabs.
  ///
  /// In en, this message translates to:
  /// **'Library Tabs'**
  String get libraryTabs;

  /// No description provided for @libraryTabsReorder.
  ///
  /// In en, this message translates to:
  /// **'You can reorder the activated tabs.'**
  String get libraryTabsReorder;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @licenseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Licenses & Agreements Used by Namida'**
  String get licenseSubtitle;

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @liked.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get liked;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @listOfFolders.
  ///
  /// In en, this message translates to:
  /// **'List of Folders'**
  String get listOfFolders;

  /// No description provided for @loadAll.
  ///
  /// In en, this message translates to:
  /// **'Load all'**
  String get loadAll;

  /// No description provided for @loadingFile.
  ///
  /// In en, this message translates to:
  /// **'Loading File'**
  String get loadingFile;

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @localVideoMatching.
  ///
  /// In en, this message translates to:
  /// **'Local Video Matching'**
  String get localVideoMatching;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @longPressAction.
  ///
  /// In en, this message translates to:
  /// **'Long-Press Action'**
  String get longPressAction;

  /// No description provided for @longPressTheLyricsToEnterFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Long press the lyrics to enter fullscreen'**
  String get longPressTheLyricsToEnterFullscreen;

  /// No description provided for @lostMemories.
  ///
  /// In en, this message translates to:
  /// **'Lost Memories'**
  String get lostMemories;

  /// No description provided for @lostMemoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{number, plural, one{around this time, {number} year ago} other{around this time, {number} years ago}}'**
  String lostMemoriesSubtitle({required int number});

  /// No description provided for @lostPartners.
  ///
  /// In en, this message translates to:
  /// **'Lost Partners'**
  String get lostPartners;

  /// No description provided for @loudnessEnhancer.
  ///
  /// In en, this message translates to:
  /// **'Loudness Enhancer'**
  String get loudnessEnhancer;

  /// No description provided for @lyricist.
  ///
  /// In en, this message translates to:
  /// **'Lyricist'**
  String get lyricist;

  /// No description provided for @lyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// No description provided for @lyricsSource.
  ///
  /// In en, this message translates to:
  /// **'Lyrics source'**
  String get lyricsSource;

  /// No description provided for @m3uPlaylist.
  ///
  /// In en, this message translates to:
  /// **'M3U Playlist'**
  String get m3uPlaylist;

  /// No description provided for @makeYourFirstListen.
  ///
  /// In en, this message translates to:
  /// **'Make your first listen!'**
  String get makeYourFirstListen;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @manageYourAccounts.
  ///
  /// In en, this message translates to:
  /// **'Manage your accounts'**
  String get manageYourAccounts;

  /// No description provided for @manualBackup.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get manualBackup;

  /// No description provided for @manualBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'pick up a specific file'**
  String get manualBackupSubtitle;

  /// No description provided for @markAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get markAsRead;

  /// No description provided for @matchAllTracks.
  ///
  /// In en, this message translates to:
  /// **'Match All Tracks'**
  String get matchAllTracks;

  /// No description provided for @matchAllTracksNote.
  ///
  /// In en, this message translates to:
  /// **'this can have an impact on the matching speed, as it will check all tracks in your library'**
  String get matchAllTracksNote;

  /// No description provided for @matchingType.
  ///
  /// In en, this message translates to:
  /// **'Matching type'**
  String get matchingType;

  /// No description provided for @maxAudioCacheSize.
  ///
  /// In en, this message translates to:
  /// **'Max audio cache size'**
  String get maxAudioCacheSize;

  /// No description provided for @maxImageCacheSize.
  ///
  /// In en, this message translates to:
  /// **'Max image cache size'**
  String get maxImageCacheSize;

  /// No description provided for @maxVideoCacheSize.
  ///
  /// In en, this message translates to:
  /// **'Max video cache size'**
  String get maxVideoCacheSize;

  /// No description provided for @maximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get maximum;

  /// No description provided for @mediaStoreIsEnabledThisWillHaveNoEffect.
  ///
  /// In en, this message translates to:
  /// **'Media Store is enabled, this will have no effect'**
  String get mediaStoreIsEnabledThisWillHaveNoEffect;

  /// No description provided for @medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get medium;

  /// No description provided for @membershipCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get membershipCode;

  /// No description provided for @membershipCodeSentToEmail.
  ///
  /// In en, this message translates to:
  /// **'Code sent to your email'**
  String get membershipCodeSentToEmail;

  /// No description provided for @membershipDidntChange.
  ///
  /// In en, this message translates to:
  /// **'Membership didn\'t change'**
  String get membershipDidntChange;

  /// No description provided for @membershipEnjoyNew.
  ///
  /// In en, this message translates to:
  /// **'Enjoy your new membership'**
  String get membershipEnjoyNew;

  /// No description provided for @membershipFreeCoupon.
  ///
  /// In en, this message translates to:
  /// **'Free Coupon'**
  String get membershipFreeCoupon;

  /// No description provided for @membershipManage.
  ///
  /// In en, this message translates to:
  /// **'Manage your membership'**
  String get membershipManage;

  /// No description provided for @membershipNoSubscriptionsFoundForUser.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions found for this user'**
  String get membershipNoSubscriptionsFoundForUser;

  /// No description provided for @membershipSignInToPatreonAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your patreon account'**
  String get membershipSignInToPatreonAccount;

  /// No description provided for @membershipUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown Membership'**
  String get membershipUnknown;

  /// No description provided for @membershipYouNeedMembershipOfToAddMultipleAccounts.
  ///
  /// In en, this message translates to:
  /// **'You need membership of {name1} or {name2} to add multiple accounts'**
  String membershipYouNeedMembershipOfToAddMultipleAccounts({required String name1, required String name2});

  /// No description provided for @merge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get merge;

  /// No description provided for @metadataCache.
  ///
  /// In en, this message translates to:
  /// **'Metadata Cache'**
  String get metadataCache;

  /// No description provided for @metadataEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to edit metadata'**
  String get metadataEditFailed;

  /// No description provided for @metadataReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read metadata'**
  String get metadataReadFailed;

  /// No description provided for @minFileDuration.
  ///
  /// In en, this message translates to:
  /// **'Minimum Track Duration'**
  String get minFileDuration;

  /// No description provided for @minFileSize.
  ///
  /// In en, this message translates to:
  /// **'Minimum File Size'**
  String get minFileSize;

  /// No description provided for @minTrackDurationToRestoreLastPosition.
  ///
  /// In en, this message translates to:
  /// **'Minimum track duration to restore last played position'**
  String get minTrackDurationToRestoreLastPosition;

  /// No description provided for @minValueCantBeMoreThanMax.
  ///
  /// In en, this message translates to:
  /// **'Minimum value can\'t be more than the maximum'**
  String get minValueCantBeMoreThanMax;

  /// No description provided for @minValueToCountTrackListen.
  ///
  /// In en, this message translates to:
  /// **'Count a listen after: '**
  String get minValueToCountTrackListen;

  /// No description provided for @minimizedMiniplayer.
  ///
  /// In en, this message translates to:
  /// **'Minimized Miniplayer'**
  String get minimizedMiniplayer;

  /// No description provided for @minimum.
  ///
  /// In en, this message translates to:
  /// **'Minimum'**
  String get minimum;

  /// No description provided for @minimumOneFolderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'There should be at least 1 folder, add more folders if you want to remove this one'**
  String get minimumOneFolderSubtitle;

  /// No description provided for @minimumOneItem.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove item'**
  String get minimumOneItem;

  /// No description provided for @minimumOneItemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{number, plural, one{At least {number} item should remain} other{At least {number} items should remain}}'**
  String minimumOneItemSubtitle({required int number});

  /// No description provided for @minimumSegmentDuration.
  ///
  /// In en, this message translates to:
  /// **'Minimum Segment Duration'**
  String get minimumSegmentDuration;

  /// No description provided for @miniplayerCustomization.
  ///
  /// In en, this message translates to:
  /// **'Miniplayer Customization'**
  String get miniplayerCustomization;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutes;

  /// No description provided for @missingEntries.
  ///
  /// In en, this message translates to:
  /// **'Missing Entries'**
  String get missingEntries;

  /// No description provided for @missingTracks.
  ///
  /// In en, this message translates to:
  /// **'Missing Tracks'**
  String get missingTracks;

  /// No description provided for @mix.
  ///
  /// In en, this message translates to:
  /// **'Mix'**
  String get mix;

  /// No description provided for @mixPlaylistGeneratedByYoutube.
  ///
  /// In en, this message translates to:
  /// **'Mix playlist generated by youtube'**
  String get mixPlaylistGeneratedByYoutube;

  /// No description provided for @mixes.
  ///
  /// In en, this message translates to:
  /// **'Mixes'**
  String get mixes;

  /// No description provided for @mobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get mobile;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @months.
  ///
  /// In en, this message translates to:
  /// **'Months'**
  String get months;

  /// No description provided for @mood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get mood;

  /// No description provided for @moods.
  ///
  /// In en, this message translates to:
  /// **'Moods'**
  String get moods;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @mostPlayed.
  ///
  /// In en, this message translates to:
  /// **'Most Played'**
  String get mostPlayed;

  /// No description provided for @multipleTracksTagsEditNote.
  ///
  /// In en, this message translates to:
  /// **'You are about to edit these tracks,\nUnchanged fields remain untouched.'**
  String get multipleTracksTagsEditNote;

  /// No description provided for @musicOfftopic.
  ///
  /// In en, this message translates to:
  /// **'Music Offtopic'**
  String get musicOfftopic;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameContainsBadCharacter.
  ///
  /// In en, this message translates to:
  /// **'Name contains bad character'**
  String get nameContainsBadCharacter;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @newDirectory.
  ///
  /// In en, this message translates to:
  /// **'New directory'**
  String get newDirectory;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @newTracksAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Tracks'**
  String get newTracksAdd;

  /// No description provided for @newTracksMoods.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get newTracksMoods;

  /// No description provided for @newTracksMoodsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate tracks based on available moods'**
  String get newTracksMoodsSubtitle;

  /// No description provided for @newTracksRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get newTracksRandom;

  /// No description provided for @newTracksRandomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick up random tracks from your library'**
  String get newTracksRandomSubtitle;

  /// No description provided for @newTracksRatings.
  ///
  /// In en, this message translates to:
  /// **'Ratings'**
  String get newTracksRatings;

  /// No description provided for @newTracksRatingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate tracks that has specific rating'**
  String get newTracksRatingsSubtitle;

  /// No description provided for @newTracksRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get newTracksRecommended;

  /// No description provided for @newTracksRecommendedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate tracks you usually listened to with {currentTrack}'**
  String newTracksRecommendedSubtitle({required String currentTrack});

  /// No description provided for @newTracksSimilarrReleaseDate.
  ///
  /// In en, this message translates to:
  /// **'Similar Release Date'**
  String get newTracksSimilarrReleaseDate;

  /// No description provided for @newTracksSimilarrReleaseDateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate tracks that were released around the same time as {currentTrack}'**
  String newTracksSimilarrReleaseDateSubtitle({required String currentTrack});

  /// No description provided for @newTracksUnknownYear.
  ///
  /// In en, this message translates to:
  /// **'Track has unknown year'**
  String get newTracksUnknownYear;

  /// No description provided for @newest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get newest;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'no'**
  String get no;

  /// No description provided for @noChangesFound.
  ///
  /// In en, this message translates to:
  /// **'No changes has been found.'**
  String get noChangesFound;

  /// No description provided for @noEnoughTracks.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have much tracks..'**
  String get noEnoughTracks;

  /// No description provided for @noExcludedFolders.
  ///
  /// In en, this message translates to:
  /// **'You Don\'t have any excluded folders'**
  String get noExcludedFolders;

  /// No description provided for @noFolderChosen.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t chosen any folder'**
  String get noFolderChosen;

  /// No description provided for @noMoodsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No moods available'**
  String get noMoodsAvailable;

  /// No description provided for @noNetworkAvailableToFetchData.
  ///
  /// In en, this message translates to:
  /// **'No network available to fetch data'**
  String get noNetworkAvailableToFetchData;

  /// No description provided for @noTracksFound.
  ///
  /// In en, this message translates to:
  /// **'No tracks were found'**
  String get noTracksFound;

  /// No description provided for @noTracksFoundBetweenDates.
  ///
  /// In en, this message translates to:
  /// **'This time range doesn\'t have any tracks.'**
  String get noTracksFoundBetweenDates;

  /// No description provided for @noTracksFoundInDirectory.
  ///
  /// In en, this message translates to:
  /// **'No tracks found in this directory'**
  String get noTracksFoundInDirectory;

  /// No description provided for @noTracksInHistory.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have enough tracks in history'**
  String get noTracksInHistory;

  /// No description provided for @nonActive.
  ///
  /// In en, this message translates to:
  /// **'Non-Active'**
  String get nonActive;

  /// No description provided for @nonFavourites.
  ///
  /// In en, this message translates to:
  /// **'Non-Favourites'**
  String get nonFavourites;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @normalizeAudio.
  ///
  /// In en, this message translates to:
  /// **'Normalize audio'**
  String get normalizeAudio;

  /// No description provided for @normalizeAudioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Normalizes volume by reading the replay gain tag or the info provided by youtube'**
  String get normalizeAudioSubtitle;

  /// No description provided for @notAvailableForYourDevice.
  ///
  /// In en, this message translates to:
  /// **'Not Available for your Device'**
  String get notAvailableForYourDevice;

  /// No description provided for @notSupportedForNetworkFiles.
  ///
  /// In en, this message translates to:
  /// **'Not Supported for Network Files'**
  String get notSupportedForNetworkFiles;

  /// No description provided for @notSupportedForVideoFiles.
  ///
  /// In en, this message translates to:
  /// **'Not Supported for Video Files'**
  String get notSupportedForVideoFiles;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @notification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notification;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @numberOfTracks.
  ///
  /// In en, this message translates to:
  /// **'Number of Tracks'**
  String get numberOfTracks;

  /// No description provided for @ofLabel.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get ofLabel;

  /// No description provided for @offlineSearch.
  ///
  /// In en, this message translates to:
  /// **'Offline Search'**
  String get offlineSearch;

  /// No description provided for @offset.
  ///
  /// In en, this message translates to:
  /// **'Offset'**
  String get offset;

  /// No description provided for @oldDirectory.
  ///
  /// In en, this message translates to:
  /// **'Old directory'**
  String get oldDirectory;

  /// No description provided for @oldDirectoryStillHasTracks.
  ///
  /// In en, this message translates to:
  /// **'Old Directory still have some tracks, confirm?'**
  String get oldDirectoryStillHasTracks;

  /// No description provided for @oldestWatch.
  ///
  /// In en, this message translates to:
  /// **'Oldest Watch'**
  String get oldestWatch;

  /// No description provided for @onDeviceConnect.
  ///
  /// In en, this message translates to:
  /// **'On Device Connect'**
  String get onDeviceConnect;

  /// No description provided for @onInterruption.
  ///
  /// In en, this message translates to:
  /// **'On Interruption'**
  String get onInterruption;

  /// No description provided for @onNotificationTap.
  ///
  /// In en, this message translates to:
  /// **'On Notification Tap'**
  String get onNotificationTap;

  /// No description provided for @onOpeningYoutubeLink.
  ///
  /// In en, this message translates to:
  /// **'On opening youtube link'**
  String get onOpeningYoutubeLink;

  /// No description provided for @onSwiping.
  ///
  /// In en, this message translates to:
  /// **'On Swiping'**
  String get onSwiping;

  /// No description provided for @onVolumeZero.
  ///
  /// In en, this message translates to:
  /// **'On Volume 0'**
  String get onVolumeZero;

  /// No description provided for @ongoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get ongoing;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @openApp.
  ///
  /// In en, this message translates to:
  /// **'Open App'**
  String get openApp;

  /// No description provided for @openInFileExplorer.
  ///
  /// In en, this message translates to:
  /// **'Open in File Explorer'**
  String get openInFileExplorer;

  /// No description provided for @openInYoutubeView.
  ///
  /// In en, this message translates to:
  /// **'Open in Youtube view'**
  String get openInYoutubeView;

  /// No description provided for @openMiniplayer.
  ///
  /// In en, this message translates to:
  /// **'Open Miniplayer'**
  String get openMiniplayer;

  /// No description provided for @openQueue.
  ///
  /// In en, this message translates to:
  /// **'Open Queue'**
  String get openQueue;

  /// No description provided for @openYoutubeLink.
  ///
  /// In en, this message translates to:
  /// **'Open Youtube Link'**
  String get openYoutubeLink;

  /// No description provided for @operationRequiresAccount.
  ///
  /// In en, this message translates to:
  /// **'Operation {name} requires account, Sign in to proceed'**
  String operationRequiresAccount({required String name});

  /// No description provided for @operationRequiresMembership.
  ///
  /// In en, this message translates to:
  /// **'Operation {operation} requires at least membership {name}'**
  String operationRequiresMembership({required String name, required String operation});

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @others.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get others;

  /// No description provided for @output.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get output;

  /// No description provided for @outro.
  ///
  /// In en, this message translates to:
  /// **'Outro'**
  String get outro;

  /// No description provided for @overrideOldFilesInTheSameFolder.
  ///
  /// In en, this message translates to:
  /// **'Override old files in the same folder'**
  String get overrideOldFilesInTheSameFolder;

  /// No description provided for @palette.
  ///
  /// In en, this message translates to:
  /// **'Palette'**
  String get palette;

  /// No description provided for @paletteMix.
  ///
  /// In en, this message translates to:
  /// **'Mix'**
  String get paletteMix;

  /// No description provided for @paletteNewMix.
  ///
  /// In en, this message translates to:
  /// **'New Mix'**
  String get paletteNewMix;

  /// No description provided for @paletteSelectedMix.
  ///
  /// In en, this message translates to:
  /// **'Selected Mix'**
  String get paletteSelectedMix;

  /// No description provided for @parallelDownloads.
  ///
  /// In en, this message translates to:
  /// **'Parallel Downloads'**
  String get parallelDownloads;

  /// No description provided for @parsed.
  ///
  /// In en, this message translates to:
  /// **'parsed'**
  String get parsed;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @path.
  ///
  /// In en, this message translates to:
  /// **'File Full Path'**
  String get path;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @pauseFadeDuration.
  ///
  /// In en, this message translates to:
  /// **'Pause Fade Duration'**
  String get pauseFadeDuration;

  /// No description provided for @pausePlayback.
  ///
  /// In en, this message translates to:
  /// **'Pause playback'**
  String get pausePlayback;

  /// No description provided for @percentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage'**
  String get percentage;

  /// No description provided for @performanceMode.
  ///
  /// In en, this message translates to:
  /// **'Performance mode'**
  String get performanceMode;

  /// No description provided for @performanceNote.
  ///
  /// In en, this message translates to:
  /// **'Might affect performance'**
  String get performanceNote;

  /// No description provided for @personalized.
  ///
  /// In en, this message translates to:
  /// **'Personalized'**
  String get personalized;

  /// No description provided for @personalizedRelatedVideos.
  ///
  /// In en, this message translates to:
  /// **'Personalized Related Videos'**
  String get personalizedRelatedVideos;

  /// No description provided for @personalizedRelatedVideosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disabling this will increase data usage'**
  String get personalizedRelatedVideosSubtitle;

  /// No description provided for @pickColorsFromDeviceWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Pick Colors from Device Wallpaper'**
  String get pickColorsFromDeviceWallpaper;

  /// No description provided for @pickFromStorage.
  ///
  /// In en, this message translates to:
  /// **'Pick from storage'**
  String get pickFromStorage;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// No description provided for @pitch.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get pitch;

  /// No description provided for @plain.
  ///
  /// In en, this message translates to:
  /// **'Plain'**
  String get plain;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @playAfter.
  ///
  /// In en, this message translates to:
  /// **'Play After'**
  String get playAfter;

  /// No description provided for @playAfterNextPrev.
  ///
  /// In en, this message translates to:
  /// **'Auto Play on Next/Previous'**
  String get playAfterNextPrev;

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play All'**
  String get playAll;

  /// No description provided for @playFadeDuration.
  ///
  /// In en, this message translates to:
  /// **'Play Fade Duration'**
  String get playFadeDuration;

  /// No description provided for @playLast.
  ///
  /// In en, this message translates to:
  /// **'Play Last'**
  String get playLast;

  /// No description provided for @playNext.
  ///
  /// In en, this message translates to:
  /// **'Play Next'**
  String get playNext;

  /// No description provided for @playbackSetting.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playbackSetting;

  /// No description provided for @playbackSettingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Can be accessed directly in the player by long pressing the audio button'**
  String get playbackSettingSubtitle;

  /// No description provided for @playlist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlist;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @playlistsImportM3uNative.
  ///
  /// In en, this message translates to:
  /// **'This will import M3U playlists to be used only by namida, use if you are migrating'**
  String get playlistsImportM3uNative;

  /// No description provided for @playlistsImportM3uSynced.
  ///
  /// In en, this message translates to:
  /// **'This will automatically import M3U playlists from indexer folders and keep them synced with the original M3U file. enable if you access/modify the playlists from other apps'**
  String get playlistsImportM3uSynced;

  /// No description provided for @playlistsImportM3uSyncedAutoImport.
  ///
  /// In en, this message translates to:
  /// **'Auto import M3U Playlists'**
  String get playlistsImportM3uSyncedAutoImport;

  /// No description provided for @pleaseEnterADifferentName.
  ///
  /// In en, this message translates to:
  /// **'This name already exists :(\nplease try another fancy name'**
  String get pleaseEnterADifferentName;

  /// No description provided for @pleaseEnterALink.
  ///
  /// In en, this message translates to:
  /// **'Please enter a link'**
  String get pleaseEnterALink;

  /// No description provided for @pleaseEnterALinkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'umm.. is this a youtube link?'**
  String get pleaseEnterALinkSubtitle;

  /// No description provided for @pleaseEnterAName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get pleaseEnterAName;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @preventDuplicatedTracks.
  ///
  /// In en, this message translates to:
  /// **'Prevent Duplicated tracks'**
  String get preventDuplicatedTracks;

  /// No description provided for @preventDuplicatedTracksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Uses filename to uniqely identify tracks'**
  String get preventDuplicatedTracksSubtitle;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @previousButtonReplays.
  ///
  /// In en, this message translates to:
  /// **'Previous button replays'**
  String get previousButtonReplays;

  /// No description provided for @previousButtonReplaysSubtitle.
  ///
  /// In en, this message translates to:
  /// **'if pressed while current position was more than seek duration'**
  String get previousButtonReplaysSubtitle;

  /// No description provided for @prioritizeEmbeddedLyrics.
  ///
  /// In en, this message translates to:
  /// **'Prioritize embedded lyrics'**
  String get prioritizeEmbeddedLyrics;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @private.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get private;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @promptToChangeTrackPath.
  ///
  /// In en, this message translates to:
  /// **'Usually this happens when you delete/move/rename the file outside namida, Would you like to update current path?'**
  String get promptToChangeTrackPath;

  /// No description provided for @public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get public;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// No description provided for @queues.
  ///
  /// In en, this message translates to:
  /// **'Queues'**
  String get queues;

  /// No description provided for @random.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get random;

  /// No description provided for @randomPicks.
  ///
  /// In en, this message translates to:
  /// **'Random Picks'**
  String get randomPicks;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @reIndex.
  ///
  /// In en, this message translates to:
  /// **'Re-index'**
  String get reIndex;

  /// No description provided for @reIndexSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rebuild your music library from scratch'**
  String get reIndexSubtitle;

  /// No description provided for @reIndexWarning.
  ///
  /// In en, this message translates to:
  /// **'This process might take a while, depending on your library size.\n\nArtworks will not get re-indexed as long as they still exist'**
  String get reIndexWarning;

  /// No description provided for @recentAlbums.
  ///
  /// In en, this message translates to:
  /// **'Recent Albums'**
  String get recentAlbums;

  /// No description provided for @recentArtists.
  ///
  /// In en, this message translates to:
  /// **'Recent Artists'**
  String get recentArtists;

  /// No description provided for @recentListens.
  ///
  /// In en, this message translates to:
  /// **'Recent Listens'**
  String get recentListens;

  /// No description provided for @recentQueues.
  ///
  /// In en, this message translates to:
  /// **'Recent Queues'**
  String get recentQueues;

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently Added'**
  String get recentlyAdded;

  /// No description provided for @recordLabel.
  ///
  /// In en, this message translates to:
  /// **'Record Label'**
  String get recordLabel;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @refreshLibrary.
  ///
  /// In en, this message translates to:
  /// **'Refresh Library'**
  String get refreshLibrary;

  /// No description provided for @refreshLibrarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check for newly added or deleted music'**
  String get refreshLibrarySubtitle;

  /// No description provided for @refreshOnStartup.
  ///
  /// In en, this message translates to:
  /// **'Refresh on startup'**
  String get refreshOnStartup;

  /// No description provided for @relatedVideos.
  ///
  /// In en, this message translates to:
  /// **'Related videos'**
  String get relatedVideos;

  /// No description provided for @rememberAudioOnlyMode.
  ///
  /// In en, this message translates to:
  /// **'Remember audio only mode'**
  String get rememberAudioOnlyMode;

  /// No description provided for @remixer.
  ///
  /// In en, this message translates to:
  /// **'Remixer'**
  String get remixer;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Remove Duplicates'**
  String get removeDuplicates;

  /// No description provided for @removeFromFavourites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get removeFromFavourites;

  /// No description provided for @removeFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get removeFromLibrary;

  /// No description provided for @removeFromPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Remove From Playlist'**
  String get removeFromPlaylist;

  /// No description provided for @removeQueue.
  ///
  /// In en, this message translates to:
  /// **'Remove Queue'**
  String get removeQueue;

  /// No description provided for @removeSourceFromHistory.
  ///
  /// In en, this message translates to:
  /// **'Remove source from history'**
  String get removeSourceFromHistory;

  /// No description provided for @removeWhitespaces.
  ///
  /// In en, this message translates to:
  /// **'Remove Whitespaces'**
  String get removeWhitespaces;

  /// No description provided for @removed.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get removed;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renamePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Rename Playlist'**
  String get renamePlaylist;

  /// No description provided for @reorderable.
  ///
  /// In en, this message translates to:
  /// **'Reorderable'**
  String get reorderable;

  /// No description provided for @repeatForNTimes.
  ///
  /// In en, this message translates to:
  /// **'{number, plural, one{Repeat for {number} more time} other{Repeat for {number} more times}}'**
  String repeatForNTimes({required int number});

  /// No description provided for @repeatMode.
  ///
  /// In en, this message translates to:
  /// **'Repeat mode'**
  String get repeatMode;

  /// No description provided for @repeatModeAll.
  ///
  /// In en, this message translates to:
  /// **'Repeat All Queue'**
  String get repeatModeAll;

  /// No description provided for @repeatModeNone.
  ///
  /// In en, this message translates to:
  /// **'Stop on Last Track'**
  String get repeatModeNone;

  /// No description provided for @repeatModeOne.
  ///
  /// In en, this message translates to:
  /// **'Repeat Current Track'**
  String get repeatModeOne;

  /// No description provided for @replaceAllListensWithAnotherTrack.
  ///
  /// In en, this message translates to:
  /// **'Replace all listens with another track'**
  String get replaceAllListensWithAnotherTrack;

  /// No description provided for @replies.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get replies;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @requiresClearingImageCacheAndReIndexing.
  ///
  /// In en, this message translates to:
  /// **'Requires clearing image cache and re indexing'**
  String get requiresClearingImageCacheAndReIndexing;

  /// No description provided for @rescanVideos.
  ///
  /// In en, this message translates to:
  /// **'Re-scan videos'**
  String get rescanVideos;

  /// No description provided for @resetBrightness.
  ///
  /// In en, this message translates to:
  /// **'Reset brightness'**
  String get resetBrightness;

  /// No description provided for @resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Set to'**
  String get resetToDefault;

  /// No description provided for @respectNoMedia.
  ///
  /// In en, this message translates to:
  /// **'Respect .nomedia'**
  String get respectNoMedia;

  /// No description provided for @respectNoMediaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Don\'t include folders that has .nomedia'**
  String get respectNoMediaSubtitle;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore Backup'**
  String get restoreBackup;

  /// No description provided for @restoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore Defaults'**
  String get restoreDefaults;

  /// No description provided for @restoredBackupSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Restored Backup'**
  String get restoredBackupSuccessfully;

  /// No description provided for @restoredBackupSuccessfullySub.
  ///
  /// In en, this message translates to:
  /// **'Backup file has been restored successfully'**
  String get restoredBackupSuccessfullySub;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @resumeIfWasInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Resume if was paused by interruption'**
  String get resumeIfWasInterrupted;

  /// No description provided for @resumeIfWasPausedByDeviceDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Resume if was paused by device disconnect'**
  String get resumeIfWasPausedByDeviceDisconnect;

  /// No description provided for @resumeIfWasPausedByVolume.
  ///
  /// In en, this message translates to:
  /// **'Resume if was paused by volume'**
  String get resumeIfWasPausedByVolume;

  /// No description provided for @resumeIfWasPausedForLessThanNMin.
  ///
  /// In en, this message translates to:
  /// **'{number, plural, one{Resume if was paused for less than {number} minute} other{Resume if was paused for less than {number} minutes}}'**
  String resumeIfWasPausedForLessThanNMin({required int number});

  /// No description provided for @returnYoutubeDislike.
  ///
  /// In en, this message translates to:
  /// **'Return Youtube Dislike'**
  String get returnYoutubeDislike;

  /// No description provided for @reverseOrder.
  ///
  /// In en, this message translates to:
  /// **'Reverse Order'**
  String get reverseOrder;

  /// No description provided for @rightAction.
  ///
  /// In en, this message translates to:
  /// **'Right Action'**
  String get rightAction;

  /// No description provided for @ringtone.
  ///
  /// In en, this message translates to:
  /// **'Ringtone'**
  String get ringtone;

  /// No description provided for @sameDirectoryOnly.
  ///
  /// In en, this message translates to:
  /// **'Same directory only'**
  String get sameDirectoryOnly;

  /// No description provided for @sample.
  ///
  /// In en, this message translates to:
  /// **'Sample'**
  String get sample;

  /// No description provided for @sampleRate.
  ///
  /// In en, this message translates to:
  /// **'Sample Rate'**
  String get sampleRate;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Save to library'**
  String get saveToLibrary;

  /// No description provided for @savedIn.
  ///
  /// In en, this message translates to:
  /// **'Saved in'**
  String get savedIn;

  /// No description provided for @scaleMultiplier.
  ///
  /// In en, this message translates to:
  /// **'Scale Multiplier'**
  String get scaleMultiplier;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchYoutube.
  ///
  /// In en, this message translates to:
  /// **'Search YouTube'**
  String get searchYoutube;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get seconds;

  /// No description provided for @seeProjectCodeOnSite.
  ///
  /// In en, this message translates to:
  /// **'See Project Code on {site}'**
  String seeProjectCodeOnSite({required String site});

  /// No description provided for @seekDuration.
  ///
  /// In en, this message translates to:
  /// **'Seek Duration'**
  String get seekDuration;

  /// No description provided for @seekDurationInfo.
  ///
  /// In en, this message translates to:
  /// **'You can tap on current duration to seek backwards & total duration to seek forwards'**
  String get seekDurationInfo;

  /// No description provided for @seekbar.
  ///
  /// In en, this message translates to:
  /// **'Seekbar'**
  String get seekbar;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @selectFilesAlreadyInLocalLibrary.
  ///
  /// In en, this message translates to:
  /// **'Select files already in local library'**
  String get selectFilesAlreadyInLocalLibrary;

  /// No description provided for @selectedTracks.
  ///
  /// In en, this message translates to:
  /// **'Selected Tracks'**
  String get selectedTracks;

  /// No description provided for @selfPromotion.
  ///
  /// In en, this message translates to:
  /// **'Self Promotion'**
  String get selfPromotion;

  /// No description provided for @semitones.
  ///
  /// In en, this message translates to:
  /// **'Semitones'**
  String get semitones;

  /// No description provided for @separatorsBlacklistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'These words will not get split'**
  String get separatorsBlacklistSubtitle;

  /// No description provided for @separatorsMessage.
  ///
  /// In en, this message translates to:
  /// **'No need to insert spaces, unless you wanna use a letter/symbol that can be found in a whole word (like x and ft.)'**
  String get separatorsMessage;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server Address'**
  String get serverAddress;

  /// No description provided for @setAs.
  ///
  /// In en, this message translates to:
  /// **'Set as'**
  String get setAs;

  /// No description provided for @setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as Default'**
  String get setAsDefault;

  /// No description provided for @setFileLastModifiedAsVideoUploadDate.
  ///
  /// In en, this message translates to:
  /// **'Set file last modified as video upload date'**
  String get setFileLastModifiedAsVideoUploadDate;

  /// No description provided for @setMonoAudio.
  ///
  /// In en, this message translates to:
  /// **'Set Mono Audio'**
  String get setMonoAudio;

  /// No description provided for @setMoods.
  ///
  /// In en, this message translates to:
  /// **'Set moods'**
  String get setMoods;

  /// No description provided for @setMoodsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use commas (,) to separate between them'**
  String get setMoodsSubtitle;

  /// No description provided for @setRating.
  ///
  /// In en, this message translates to:
  /// **'Set Rating'**
  String get setRating;

  /// No description provided for @setTags.
  ///
  /// In en, this message translates to:
  /// **'Set tags'**
  String get setTags;

  /// No description provided for @setYoutubeLink.
  ///
  /// In en, this message translates to:
  /// **'Set Youtube Link'**
  String get setYoutubeLink;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @setupFirstStartup.
  ///
  /// In en, this message translates to:
  /// **'Setup first startup'**
  String get setupFirstStartup;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareLogs.
  ///
  /// In en, this message translates to:
  /// **'Share Logs'**
  String get shareLogs;

  /// No description provided for @shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get shortcuts;

  /// No description provided for @shouldDuck.
  ///
  /// In en, this message translates to:
  /// **'Should duck'**
  String get shouldDuck;

  /// No description provided for @shouldDuckNote.
  ///
  /// In en, this message translates to:
  /// **'Indicates that the volume should be lowered. ex: notification'**
  String get shouldDuckNote;

  /// No description provided for @shouldPause.
  ///
  /// In en, this message translates to:
  /// **'Should pause'**
  String get shouldPause;

  /// No description provided for @shouldPauseNote.
  ///
  /// In en, this message translates to:
  /// **'Indicates that the playback should be paused. ex: calls'**
  String get shouldPauseNote;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show All'**
  String get showAll;

  /// No description provided for @showChannelWatermarkInFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Show channel watermark in fullscreen'**
  String get showChannelWatermarkInFullscreen;

  /// No description provided for @showFailedOnly.
  ///
  /// In en, this message translates to:
  /// **'Show Failed only'**
  String get showFailedOnly;

  /// No description provided for @showHideUnknownFields.
  ///
  /// In en, this message translates to:
  /// **'Show/hide Unknown Fields'**
  String get showHideUnknownFields;

  /// No description provided for @showInSeekbar.
  ///
  /// In en, this message translates to:
  /// **'Show in Seekbar'**
  String get showInSeekbar;

  /// No description provided for @showMixPlaylistsIn.
  ///
  /// In en, this message translates to:
  /// **'Show Mixes in'**
  String get showMixPlaylistsIn;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// No description provided for @showShortVideosIn.
  ///
  /// In en, this message translates to:
  /// **'Show Shorts in'**
  String get showShortVideosIn;

  /// No description provided for @showSkipButton.
  ///
  /// In en, this message translates to:
  /// **'Show Skip Button'**
  String get showSkipButton;

  /// No description provided for @showVideoEndcards.
  ///
  /// In en, this message translates to:
  /// **'Show video endcards'**
  String get showVideoEndcards;

  /// No description provided for @showWebm.
  ///
  /// In en, this message translates to:
  /// **'Show webm'**
  String get showWebm;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @shuffleAll.
  ///
  /// In en, this message translates to:
  /// **'Shuffle All'**
  String get shuffleAll;

  /// No description provided for @shuffleNext.
  ///
  /// In en, this message translates to:
  /// **'Shuffle Next'**
  String get shuffleNext;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInCanceled.
  ///
  /// In en, this message translates to:
  /// **'Sign in was canceled'**
  String get signInCanceled;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed'**
  String get signInFailed;

  /// No description provided for @signInToYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your account'**
  String get signInToYourAccount;

  /// No description provided for @signInYouDontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any account signed in'**
  String get signInYouDontHaveAccount;

  /// No description provided for @signInYouNeedAccountToViewPage.
  ///
  /// In en, this message translates to:
  /// **'You need an account to view this page'**
  String get signInYouNeedAccountToViewPage;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutFromName.
  ///
  /// In en, this message translates to:
  /// **'Sign out from {name}'**
  String signOutFromName({required String name});

  /// No description provided for @signingInAllowsBasicUsage.
  ///
  /// In en, this message translates to:
  /// **'Signing in allows basic usage'**
  String get signingInAllowsBasicUsage;

  /// No description provided for @signingInAllowsBasicUsageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get early access through patreon or by using coupon'**
  String get signingInAllowsBasicUsageSubtitle;

  /// No description provided for @similarDiscoverDate.
  ///
  /// In en, this message translates to:
  /// **'Similar Discover Date'**
  String get similarDiscoverDate;

  /// No description provided for @similarDiscoverDateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate tracks that were discovered around the same time as {currentTrack}'**
  String similarDiscoverDateSubtitle({required String currentTrack});

  /// No description provided for @similarTimeRange.
  ///
  /// In en, this message translates to:
  /// **'Similar Time Range'**
  String get similarTimeRange;

  /// No description provided for @similarTimeRangeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Generate tracks you listened to around the same time as {currentTrack}'**
  String similarTimeRangeSubtitle({required String currentTrack});

  /// No description provided for @singles.
  ///
  /// In en, this message translates to:
  /// **'Singles'**
  String get singles;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @skipCountTracking.
  ///
  /// In en, this message translates to:
  /// **'Skip Count Tracking'**
  String get skipCountTracking;

  /// No description provided for @skipSilence.
  ///
  /// In en, this message translates to:
  /// **'Skip Silence'**
  String get skipSilence;

  /// No description provided for @skipSponsorSegmentsInVideos.
  ///
  /// In en, this message translates to:
  /// **'Skip Sponsor Segments in Videos'**
  String get skipSponsorSegmentsInVideos;

  /// No description provided for @sleepAfter.
  ///
  /// In en, this message translates to:
  /// **'Sleep After'**
  String get sleepAfter;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// No description provided for @socials.
  ///
  /// In en, this message translates to:
  /// **'Socials'**
  String get socials;

  /// No description provided for @socialsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join us on our platforms for Updates, Tips, Discussion & Ideas'**
  String get socialsSubtitle;

  /// No description provided for @someWebServersRequireAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Some web servers require authentication. Please update credentials to maintain access to your library.'**
  String get someWebServersRequireAuthentication;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @sponsor.
  ///
  /// In en, this message translates to:
  /// **'Sponsor'**
  String get sponsor;

  /// No description provided for @sponsorblock.
  ///
  /// In en, this message translates to:
  /// **'SponsorBlock'**
  String get sponsorblock;

  /// No description provided for @sponsorblockLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'SponsorBlock Leaderboard'**
  String get sponsorblockLeaderboard;

  /// No description provided for @staggeredAlbumGridView.
  ///
  /// In en, this message translates to:
  /// **'Staggered Album Gridview'**
  String get staggeredAlbumGridView;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get stats;

  /// No description provided for @statsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Here is some info about your library'**
  String get statsSubtitle;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @stopAfterThisTrack.
  ///
  /// In en, this message translates to:
  /// **'Stop after this track'**
  String get stopAfterThisTrack;

  /// No description provided for @stopAfterThisVideo.
  ///
  /// In en, this message translates to:
  /// **'Stop after this video'**
  String get stopAfterThisVideo;

  /// No description provided for @storagePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission Denied'**
  String get storagePermissionDenied;

  /// No description provided for @storagePermissionDeniedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please allow access to be able to perform this action'**
  String get storagePermissionDeniedSubtitle;

  /// No description provided for @stretchLyricsDuration.
  ///
  /// In en, this message translates to:
  /// **'Stretch Lyrics Duration'**
  String get stretchLyricsDuration;

  /// No description provided for @subdirectory.
  ///
  /// In en, this message translates to:
  /// **'Subdirectory'**
  String get subdirectory;

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscribe;

  /// No description provided for @subscribed.
  ///
  /// In en, this message translates to:
  /// **'Subscribed'**
  String get subscribed;

  /// No description provided for @subscriber.
  ///
  /// In en, this message translates to:
  /// **'Subscriber'**
  String get subscriber;

  /// No description provided for @subscribers.
  ///
  /// In en, this message translates to:
  /// **'Subscribers'**
  String get subscribers;

  /// No description provided for @succeeded.
  ///
  /// In en, this message translates to:
  /// **'Succeeded'**
  String get succeeded;

  /// No description provided for @suggestionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Have an Issue or Suggestion? Open an issue on {site}'**
  String suggestionSubtitle({required String site});

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @supremacy.
  ///
  /// In en, this message translates to:
  /// **'Supremacy'**
  String get supremacy;

  /// No description provided for @sussyBaka.
  ///
  /// In en, this message translates to:
  /// **'Bruh no tracks'**
  String get sussyBaka;

  /// No description provided for @swipeActions.
  ///
  /// In en, this message translates to:
  /// **'Swipe Actions'**
  String get swipeActions;

  /// No description provided for @swipeToOpenDrawer.
  ///
  /// In en, this message translates to:
  /// **'Swipe to open drawer'**
  String get swipeToOpenDrawer;

  /// No description provided for @synced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get synced;

  /// No description provided for @synopsis.
  ///
  /// In en, this message translates to:
  /// **'Synopsis'**
  String get synopsis;

  /// No description provided for @tagFields.
  ///
  /// In en, this message translates to:
  /// **'Tag Fields'**
  String get tagFields;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @tapAction.
  ///
  /// In en, this message translates to:
  /// **'Tap Action'**
  String get tapAction;

  /// No description provided for @tapToSeek.
  ///
  /// In en, this message translates to:
  /// **'Tap to seek'**
  String get tapToSeek;

  /// No description provided for @theFollowingChangesWereDetected.
  ///
  /// In en, this message translates to:
  /// **'The following changes were detected'**
  String get theFollowingChangesWereDetected;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @themeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// No description provided for @themeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// No description provided for @themeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeModeSystem;

  /// No description provided for @themeSettings.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeSettings;

  /// No description provided for @themeSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The overall vibe of your player'**
  String get themeSettingsSubtitle;

  /// No description provided for @thisPlaylistHasActiveSortersDisableThemBeforeReordering.
  ///
  /// In en, this message translates to:
  /// **'This playlist has active sorters, please disable them before reordering.'**
  String get thisPlaylistHasActiveSortersDisableThemBeforeReordering;

  /// No description provided for @thisVideoIsLikelyDeletedOrSetToPrivate.
  ///
  /// In en, this message translates to:
  /// **'This video is likely deleted or set to private.'**
  String get thisVideoIsLikelyDeletedOrSetToPrivate;

  /// No description provided for @thumbnails.
  ///
  /// In en, this message translates to:
  /// **'Thumbnails'**
  String get thumbnails;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @top.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get top;

  /// No description provided for @topComments.
  ///
  /// In en, this message translates to:
  /// **'Top comments'**
  String get topComments;

  /// No description provided for @topCommentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display comments at top instead of bottom'**
  String get topCommentsSubtitle;

  /// No description provided for @topRecentAlbums.
  ///
  /// In en, this message translates to:
  /// **'Top Recent Albums'**
  String get topRecentAlbums;

  /// No description provided for @topRecentArtists.
  ///
  /// In en, this message translates to:
  /// **'Top Recent Artists'**
  String get topRecentArtists;

  /// No description provided for @topRecents.
  ///
  /// In en, this message translates to:
  /// **'Top Recents'**
  String get topRecents;

  /// No description provided for @totalListenTime.
  ///
  /// In en, this message translates to:
  /// **'Total Listen Time'**
  String get totalListenTime;

  /// No description provided for @totalListens.
  ///
  /// In en, this message translates to:
  /// **'Total Listens'**
  String get totalListens;

  /// No description provided for @totalTracks.
  ///
  /// In en, this message translates to:
  /// **'Total Tracks'**
  String get totalTracks;

  /// No description provided for @totalTracksDuration.
  ///
  /// In en, this message translates to:
  /// **'Total Tracks Duration'**
  String get totalTracksDuration;

  /// No description provided for @track.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get track;

  /// No description provided for @trackArtistsSeparator.
  ///
  /// In en, this message translates to:
  /// **'Artists Separators'**
  String get trackArtistsSeparator;

  /// No description provided for @trackGenresSeparator.
  ///
  /// In en, this message translates to:
  /// **'Genres Separators'**
  String get trackGenresSeparator;

  /// No description provided for @trackInfo.
  ///
  /// In en, this message translates to:
  /// **'Track Info'**
  String get trackInfo;

  /// No description provided for @trackNotFound.
  ///
  /// In en, this message translates to:
  /// **'Track not found'**
  String get trackNotFound;

  /// No description provided for @trackNumber.
  ///
  /// In en, this message translates to:
  /// **'Track Number'**
  String get trackNumber;

  /// No description provided for @trackNumberTotal.
  ///
  /// In en, this message translates to:
  /// **'Track Total'**
  String get trackNumberTotal;

  /// No description provided for @trackPathOldNew.
  ///
  /// In en, this message translates to:
  /// **'Old name: \"{oldName}\"\n\nNew name: \"{newName}\"\n\nAre you sure?'**
  String trackPathOldNew({required String newName, required String oldName});

  /// No description provided for @trackPlayMode.
  ///
  /// In en, this message translates to:
  /// **'Play Mode'**
  String get trackPlayMode;

  /// No description provided for @trackPlayModeSearchResults.
  ///
  /// In en, this message translates to:
  /// **'Search Results'**
  String get trackPlayModeSearchResults;

  /// No description provided for @trackPlayModeSelectedOnly.
  ///
  /// In en, this message translates to:
  /// **'Selected track only'**
  String get trackPlayModeSelectedOnly;

  /// No description provided for @trackPlayModeTrackAlbum.
  ///
  /// In en, this message translates to:
  /// **'Track\'s Album'**
  String get trackPlayModeTrackAlbum;

  /// No description provided for @trackPlayModeTrackArtist.
  ///
  /// In en, this message translates to:
  /// **'Track\'s Main Artist'**
  String get trackPlayModeTrackArtist;

  /// No description provided for @trackPlayModeTrackGenre.
  ///
  /// In en, this message translates to:
  /// **'Track\'s Genre'**
  String get trackPlayModeTrackGenre;

  /// No description provided for @trackThumbnailSizeInList.
  ///
  /// In en, this message translates to:
  /// **'Size of Track Thumbnail'**
  String get trackThumbnailSizeInList;

  /// No description provided for @trackTileCustomization.
  ///
  /// In en, this message translates to:
  /// **'Track Tile Customization'**
  String get trackTileCustomization;

  /// No description provided for @trackTileItemsSeparator.
  ///
  /// In en, this message translates to:
  /// **'Items Separator'**
  String get trackTileItemsSeparator;

  /// No description provided for @tracks.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get tracks;

  /// No description provided for @tracksExcludedByNomedia.
  ///
  /// In en, this message translates to:
  /// **'Tracks Excluded by .nomedia'**
  String get tracksExcludedByNomedia;

  /// No description provided for @tracksInfo.
  ///
  /// In en, this message translates to:
  /// **'Tracks Info'**
  String get tracksInfo;

  /// No description provided for @underrated.
  ///
  /// In en, this message translates to:
  /// **'Underrated'**
  String get underrated;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @undoChanges.
  ///
  /// In en, this message translates to:
  /// **'Undo Changes?'**
  String get undoChanges;

  /// No description provided for @undoChangesDeletedPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Undo deleted playlist'**
  String get undoChangesDeletedPlaylist;

  /// No description provided for @undoChangesDeletedQueue.
  ///
  /// In en, this message translates to:
  /// **'Undo deleted Queue'**
  String get undoChangesDeletedQueue;

  /// No description provided for @undoChangesDeletedTrack.
  ///
  /// In en, this message translates to:
  /// **'Undo deleted track'**
  String get undoChangesDeletedTrack;

  /// No description provided for @uniqueArtworkHash.
  ///
  /// In en, this message translates to:
  /// **'Unique Artwork Hash'**
  String get uniqueArtworkHash;

  /// No description provided for @unlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimited;

  /// No description provided for @unlisted.
  ///
  /// In en, this message translates to:
  /// **'Unlisted'**
  String get unlisted;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @unsubscribe.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe'**
  String get unsubscribe;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @updateDirectoryPath.
  ///
  /// In en, this message translates to:
  /// **'Update directory path'**
  String get updateDirectoryPath;

  /// No description provided for @updateMissingTracksOnly.
  ///
  /// In en, this message translates to:
  /// **'Update missing tracks only'**
  String get updateMissingTracksOnly;

  /// No description provided for @updating.
  ///
  /// In en, this message translates to:
  /// **'Updating'**
  String get updating;

  /// No description provided for @useCollapsedSettingTiles.
  ///
  /// In en, this message translates to:
  /// **'Use Collapsed Setting Tiles'**
  String get useCollapsedSettingTiles;

  /// No description provided for @useMediaStore.
  ///
  /// In en, this message translates to:
  /// **'Use Media Store'**
  String get useMediaStore;

  /// No description provided for @useMediaStoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'✓ instant indexing time\nx respect .nomedia will be forcely enabled\nx some metadata tags will be missing\nx youtube integration for local library will not work'**
  String get useMediaStoreSubtitle;

  /// No description provided for @usePitchBlack.
  ///
  /// In en, this message translates to:
  /// **'Use Pitch Black'**
  String get usePitchBlack;

  /// No description provided for @usePitchBlackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Useful for AMOLED screens.. and looks cooler'**
  String get usePitchBlackSubtitle;

  /// No description provided for @used.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get used;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @valueBetween50200.
  ///
  /// In en, this message translates to:
  /// **'Value should be between 50% and 200%'**
  String get valueBetween50200;

  /// No description provided for @vibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get vibration;

  /// No description provided for @vibrationType.
  ///
  /// In en, this message translates to:
  /// **'Vibration type'**
  String get vibrationType;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @videoCache.
  ///
  /// In en, this message translates to:
  /// **'Video Cache'**
  String get videoCache;

  /// No description provided for @videoCacheFile.
  ///
  /// In en, this message translates to:
  /// **'Cached Video File'**
  String get videoCacheFile;

  /// No description provided for @videoCacheFiles.
  ///
  /// In en, this message translates to:
  /// **'Cached Video Files'**
  String get videoCacheFiles;

  /// No description provided for @videoOnly.
  ///
  /// In en, this message translates to:
  /// **'Video Only'**
  String get videoOnly;

  /// No description provided for @videoPlaybackSource.
  ///
  /// In en, this message translates to:
  /// **'Video Source'**
  String get videoPlaybackSource;

  /// No description provided for @videoPlaybackSourceAutoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This will give priority to local videos, if not found then it will fetch from youtube'**
  String get videoPlaybackSourceAutoSubtitle;

  /// No description provided for @videoPlaybackSourceLocal.
  ///
  /// In en, this message translates to:
  /// **'Local Videos'**
  String get videoPlaybackSourceLocal;

  /// No description provided for @videoPlaybackSourceLocalExampleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Alan Walker - Faded.m4a\nVideo Alan Walker - Faded (480p).mp4'**
  String get videoPlaybackSourceLocalExampleSubtitle;

  /// No description provided for @videoPlaybackSourceLocalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Checks if any video file (found inside the chosen folders list) has a filename that contains the filename of the track'**
  String get videoPlaybackSourceLocalSubtitle;

  /// No description provided for @videoPlaybackSourceYoutube.
  ///
  /// In en, this message translates to:
  /// **'From Youtube'**
  String get videoPlaybackSourceYoutube;

  /// No description provided for @videoPlaybackSourceYoutubeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Checks in track\'s filename & comment for any matching youtube link, videos are cached for later use.'**
  String get videoPlaybackSourceYoutubeSubtitle;

  /// No description provided for @videoQuality.
  ///
  /// In en, this message translates to:
  /// **'Video Quality'**
  String get videoQuality;

  /// No description provided for @videoQualitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Highest quality available will be picked.'**
  String get videoQualitySubtitle;

  /// No description provided for @videoQualitySubtitleNote.
  ///
  /// In en, this message translates to:
  /// **'It\'s always good to keep more alternatives in case a quality isn\'t found, otherwise it will fallback to the worst quality'**
  String get videoQualitySubtitleNote;

  /// No description provided for @videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videos;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'view'**
  String get view;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @views.
  ///
  /// In en, this message translates to:
  /// **'views'**
  String get views;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @waveformBarsCount.
  ///
  /// In en, this message translates to:
  /// **'Waveform Bars Count'**
  String get waveformBarsCount;

  /// No description provided for @webmNoEditTagsSupport.
  ///
  /// In en, this message translates to:
  /// **'WEBM format doesn\'t support tag editing'**
  String get webmNoEditTagsSupport;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @wiredDevice.
  ///
  /// In en, this message translates to:
  /// **'Wired Device'**
  String get wiredDevice;

  /// No description provided for @wirelessDevice.
  ///
  /// In en, this message translates to:
  /// **'Wireless Device'**
  String get wirelessDevice;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'yes'**
  String get yes;

  /// No description provided for @yourCurrentMembershipIs.
  ///
  /// In en, this message translates to:
  /// **'Your current membership is {name}'**
  String yourCurrentMembershipIs({required String name});

  /// No description provided for @yourCustomOrderWillBeLost.
  ///
  /// In en, this message translates to:
  /// **'Your custom order will be lost, Are you sure?'**
  String get yourCustomOrderWillBeLost;

  /// No description provided for @youtube.
  ///
  /// In en, this message translates to:
  /// **'Youtube'**
  String get youtube;

  /// No description provided for @youtubeMusic.
  ///
  /// In en, this message translates to:
  /// **'Youtube Music'**
  String get youtubeMusic;

  /// No description provided for @youtubeSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customize Youtube experience'**
  String get youtubeSettingsSubtitle;

  /// No description provided for @youtubeStyleMiniplayer.
  ///
  /// In en, this message translates to:
  /// **'Youtube-style Miniplayer'**
  String get youtubeStyleMiniplayer;

  /// No description provided for @ytPreferNewComments.
  ///
  /// In en, this message translates to:
  /// **'Prefer new comments when possible'**
  String get ytPreferNewComments;

  /// No description provided for @ytPreferNewCommentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Cached version will only be used when there is no connection'**
  String get ytPreferNewCommentsSubtitle;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'af',
    'ar',
    'bn',
    'bs',
    'de',
    'en',
    'eo',
    'es',
    'fa',
    'fi',
    'fr',
    'hi',
    'id',
    'it',
    'ja',
    'ko',
    'nl',
    'pl',
    'pt',
    'ro',
    'ru',
    'sl',
    'sr',
    'ta',
    'tr',
    'uk',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'es':
      {
        switch (locale.countryCode) {
          case 'CO':
            return AppLocalizationsEsCo();
        }
        break;
      }
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'af':
      return AppLocalizationsAf();
    case 'ar':
      return AppLocalizationsAr();
    case 'bn':
      return AppLocalizationsBn();
    case 'bs':
      return AppLocalizationsBs();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'eo':
      return AppLocalizationsEo();
    case 'es':
      return AppLocalizationsEs();
    case 'fa':
      return AppLocalizationsFa();
    case 'fi':
      return AppLocalizationsFi();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'nl':
      return AppLocalizationsNl();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ro':
      return AppLocalizationsRo();
    case 'ru':
      return AppLocalizationsRu();
    case 'sl':
      return AppLocalizationsSl();
    case 'sr':
      return AppLocalizationsSr();
    case 'ta':
      return AppLocalizationsTa();
    case 'tr':
      return AppLocalizationsTr();
    case 'uk':
      return AppLocalizationsUk();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
