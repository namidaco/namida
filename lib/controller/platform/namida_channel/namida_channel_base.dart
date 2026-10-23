part of 'namida_channel.dart';

abstract class NamidaChannel {
  static final NamidaChannel inst = NamidaChannel._platform();

  static NamidaChannel _platform() {
    return NamidaPlatformBuilder.init(
      android: _NamidaChannelAndroid._init,
      ios: _NamidaChannelIOS._init,
      windows: _NamidaChannelWindows._internal,
      linux: _NamidaChannelLinux._internal,
      macos: _NamidaChannelMacOS._init,
    );
  }

  static NamidaAppIcons get defaultAppIconForPlatform => NamidaPlatformBuilder.initValue(
    android: NamidaAppIcons.namida,
    ios: NamidaAppIcons.namida,
    windows: NamidaJellys.enabled ? NamidaAppIcons.jellyda : NamidaAppIcons.namida,
    linux: NamidaJellys.enabled ? NamidaAppIcons.jellyda : NamidaAppIcons.namida,
    macos: NamidaJellys.enabled ? NamidaAppIcons.jellyda : NamidaAppIcons.namida,
  );
  static const defaultLayerIconForPlatform = 'assets/namida.png';

  final isInPip = false.obs;

  Future<NamidaAppIcons?> getEnabledAppIcon() async {
    if (!supportsAppIcons) return null;
    NamidaAppIcons? newEnabledIcon;
    for (final e in NamidaAppIcons.values) {
      final enabled = await NamidaChannel.inst.isAppIconEnabled(e) ?? false;
      if (enabled) {
        newEnabledIcon = e;
        break;
      }
    }
    return newEnabledIcon;
  }

  bool get canOpenFileInExplorer;
  Future<void>? openFileInExplorer(String filePath, {bool isDirectory = false});

  bool get supportsAppIcons => false;
  Future<bool?> isAppIconEnabled(NamidaAppIcons type) async => false;

  Future<void> changeAppIcon(NamidaAppIcons type) async {}

  Future<void> updatePipRatio({int? width, int? height}) async {}

  Future<void> setCanEnterPip(bool canEnter) async {}

  /// an in-app snackbar where the system has no toasts.
  Future<void> showToast({required String message, required SnackDisplayDuration duration}) async {
    snackyy(message: message, displayDuration: duration);
  }

  Future<int> getPlatformSdk() async => 1;

  Future<bool> setMonoAudio(bool? enabled) async => false;

  Future<bool> setMusicAs({required String path, required List<SetMusicAsAction> types}) async => false;

  Future<bool> openSystemEqualizer(int? sessionId, {String? package}) async => false;

  Future<bool> openNamidaSync(String backupFolder, String musicFoldersJoined) async => false;

  Future<bool> openHomeWidgetSettings() async => false;

  final _multicastLockOwners = <MulticastLockOwner>{};

  /// android drops multicast packets unless a lock is held, it stays held while any owner needs it.
  void setMulticastLock(MulticastLockOwner owner, bool enabled) {
    final wasHeld = _multicastLockOwners.isNotEmpty;
    if (enabled) {
      _multicastLockOwners.add(owner);
    } else {
      _multicastLockOwners.remove(owner);
    }
    final isHeld = _multicastLockOwners.isNotEmpty;
    if (isHeld != wasHeld) _setMulticastLockNative(isHeld);
  }

  Future<void> _setMulticastLockNative(bool enabled) async {}

  Future<void> sendBroadcast(String action, Map<String, Object?> extras) async {}

  /// null [text] sends a stop. false when the SuperLyric module isn't active.
  Future<bool> sendSuperLyric({required String? title, required String? artist, required String? album, required String? text, required int startMS, required int endMS}) async =>
      false;

  Future<void> releaseSuperLyric() async {}

  /// lets android offer namida as a plugged usb dac's default app.
  Future<void> setUsbDacHandlerEnabled(bool enabled) async {}

  Future<bool> shareFiles(List<String> paths) async => false;

  /// files and links the system opened namida with, ex: "open in" or an oauth redirect. file urls arrive as paths.
  /// android & desktop get them through intents and launch args instead.
  Future<void> listenOpenedUrls(void Function(List<String> items) onItems) async {}

  /// ios resamples to the audio session rate, matching it to the source keeps the output bit-perfect.
  Future<void> setPreferredSampleRate(int sampleRate) async {}

  /// ios suspends the app shortly after leaving it unless audio plays, this asks for the time to finish ongoing work.
  /// sent again for every new batch the user starts, it renews what the system let expire.
  Future<void> setKeepRunningInBackground(bool keepRunning) async {}

  /// progress shown by ios for the work kept running by [setKeepRunningInBackground].
  Future<void> updateBackgroundWorkProgress({required int progress, required int totalProgress, required int itemsCount}) async {}

  Future<void> logPreviousAbnormalExits() async {}

  /// wether the media command (play, next, etc) that woke the app was sent by us (home widget/quick settings tile).
  /// external commands (bluetooth, system media resumption, etc) can be sent without user intention,
  /// so they shouldn't start playback on a cold start.
  Future<bool> consumeSelfSentMediaCommand() async => true;

