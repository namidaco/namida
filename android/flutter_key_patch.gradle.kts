// by claude
// -- patches flutter's android embedding jar until flutter#185849 is fixed (gboard select, soft keyboard ctrl keys, #1391). off: -PnamidaFlutterKeyPatch=false

import java.io.File
import java.net.URI
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.Properties
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream
import javax.tools.ToolProvider

val flutterKeyPatchSourcePath = "engine/src/flutter/shell/platform/android/io/flutter/embedding/android/KeyEmbedderResponder.java"
val flutterKeyPatchClassDir = "io/flutter/embedding/android"
val flutterKeyPatchClassName = "KeyEmbedderResponder"
val flutterKeyPatchModes = listOf("debug", "profile", "release")

val flutterKeyPatchEdits = listOf(
    """
    |  @NonNull private final HashMap<Long, TogglingGoal> togglingGoals = new HashMap<>();
    """.trimMargin() to """
    |  @NonNull private final HashMap<Long, TogglingGoal> togglingGoals = new HashMap<>();
    |  private final ArrayList<Runnable> releasesAfterReply = new ArrayList<>();
    """.trimMargin(),
    """
    |    boolean postEventAnyPressed = false;
    """.trimMargin() to """
    |    boolean postEventAnyPressed = false;
    |    boolean eventIsGoalKey = false;
    """.trimMargin(),
    """
    |      if (key.logicalKey == eventLogicalKey) {
    """.trimMargin() to """
    |      if (key.logicalKey == eventLogicalKey) {
    |        eventIsGoalKey = true;
    """.trimMargin(),
    """
    |    boolean isVirtualKeyboard =
    |        event.getDeviceId() == android.view.KeyCharacterMap.VIRTUAL_KEYBOARD;
    """.trimMargin() to """
    |    boolean isVirtualKeyboard =
    |        event.getDeviceId() == android.view.KeyCharacterMap.VIRTUAL_KEYBOARD;
    |    // -- namida: the modifier only applies to the event carrying it, see flutter#185849
    |    final boolean skipSynthesizing = isVirtualKeyboard && eventIsGoalKey;
    |    final boolean shouldReleaseAfterReply = isVirtualKeyboard && !eventIsGoalKey;
    """.trimMargin(),
    """
    |        if (postEventAnyPressed || isVirtualKeyboard) {
    |          preEventStates[keyIdx] = nowStates[keyIdx];
    |        } else {
    |          preEventStates[keyIdx] = true;
    |          postEventAnyPressed = true;
    |        }
    |      }
    |      if (!postEventAnyPressed && !isVirtualKeyboard) {
    """.trimMargin() to """
    |        if (postEventAnyPressed || skipSynthesizing) {
    |          preEventStates[keyIdx] = nowStates[keyIdx];
    |        } else {
    |          preEventStates[keyIdx] = true;
    |          postEventAnyPressed = true;
    |          if (shouldReleaseAfterReply) {
    |            final KeyboardMap.KeyPair key = goal.keys[keyIdx];
    |            releasesAfterReply.add(
    |                () -> synthesizeEvent(false, key.logicalKey, key.physicalKey, event.getEventTime()));
    |          }
    |        }
    |      }
    |      if (!postEventAnyPressed && !skipSynthesizing) {
    """.trimMargin(),
    """
    |    sendKeyEvent(output, onKeyEventHandledCallback);
    """.trimMargin() to """
    |    sendKeyEvent(output, withReleasesAfterReply(onKeyEventHandledCallback));
    """.trimMargin(),
    """
    |  private void sendKeyEvent(KeyData data, OnKeyEventHandledCallback onKeyEventHandledCallback) {
    """.trimMargin() to """
    |  // -- namida: a release sent with the event would reach the framework before it handles the event
    |  private OnKeyEventHandledCallback withReleasesAfterReply(OnKeyEventHandledCallback callback) {
    |    if (releasesAfterReply.isEmpty()) {
    |      return callback;
    |    }
    |    final ArrayList<Runnable> releases = new ArrayList<>(releasesAfterReply);
    |    releasesAfterReply.clear();
    |    return handled -> {
    |      for (final Runnable release : releases) {
    |        release.run();
    |      }
    |      callback.onKeyEventHandled(handled);
    |    };
    |  }
    |
    |  private void sendKeyEvent(KeyData data, OnKeyEventHandledCallback onKeyEventHandledCallback) {
    """.trimMargin(),
    """
    |      onKeyEventHandledCallback.onKeyEventHandled(true);
    """.trimMargin() to """
    |      withReleasesAfterReply(onKeyEventHandledCallback).onKeyEventHandled(true);
    """.trimMargin(),
)

