// ignore_for_file: public_member_api_docs, sort_constructors_first, constant_identifier_names, unused_element
import 'dart:io';

import 'package:path/path.dart' as p;

class _FilePaths {
  static const project_root = r'.';
  static const android_res = '$project_root/android/app/src/main/res';
  // ignore: unused_field
  static const launch_background = '$project_root/android/app/src/main/res/drawable/launch_background.xml';
  static const android_manifest = '$project_root/android/app/src/main/AndroidManifest.xml';
  static const main_activity_kt = '$project_root/android/app/src/main/kotlin/com/msob7y/namida/NamidaMainActivity.kt';
  static const launcher_icon_controller_kt = '$project_root/android/app/src/main/kotlin/com/msob7y/namida/LauncherIconController.kt';
  static const namida_channel_base_dart = '$project_root/lib/controller/platform/namida_channel/namida_channel_base.dart';
}

/// Generates code for multiple icons in dart/kotlin/AndroidManifest
void main() async {
  for (final icon in _appIcons) {
    final configName = icon.dartName;
    // if (icon == _IconDetails.defaultIcon) {
    //   await Process.run(
    //     'dart',
    //     [
    //       'run',
    //       'flutter_native_splash:create',
    //       '--path=scripts/splash_configs/splash_$configName.yaml',
    //     ],
    //     runInShell: true,
    //   );
    // }

    _renameAndroidFiles(configName);

    _replaceInKotlin();
    _replaceInManifest();
    _replaceInDart();
  }
}

void _renameAndroidFiles(String suffix) {
  // final parentDir = _FilePaths.android_res;
  // File getFile(Iterable<String> parts) => File(p.joinAll([parentDir, ...parts]));
  // _renameFile(getFile(['drawable', 'background.png']), 'background_$suffix.png');
  // _renameAllInSubFolderInRes('mipmap', 'ic_launcher', suffix, extValidator: (ext) => ext == '.png', exactName: true);

  // -- seems like we cant have multiple splash icon and bg.. rip
  // _renameAllInSubFolderInRes('drawable', 'background', suffix);
  // _renameAllInSubFolderInRes('drawable', 'splash', suffix);
  // _replaceAllInFile(
  //   _FilePaths.launch_background,
  //   (content) => content
  //       .replaceAll('@drawable/background', '@drawable/background_$suffix') //
  //       .replaceAll('@drawable/splash', '@drawable/splash_$suffix'),
  // );
}

void _replaceInDart() {
  final prefixComment = '// $_kPrefixComment';
  final suffixComment = '// $_kSuffixComment';
  final iconsEnum = _appIcons.map((e) {
    final authorInfo = e.authorInfos.map((e) => e.toClassString()).join(', ');
    return '\t${e.dartName}("${e.assetPath}", [$authorInfo]),';
  }).join('\n');
  _replaceAllInFile(
    _FilePaths.namida_channel_base_dart,
    (content) => content.replaceFirst(
      RegExp('$prefixComment([\\s\\S]*?)$suffixComment', multiLine: true),
      '''$prefixComment
enum NamidaAppIcons {
$iconsEnum
\t;

\tfinal String assetPath;
\tfinal List<AuthorInfo> authorInfos;
\tconst NamidaAppIcons(this.assetPath, this.authorInfos);
}

class AuthorInfo {
\tfinal String name;
\tfinal String? username;
\tfinal AuthorPlatform? platform;
\tfinal AuthorAIModel? aiModel;

\tconst AuthorInfo(this.name, this.username, this.platform, this.aiModel);
}

enum AuthorPlatform {
${_AuthorPlatform.values.map((e) => '\t${e.name},').join('\n')}
}

enum AuthorAIModel {
${_AuthorAIModel.values.map((e) => '\t${e.name},').join('\n')}
}

$suffixComment''',
    ),
  );
}

void _replaceInManifest() {
  final prefixComment = '<!-- $_kPrefixComment -->';
  final suffixComment = '<!-- $_kSuffixComment -->';
  const indent = '\t\t';

  final String manifestCode = _appIcons
      .map(
        (icon) => '''<activity-alias
            android:enabled="${icon == _appIcons[0] ? true : false}"
            android:name="com.msob7y.namida.${icon.manifestName}"
            android:targetActivity=".NamidaMainActivity"
            android:icon="@mipmap/${icon.mipmapName}"
            android:roundIcon="@mipmap/${icon.mipmapName}"
            android:exported="true">

            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
                <category android:name="android.intent.category.MULTIWINDOW_LAUNCHER" />
            </intent-filter>
        </activity-alias>''',
      )
      .join('\n\n$indent');

  _replaceAllInFile(
    _FilePaths.android_manifest,
    (content) => content.replaceFirst(
      RegExp('$prefixComment([\\s\\S]*?)$suffixComment', multiLine: true),
      '$prefixComment\n$indent$manifestCode\n$indent$suffixComment',
    ),
  );
}

