package com.msob7y.namida

import android.content.Context
import android.net.Uri
import android.os.Environment
import io.flutter.util.PathUtils

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
