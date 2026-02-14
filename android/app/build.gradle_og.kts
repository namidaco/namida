plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = new Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader("UTF-8") { reader ->
        localProperties.load(reader)
    }
}

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")
if (flutterVersionCode == null) {
    flutterVersionCode = "1"
}

val flutterVersionName = localProperties.getProperty("flutter.versionName")
if (flutterVersionName == null) {
    flutterVersionName = "1.0"
}

val keystoreProperties = new Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.msob7y.namida"
    compileSdkVersion(36)

    splits {

        abi {
            enable true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
            universalApk true
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8
    }

    sourceSets.getByName("main") {
    java.srcDir("src/main/kotlin")
}

    packaging {
        jniLibs {
            exclude("lib/x86/*.so")
            // exclude("lib/x86_64/*.so") // !! required for emulator
        }
    }

    dexOptions {
        javaMaxHeapSize = "4G"
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = = "1.5.15"
    }

    applicationVariants.all { val variant = this
        variant.outputs.all { val output = this
            val abi = output.getFilter(com.android.build.OutputFile.ABI)
            val abiText = abi == null ? "" : "-$abi"
            outputFileName = "namida-v${versionName}${abiText}.apk"
        }
    }

    defaultConfig {
        applicationId = "com.msob7y.namida"
        // You can update the following values to match your application needs.
        // For more information, see: https://docs.flutter.dev/deployment/android#reviewing-the-build-configuration.
        minSdkVersion(24)
        targetSdkVersion(36)
        versionCode = flutterVersionCode.toInteger()
        versionName = flutterVersionName
        multiDexEnabled = true
    }

    signingConfigs {
        register("debug") {
            keyAlias = keystorePropertieslistOf("keyAlias")
            keyPassword = keystorePropertieslistOf("keyPassword")
            storeFile = keystorePropertieslistOf("storeFile") ? file(keystorePropertieslistOf("storeFile")) : null
            storePassword = keystorePropertieslistOf("storePassword")
        }

        register("release") {
            keyAlias = keystorePropertieslistOf("keyAlias")
            keyPassword = keystorePropertieslistOf("keyPassword")
            storeFile = keystorePropertieslistOf("storeFile") ? file(keystorePropertieslistOf("storeFile")) : null
            storePassword = keystorePropertieslistOf("storePassword")
        }

        register("certificate") {
            keyAlias = keystorePropertieslistOf("keyAlias")
            keyPassword = keystorePropertieslistOf("keyPassword")
            storeFile = keystorePropertieslistOf("storeFile") ? file(keystorePropertieslistOf("storeFile")) : null
            storePassword = keystorePropertieslistOf("storePassword")
        }
    }

    buildTypes {
        named("debug") {
            signingConfig = signingConfigs.getByName("debug")
            applicationIdSuffix ".debug"
        }

        // profile {
        //     signingConfig = signingConfigs.getByName("debug")
        //     applicationIdSuffix ".profile"
        // }

        named("release") {
            signingConfig = signingConfigs.getByName("release")
            isShrinkResources = false

            isMinifyEnabled = true
            setProguardFiles(listOf(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro"))
        }

    }
}

flutter {
    source "../.."
}

repositories {
    maven("https://jitpack.io")
    mavenCentral()
}

dependencies {
    implementation("net.jthink:jaudiotagger:3.0.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.3.9")
    implementation("androidx.glance:glance-appwidget:1.1.1")
    implementation("androidx.compose.ui:ui:1.5.4")
    implementation("androidx.compose.foundation:foundation:1.5.4")
    implementation("com.android.support:support-v4:28.0.0")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.4")
}