void _replaceInKotlin() {
  final prefixComment = '// $_kPrefixComment';
  final suffixComment = '// $_kSuffixComment';
  const indent = '\t\t\t\t';
  final iconsMatches = _appIcons.map((e) => '$indent\t\t"${e.dartName}" -> LauncherIcon.${e.kotlinName}').join('\n');
  final kotlinCode = '''"changeAppIcon" -> {
          val key = call.argument<String>("key")
          val nativeIcon = when (key) {
$iconsMatches
            else -> null
          }

          if (nativeIcon != null) {
              LauncherIconController.setIcon(nativeIcon)
              result.success(true)
          } else {
              result.error("INVALID_ICON", "No matching icon for key: \$key", null)
          }
        }''';
  final kotlinCode2 = '''"isAppIconEnabled" -> {
          val key = call.argument<String>("key")
          val nativeIcon = when (key) {
$iconsMatches
            else -> null
          }

          if (nativeIcon != null) {
              val enabled = LauncherIconController.isEnabled(nativeIcon)
              result.success(enabled)
          } else {
              result.error("INVALID_ICON", "No matching icon for key: \$key", null)
          }
        }''';
  _replaceAllInFile(
    _FilePaths.main_activity_kt,
    (content) => content.replaceFirst(
      RegExp('$prefixComment([\\s\\S]*?)$suffixComment', multiLine: true),
      '$prefixComment\n$indent$kotlinCode\n$indent$kotlinCode2\n$indent$suffixComment',
    ),
  );

  final iconsConstructor = _appIcons.mapIndexed((e, i) {
    final trailing = i == _appIcons.length - 1 ? ';' : ',';
    return '\t${e.kotlinName}("${e.manifestName}", R.mipmap.${e.mipmapName})$trailing';
  }).join('\n');

  _replaceAllInFile(
    _FilePaths.launcher_icon_controller_kt,
    (content) => content.replaceFirst(
      RegExp('$prefixComment([\\s\\S]*?)$suffixComment', multiLine: true),
      '''$prefixComment
enum class LauncherIcon(
    val key: String,
    val foreground: Int
) {
$iconsConstructor

    private var componentName: ComponentName? = null

    fun getComponentName(ctx: Context): ComponentName {
        if (componentName == null) {
            componentName = ComponentName(ctx.packageName, "com.msob7y.namida.\$key")
        }
        return componentName!!
    }
}
$suffixComment''',
    ),
  );
}

void _replaceAllInFile(String filePath, String Function(String content) newContent) {
  final f = File(filePath);
  final content = f.readAsStringSync();
  f.writeAsStringSync(newContent(content));
}

void _renameAllInSubFolderInRes(String subdirPrefix, String filenamePrefix, String suffix, {bool exactName = false, bool Function(String ext)? extValidator}) {
  final parentDir = _FilePaths.android_res;
  for (final e in Directory(parentDir).listSync()) {
    if (e is Directory) {
      if (p.basename(e.path).startsWith(subdirPrefix)) {
        for (final f in e.listSync()) {
          if (f is File) {
            final goodName = exactName ? p.basenameWithoutExtension(f.path) == filenamePrefix : p.basename(f.path).startsWith(filenamePrefix);
            if (goodName) {
              if (extValidator == null || extValidator(p.extension(f.path))) {
                _renameFileAdv(
                  f,
                  (old) => old.replaceFirst(filenamePrefix, '${filenamePrefix}_$suffix'),
                );
              }
            }
          }
        }
      }
    }
  }
}

File _renameFile(File file, String newFileName) {
  var path = file.path;
  var lastSeparator = path.lastIndexOf(Platform.pathSeparator);
  var newPath = path.substring(0, lastSeparator + 1) + newFileName;
  return file.renameSync(newPath);
}

File _renameFileAdv(File file, String Function(String old) newFileNameBuilder) {
  var path = file.path;
  var lastSeparator = path.lastIndexOf(Platform.pathSeparator);
  var oldName = path.substring(lastSeparator + 1, null);
  var newPath = path.substring(0, lastSeparator + 1) + newFileNameBuilder(oldName);
  return file.renameSync(newPath);
}

const _kPrefixComment = 'SPLASH_AUTO_GENERATED START';
const _kSuffixComment = 'SPLASH_AUTO_GENERATED END';