// -- javac only needs the symbols, the real classes come with the app
val flutterKeyPatchAnnotationStubs = listOf("NonNull", "Nullable")

fun downloadFlutterKeyPatchFile(url: String, target: File) {
    target.parentFile.mkdirs()
    val partFile = File(target.path + ".part")
    URI(url).toURL().openStream().use { input -> partFile.outputStream().use { input.copyTo(it) } }
    Files.move(partFile.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING)
}

fun isFlutterKeyPatchClassEntry(entryName: String): Boolean {
    val classPrefix = "$flutterKeyPatchClassDir/$flutterKeyPatchClassName"
    return entryName == "$classPrefix.class" || entryName.startsWith("$classPrefix$")
}

fun applyFlutterKeyPatchEdits(sourceText: String, engineHash: String): String {
    var patchedText = sourceText.replace("\r\n", "\n")
    for ((original, patched) in flutterKeyPatchEdits) {
        val index = patchedText.indexOf(original)
        val isUnique = index != -1 && patchedText.indexOf(original, index + 1) == -1
        if (!isUnique) {
            throw GradleException("flutter key patch: $flutterKeyPatchClassName.java changed in flutter $engineHash, update the patch, drop it if flutter#185849 is fixed, or build with -PnamidaFlutterKeyPatch=false")
        }
        patchedText = patchedText.replaceRange(index, index + original.length, patched)
    }
    return patchedText
}

fun writeFlutterKeyPatchJar(officialJar: File, patchedClassFiles: List<File>, target: File) {
    val partFile = File(target.path + ".part")
    ZipFile(officialJar).use { zip ->
        ZipOutputStream(partFile.outputStream()).use { out ->
            for (entry in zip.entries()) {
                if (isFlutterKeyPatchClassEntry(entry.name)) continue
                out.putNextEntry(ZipEntry(entry.name))
                zip.getInputStream(entry).use { it.copyTo(out) }
                out.closeEntry()
            }
            for (classFile in patchedClassFiles) {
                out.putNextEntry(ZipEntry("$flutterKeyPatchClassDir/${classFile.name}"))
                classFile.inputStream().use { it.copyTo(out) }
                out.closeEntry()
            }
        }
    }
    Files.move(partFile.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING)
}

fun findAndroidJar(sdkDir: File): File {
    val platformDirs = File(sdkDir, "platforms").listFiles().orEmpty().filter { File(it, "android.jar").exists() }
    val latestPlatformDir = platformDirs.maxByOrNull { it.name.removePrefix("android-").substringBefore('.').toIntOrNull() ?: 0 }
    if (latestPlatformDir == null) throw GradleException("flutter key patch: no android.jar in $sdkDir/platforms")
    return File(latestPlatformDir, "android.jar")
}

