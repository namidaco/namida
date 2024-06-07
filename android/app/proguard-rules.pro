-keep class com.google.android.exoplayer2.** { *; }

## Rules for NewPipeExtractor
-keep class org.schabi.newpipe.extractor.timeago.patterns.** { *; }
-keep class org.mozilla.javascript.** { *; }
-keep class org.mozilla.classfile.ClassFileWriter
-dontwarn org.mozilla.javascript.tools.**

-dontobfuscate

-keep class org.schabi.newpipe.extractor.** { *; }
-keep class org.ocpsoft.prettytime.i18n.** { *; }

# Rules for OkHttp. Copy paste from https://github.com/square/okhttp
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
# A resource is loaded with a relative path so the package of this class must be preserved.
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
}


-dontwarn android.arch.util.paging.CountedDataSource
-dontwarn android.arch.persistence.room.paging.LimitOffsetDataSource


-keep class com.artxdev.** { *; }
-keep class com.namidaco.** { *; }
-keep class org.jaudiotagger.** { *; }

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class androidx.lifecycle.DefaultLifecycleObserver


-keep class android.window.** { *; }

-dontwarn com.google.android.play.core.**
-dontwarn java.awt.**
-dontwarn javax.imageio.**
-dontwarn javax.swing.filechooser.FileFilter