  final _onResume = <FutureOr<void> Function()>[];
  final _onSuspending = <FutureOr<void> Function()>[];
  final _onDestroy = <FutureOr<void> Function()>[];

  void addOnDestroy(FutureOr<void> Function() fn) {
    _onDestroy.add(fn);
  }

  void addOnResume(FutureOr<void> Function() fn) {
    _onResume.add(fn);
  }

  void addOnSuspending(FutureOr<void> Function() fn) {
    _onSuspending.add(fn);
  }

  void removeOnDestroy(FutureOr<void> Function() fn) {
    _onDestroy.remove(fn);
  }

  void removeOnResume(FutureOr<void> Function() fn) {
    _onResume.remove(fn);
  }

  void removeOnSuspending(FutureOr<void> Function() fn) {
    _onSuspending.remove(fn);
  }
}

enum MulticastLockOwner {
  sync,
  partyHost,
  partyScan,
}

extension NamidaAppIconsUtils on NamidaAppIcons {
  bool get isJelly => this == NamidaAppIcons.jellyda;

  AuthorInfo get preferredAuthorInfo => authorInfos.first;

  String get authorInfoText {
    final info = preferredAuthorInfo;
    String finalText;
    String? username = info.username;
    if (username != null) {
      finalText = '@$username';
    } else {
      finalText = info.name;
    }
    final platform = info.platform?.name;
    if (platform != null) finalText += ' ($platform)';

    return finalText;
  }
}

// SPLASH_AUTO_GENERATED START
enum NamidaAppIcons {
  namida("assets/namida_icon.png", [AuthorInfo("شاكور", null, AuthorPlatform.discord, null), AuthorInfo("MSOB7YY", "MSOB7YY", AuthorPlatform.github, null)]),
  cutsie("assets/namida_icon_cutsie.webp", [AuthorInfo("smilez", null, AuthorPlatform.discord, AuthorAIModel.gpt4)]),
  jellyda("assets/namida_icon_jellyda.webp", [AuthorInfo("Tsuune", "tsuuneki", AuthorPlatform.discord, null), AuthorInfo("Tsuune", "TsunekiHouse", AuthorPlatform.telegram, null)]),
  eddy("assets/namida_icon_eddy.webp", [AuthorInfo(":𝟛𝓗𝓪𝓹𝓹𝔂", null, AuthorPlatform.discord, null)]),
  namichin("assets/namida_icon_namichin.webp", [AuthorInfo("Scarecloud", null, AuthorPlatform.discord, null)]),
  space("assets/namida_icon_space.webp", [AuthorInfo(":𝟛𝓗𝓪𝓹𝓹𝔂", null, AuthorPlatform.discord, null)]),
  retro("assets/namida_icon_retro.png", [AuthorInfo("sgfreak", null, AuthorPlatform.discord, null)]),
  ookami("assets/namida_icon_ookami.webp", [AuthorInfo("神 ᴛᴀᴋᴜᴍɪ", null, AuthorPlatform.discord, AuthorAIModel.unknown)]),
  original("assets/namida_icon_original.webp", [AuthorInfo("MSOB7YY", "MSOB7YY", AuthorPlatform.github, AuthorAIModel.midjourney)]),
  enhanced("assets/namida_icon_enhanced.webp", [AuthorInfo("im_mehu", null, AuthorPlatform.discord, null)]),
  hollow("assets/namida_icon_hollow.png", [AuthorInfo("wispy", null, AuthorPlatform.discord, null)]),
  pastel("assets/namida_icon_pastel.webp", [AuthorInfo("cui", null, AuthorPlatform.discord, AuthorAIModel.gemini)]),
  monet("assets/namida_icon_monet.png", [AuthorInfo("Sujal", null, AuthorPlatform.telegram, null)]),
  glowy("assets/namida_icon_glowy.webp", [AuthorInfo("Sujal", null, AuthorPlatform.telegram, null)]),
  spooky("assets/namida_icon_spooky.webp", [AuthorInfo("Miguquis", null, AuthorPlatform.discord, AuthorAIModel.gemini)]),
  namiween("assets/namida_icon_namiween.webp", [AuthorInfo("𐔌 . ⋮ Reggie .ᐟ ֹ ₊ ꒱", null, AuthorPlatform.discord, AuthorAIModel.unknown)]),
  tired("assets/namida_icon_tired.webp", [AuthorInfo("Zephyr", null, AuthorPlatform.discord, AuthorAIModel.unknown)]),
  ;

  final String assetPath;
  final List<AuthorInfo> authorInfos;
  const NamidaAppIcons(this.assetPath, this.authorInfos);
}

class AuthorInfo {
  final String name;
  final String? username;
  final AuthorPlatform? platform;
  final AuthorAIModel? aiModel;

  const AuthorInfo(this.name, this.username, this.platform, this.aiModel);
}

enum AuthorPlatform {
  github,
  telegram,
  discord,
}

enum AuthorAIModel {
  midjourney,
  gemini,
  gpt4,
  unknown,
}

// SPLASH_AUTO_GENERATED END
