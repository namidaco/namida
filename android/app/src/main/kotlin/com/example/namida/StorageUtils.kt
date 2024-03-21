package com.msob7y.namida

import android.content.Context
import android.net.Uri
import android.os.Environment

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
      for (dir in context.getExternalFilesDirs(null)) {
        if (dir != null) {
          storagePaths.add(dir.getAbsolutePath().split("/Android/data/").first())
        }
      }
      if (storagePaths.isEmpty()) {
        storagePaths.add(Environment.getExternalStoragePublicDirectory("").path)
      }
    } catch (ignore: Exception) {}
  }

  fun getStorageDirsData(): MutableList<String> {
    val folders = mutableListOf<String>()
    for (dir in context.getExternalFilesDirs(null)) {
      if (dir != null) {
        folders.add(dir.getAbsolutePath())
      }
    }
    return folders
  }

  fun getStorageDirsCache(): MutableList<String> {
    val folders = mutableListOf<String>()
    for (f in context.getExternalCacheDirs()) {
      folders.add(f.path)
    }
    return folders
  }
}
