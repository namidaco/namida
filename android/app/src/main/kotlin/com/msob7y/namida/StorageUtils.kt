package com.msob7y.namida

import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.storage.StorageManager
import android.os.storage.StorageVolume
import io.flutter.util.PathUtils
import java.io.File

public class StorageUtils(private val context: Context) {

  val storagePaths = mutableListOf<String>()

  fun contentUriToPath(contentUri: Uri?): String? {
    if (storagePaths.isEmpty()) fillStoragePaths()
    if (contentUri == null) return null
    return NamidaFileUtils.getRealPath(context, contentUri, storagePaths)
  }

  fun fillStoragePaths() {
    try {
      storagePaths.clear()
      for (folderPath in getStorageDirsData()) {
        storagePaths.add(folderPath.split("/Android/data/").first())
      }
    } catch (ignore: Exception) {}

    if (storagePaths.isEmpty()) {
      try {
        storagePaths.add(Environment.getExternalStoragePublicDirectory("").path)
      } catch (ignore: Exception) {}
    }

    // -- usb drives & car head units mount volumes that `getExternalFilesDirs` never lists
    try {
      val storageManager = context.getSystemService(Context.STORAGE_SERVICE) as StorageManager
      for (volume in storageManager.storageVolumes) {
        val path = volumeDirectory(volume) ?: continue
        if (!storagePaths.contains(path) && File(path).exists()) storagePaths.add(path)
      }
    } catch (ignore: Exception) {}
  }

  private fun volumeDirectory(volume: StorageVolume): String? {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) return volume.directory?.absolutePath
    return try {
      StorageVolume::class.java.getMethod("getPath").invoke(volume) as? String
    } catch (ignore: Exception) {
      null
    }
  }

  fun getStorageDirsData(): MutableList<String> {
    val folders = mutableListOf<String>()
    try {
      for (dir in context.getExternalFilesDirs(null)) {
        if (dir != null) folders.add(dir.getAbsolutePath())
      }
    } catch (ignore: Exception) {}

    if (folders.isEmpty()) {
      try {
        val dir = context.getExternalFilesDir(null)
        if (dir != null) folders.add(dir.getAbsolutePath())
      } catch (ignore: Exception) {}
    }

    // -- fallback to root app directory
    if (folders.isEmpty()) {
      try {
        val dataDirRoot = PathUtils.getFilesDir(context)
        folders.add(dataDirRoot)
      } catch (ignore: Exception) {}
    }

    return folders
  }

  fun getStorageDirsCache(): MutableList<String> {
    val folders = mutableListOf<String>()
    try {
      for (f in context.getExternalCacheDirs()) {
        folders.add(f.path)
      }
    } catch (ignore: Exception) {}

    if (folders.isEmpty()) {
      try {
        val dir = context.getExternalCacheDir()
        if (dir != null) folders.add(dir.getAbsolutePath())
      } catch (ignore: Exception) {}
    }

    // -- fallback to root app directory
    if (folders.isEmpty()) {
      try {
        val cacheDirRoot = PathUtils.getCacheDirectory(context)
        folders.add(cacheDirRoot)
      } catch (ignore: Exception) {}
    }

    return folders
  }
}