fun prepareFlutterKeyPatchRepo(): File {
    val localProperties = Properties()
    rootProject.file("local.properties").inputStream().use { localProperties.load(it) }
    val flutterRoot = File(localProperties.getProperty("flutter.sdk"))
    val engineHash = File(flutterRoot, "bin/cache/engine.stamp").readText().trim()
    val version = "1.0.0-$engineHash"

    val patchId = flutterKeyPatchEdits.hashCode().toUInt().toString(16)
    val patchDir = rootProject.layout.buildDirectory.dir("flutter_key_patch/$patchId").get().asFile
    val repoDir = File(patchDir, "maven")

    fun getModuleDir(mode: String) = File(repoDir, "io/flutter/flutter_embedding_$mode/$version")
    fun getModuleBaseName(mode: String) = "flutter_embedding_$mode-$version"

    val missingModes = flutterKeyPatchModes.filter { !File(getModuleDir(it), "${getModuleBaseName(it)}.jar").exists() }
    if (missingModes.isEmpty()) return repoDir

    val stalePatchDirs = patchDir.parentFile.listFiles().orEmpty().filter { it != patchDir }
    for (stalePatchDir in stalePatchDirs) stalePatchDir.deleteRecursively()

    val engineRealm = File(flutterRoot, "bin/cache/engine.realm").takeIf { it.exists() }?.readText()?.trim().orEmpty()
    val engineRealmPrefix = if (engineRealm.isEmpty()) "" else "$engineRealm/"
    val storageBaseUrl = System.getenv("FLUTTER_STORAGE_BASE_URL") ?: "https://storage.googleapis.com"
    val mavenBaseUrl = "$storageBaseUrl/${engineRealmPrefix}download.flutter.io/io/flutter"

    val workDir = File(patchDir, "work")
    workDir.deleteRecursively()

    val officialJars = missingModes.associateWith { File(workDir, "${getModuleBaseName(it)}.jar") }
    for ((mode, officialJar) in officialJars) {
        downloadFlutterKeyPatchFile("$mavenBaseUrl/flutter_embedding_$mode/$version/${officialJar.name}", officialJar)
    }

    val localSourceFile = File(flutterRoot, flutterKeyPatchSourcePath)
    val rawSourceUrl = "https://raw.githubusercontent.com/flutter/flutter/$engineHash/$flutterKeyPatchSourcePath"
    val sourceText = if (localSourceFile.exists()) localSourceFile.readText() else URI(rawSourceUrl).toURL().readText()
    val patchedText = applyFlutterKeyPatchEdits(sourceText, engineHash)

    val sourceDir = File(workDir, "src")
    val sourceFile = File(sourceDir, "$flutterKeyPatchClassName.java")
    sourceDir.mkdirs()
    sourceFile.writeText(patchedText)
    val stubFiles = mutableListOf<File>()
    for (annotationName in flutterKeyPatchAnnotationStubs) {
        val stubFile = File(sourceDir, "$annotationName.java")
        stubFile.writeText("package androidx.annotation;\npublic @interface $annotationName {}\n")
        stubFiles.add(stubFile)
    }

    val sdkDirPath = localProperties.getProperty("sdk.dir") ?: System.getenv("ANDROID_HOME") ?: System.getenv("ANDROID_SDK_ROOT")
    if (sdkDirPath == null) throw GradleException("flutter key patch: android sdk not found, set sdk.dir in local.properties or ANDROID_HOME")
    val androidJar = findAndroidJar(File(sdkDirPath))
    val classpathJar = officialJars.values.first()
    val classpath = listOf(androidJar, classpathJar).joinToString(File.pathSeparator)

    val compiler = ToolProvider.getSystemJavaCompiler() ?: throw GradleException("flutter key patch: gradle has to run on a JDK to compile the patch")
    val classesDir = File(workDir, "classes")
    val compileArgs = listOf("--release", "8", "-Xlint:-options", "-nowarn", "-proc:none", "-classpath", classpath, "-d", classesDir.path, sourceFile.path) + stubFiles.map { it.path }
    val exitCode = compiler.run(null, null, null, *compileArgs.toTypedArray())
    if (exitCode != 0) throw GradleException("flutter key patch: compiling the patched $flutterKeyPatchClassName.java failed")

    val patchedClassFiles = File(classesDir, flutterKeyPatchClassDir).listFiles().orEmpty().filter { isFlutterKeyPatchClassEntry("$flutterKeyPatchClassDir/${it.name}") }

    for ((mode, officialJar) in officialJars) {
        val moduleDir = getModuleDir(mode)
        val baseName = getModuleBaseName(mode)
        downloadFlutterKeyPatchFile("$mavenBaseUrl/flutter_embedding_$mode/$version/$baseName.pom", File(moduleDir, "$baseName.pom"))
        writeFlutterKeyPatchJar(officialJar, patchedClassFiles, File(moduleDir, "$baseName.jar"))
    }
    workDir.deleteRecursively()
    logger.lifecycle("flutter key patch: patched flutter_embedding $version (${missingModes.joinToString()})")
    return repoDir
}

val isFlutterKeyPatchEnabled = providers.gradleProperty("namidaFlutterKeyPatch").orNull != "false"
if (isFlutterKeyPatchEnabled) {
    val flutterKeyPatchRepoDir = prepareFlutterKeyPatchRepo()
    allprojects {
        repositories {
            maven {
                url = flutterKeyPatchRepoDir.toURI()
                content {
                    includeModuleByRegex("io\\.flutter", "flutter_embedding_.*")
                }
            }
        }
    }
}