final _appIcons = [
  _IconDetails.defaultIcon,
  _IconDetails.create(
    'enhanced',
    ext: _ImgExtension.webp,
    authorInfos: [
      _AuthorInfo('im_mehu', null, _AuthorPlatform.discord, null),
    ],
  ),
  _IconDetails.create(
    'hollow',
    ext: _ImgExtension.png,
    authorInfos: [
      _AuthorInfo('wispy', null, _AuthorPlatform.discord, null),
    ],
  ),
  _IconDetails.create(
    'monet',
    ext: _ImgExtension.png,
    authorInfos: [
      _AuthorInfo('Sujal', null, _AuthorPlatform.telegram, null),
    ],
  ),
  _IconDetails.create(
    'glowy',
    ext: _ImgExtension.webp,
    authorInfos: [
      _AuthorInfo('Sujal', null, _AuthorPlatform.telegram, null),
    ],
  ),
  _IconDetails.create(
    'shade',
    ext: _ImgExtension.png,
    authorInfos: [
      _AuthorInfo('شاكور', null, _AuthorPlatform.discord, null),
    ],
  ),
  _IconDetails.create(
    'mini',
    ext: _ImgExtension.png,
    authorInfos: [
      _AuthorInfo('شاكور', null, _AuthorPlatform.discord, null),
    ],
  ),
  _IconDetails.create(
    'spooky',
    ext: _ImgExtension.webp,
    authorInfos: [
      _AuthorInfo('Miguquis', null, _AuthorPlatform.discord, _AuthorAIModel.gemini),
    ],
  ),
  _IconDetails.create(
    'namiween',
    ext: _ImgExtension.webp,
    authorInfos: [
      _AuthorInfo('𐔌 . ⋮ Reggie .ᐟ ֹ ₊ ꒱', null, _AuthorPlatform.discord, _AuthorAIModel.unknown),
    ],
  ),
  _IconDetails.create(
    'space',
    ext: _ImgExtension.webp,
    authorInfos: [
      _AuthorInfo(':𝟛𝓗𝓪𝓹𝓹𝔂', null, _AuthorPlatform.discord, null),
    ],
  ),
  _IconDetails.create(
    'tired',
    ext: _ImgExtension.webp,
    authorInfos: [
      _AuthorInfo('Zephyr', null, _AuthorPlatform.discord, _AuthorAIModel.unknown),
    ],
  ),
  _IconDetails.create(
    'eddy',
    ext: _ImgExtension.webp,
    authorInfos: [
      _AuthorInfo(':𝟛𝓗𝓪𝓹𝓹𝔂', null, _AuthorPlatform.discord, null),
    ],
  ),
  _IconDetails.create(
    'namichin',
    ext: _ImgExtension.webp,
    authorInfos: [
      _AuthorInfo('Scarecloud', null, _AuthorPlatform.discord, null),
    ],
  ),
  _IconDetails.create(
    'cutsie',
    ext: _ImgExtension.webp,
    authorInfos: [
      _AuthorInfo('smilez', null, _AuthorPlatform.discord, _AuthorAIModel.gpt4),
    ],
  ),
];

class _IconDetails {
  final String kotlinName, manifestName, mipmapName, dartName, assetPath;
  final List<_AuthorInfo> authorInfos;
  const _IconDetails({
    required this.kotlinName,
    required this.manifestName,
    required this.mipmapName,
    required this.dartName,
    required this.assetPath,
    required this.authorInfos,
  });

  static String _capitalizeFirst(String word) {
    if (word.length > 1) {
      try {
        return "${word[0].toUpperCase()}${word.substring(1)}";
      } catch (_) {}
    }
    return word;
  }

  static const defaultIcon = _IconDetails(
    kotlinName: 'DEFAULT',
    manifestName: 'DefaultIcon',
    mipmapName: 'ic_launcher',
    dartName: 'namida',
    assetPath: 'assets/namida_icon.webp',
    authorInfos: [
      _AuthorInfo(
        'MSOB7YY',
        'MSOB7YY',
        _AuthorPlatform.github,
        _AuthorAIModel.midjourney,
      ),
    ],
  );

  factory _IconDetails.create(String mainName, {required List<_AuthorInfo> authorInfos, required _ImgExtension ext}) {
    final upperCase = mainName.toUpperCase();
    final lowercase = mainName.toLowerCase();
    final camelcase = _capitalizeFirst(mainName);
    final extName = ext.name;

    return _IconDetails(
      kotlinName: upperCase,
      manifestName: '${camelcase}Icon',
      mipmapName: 'ic_launcher_$lowercase',
      dartName: mainName.toLowerCase(),
      assetPath: 'assets/namida_icon_$lowercase.$extName',
      authorInfos: authorInfos,
    );
  }
}

enum _ImgExtension {
  webp,
  png,
}

extension _IterablieListieUtils<E> on List<E> {
  Iterable<T> mapIndexed<T>(T Function(E e, int index) toElement) sync* {
    final length = this.length;
    for (int i = 0; i < length; i++) {
      yield toElement(this[i], i);
    }
  }
}

class _AuthorInfo {
  final String name;
  final String? username;
  final _AuthorPlatform? platform;
  final _AuthorAIModel? aiModel;

  const _AuthorInfo(this.name, this.username, this.platform, this.aiModel);

  String toClassString() {
    final nameText = '"$name"';
    final usernameText = username == null ? null : '"$username"';
    final platformText = platform == null ? null : 'AuthorPlatform.${platform!.name}';
    final aiModelText = aiModel == null ? null : 'AuthorAIModel.${aiModel!.name}';
    return 'AuthorInfo($nameText, $usernameText, $platformText, $aiModelText)';
  }
}

enum _AuthorPlatform {
  github,
  telegram,
  discord,
}

enum _AuthorAIModel {
  midjourney,
  gemini,
  gpt4,

  /// uses an ai model but not known
  unknown,
}
