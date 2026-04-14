part of 'namida_channel.dart';

abstract class NamidaChannel {
  static final NamidaChannel inst = NamidaChannel._platform();

  static NamidaChannel _platform() {
    return NamidaPlatformBuilder.init(
      android: () => _NamidaChannelAndroid._init(),
      windows: () => _NamidaChannelWindows._internal(),
      linux: () => _NamidaChannelLinux._internal(),
    );
  }

  static final defaultAppIconForPlatform = NamidaPlatformBuilder.init(
    android: () => NamidaAppIcons.namida,
    windows: () => NamidaAppIcons.namida,
    linux: () => NamidaAppIcons.namida,
  );
  static final defaultLayerIconForPlatform = 'assets/namida.png';

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

  bool get supportsAppIcons;
  Future<bool?> isAppIconEnabled(NamidaAppIcons type);

  Future<void> changeAppIcon(NamidaAppIcons type);

  Future<void> updatePipRatio({int? width, int? height});

  Future<void> setCanEnterPip(bool canEnter);

  Future<void> showToast({required String message, required SnackDisplayDuration duration});

  Future<int> getPlatformSdk();

  Future<bool> setMonoAudio(bool? enabled);

  Future<bool> setMusicAs({required String path, required List<SetMusicAsAction> types});

  Future<bool> openSystemEqualizer(int? sessionId);

  Future<bool> openNamidaSync(String backupFolder, String musicFoldersJoined);

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

// SPLASH_AUTO_GENERATED START
enum NamidaAppIcons {
  namida("assets/namida_icon.png", [AuthorInfo("شاكور", null, AuthorPlatform.discord, null), AuthorInfo("MSOB7YY", "MSOB7YY", AuthorPlatform.github, null)]),
  cutsie("assets/namida_icon_cutsie.webp", [AuthorInfo("smilez", null, AuthorPlatform.discord, AuthorAIModel.gpt4)]),
  eddy("assets/namida_icon_eddy.webp", [AuthorInfo(":𝟛𝓗𝓪𝓹𝓹𝔂", null, AuthorPlatform.discord, null)]),
  namichin("assets/namida_icon_namichin.webp", [AuthorInfo("Scarecloud", null, AuthorPlatform.discord, null)]),
  space("assets/namida_icon_space.webp", [AuthorInfo(":𝟛𝓗𝓪𝓹𝓹𝔂", null, AuthorPlatform.discord, null)]),
  retro("assets/namida_icon_retro.png", [AuthorInfo("sgfreak", null, AuthorPlatform.discord, null)]),
  ookami("assets/namida_icon_ookami.webp", [AuthorInfo("神 ᴛᴀᴋᴜᴍɪ", null, AuthorPlatform.discord, AuthorAIModel.unknown)]),
  mini("assets/namida_icon_mini.png", [AuthorInfo("شاكور", null, AuthorPlatform.discord, null)]),
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
