package com.msob7y.namida

import android.annotation.SuppressLint
import android.content.ContentUris
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.text.TextUtils
import java.io.File

object NamidaFileUtils {

  /**
   * Get a file path from a Uri. This will get the the path for Storage Access Framework Documents,
   * as well as the _data field for the MediaStore and other file-based ContentProviders. API >= 19
   * only
   *
   * @param context The context.
   * @param uri The Uri to query.
   * @author Niks
   */
  @SuppressLint("NewApi")
  fun getRealPath(context: Context, uri: Uri, storagePaths: List<String>): String? {
    var real = getRealPathFromURIAPI19(context, uri, storagePaths)
    if (real == null){
        real = extractRealPathFromFileProvider(context, uri, storagePaths)
    }
    return real
  }

  fun getRealPathFromURIAPI19(context: Context, uri: Uri, storagePaths: List<String>): String? {
    val isKitKat = Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT
    try {
      // DocumentProvider
      if (isKitKat &&
              (DocumentsContract.isDocumentUri(context, uri) || isExternalStorageDocument(uri))
      ) {
        // ExternalStorageProvider
        if (storagePaths.isNotEmpty() && isExternalStorageDocument(uri)) {
          // val docId = DocumentsContract.getDocumentId(uri)
          val uriPath = uri.path
          if (uriPath == null) return null
          val split = uriPath.split(":".toRegex()).dropLastWhile { it.isEmpty() }.toTypedArray()
          val rootDir = split[0].split("/tree/").last() // for directories
          fun buildPath(rootPath: String): String {
            return rootPath + "/" + split[1]
          }
          // -- this only to handle when same file path exists in 2 storages
          // -- we check manually if primary storage selected
          if (storagePaths.size >= 2) {
            if ("primary".equals(rootDir, ignoreCase = true) &&
                    File(buildPath(storagePaths[0])).exists()
            ) {
              return buildPath(storagePaths[0])
            } else if (File(buildPath(storagePaths[1])).exists()) {
              return buildPath(storagePaths[1])
            }
          }

          for (sp in storagePaths) {
            val path = buildPath(sp)
            if (File(path).exists()) return path
          }
        } else if (isDownloadsDocument(uri)) {
          var cursor: Cursor? = null
          try {
            cursor =
                context.contentResolver.query(
                    uri,
                    arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
                    null,
                    null,
                    null
                )
            cursor!!.moveToNext()
            val fileName = cursor.getString(0)
            val path =
                Environment.getExternalStorageDirectory().toString() + "/Download/" + fileName
            if (!TextUtils.isEmpty(path)) {
              return path
            }
          } finally {
            cursor?.close()
          }
          val id = DocumentsContract.getDocumentId(uri)
          if (id.startsWith("raw:")) {
            return id.replaceFirst("raw:".toRegex(), "")
          }
          val contentUri =
              ContentUris.withAppendedId(
                  Uri.parse("content://downloads"),
                  java.lang.Long.valueOf(id)
              )

          return getDataColumn(context, contentUri, null, null)
        } else if (isMediaDocument(uri)) {
          val docId = DocumentsContract.getDocumentId(uri)
          val split = docId.split(":".toRegex()).dropLastWhile { it.isEmpty() }.toTypedArray()
          val type = split[0]

          val contentUri: Uri =
              when (type) {
                "image" -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                "video" -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                "audio" -> MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                "downloads" -> MediaStore.Downloads.EXTERNAL_CONTENT_URI
                else -> MediaStore.Files.getContentUri("external")
              }

          val selection = "_id=?"
          val selectionArgs = arrayOf(split[1])

          return getDataColumn(context, contentUri, selection, selectionArgs)
        } // MediaProvider
        // DownloadsProvider
      } else if ("content".equals(uri.scheme!!, ignoreCase = true)) {

        // Return the remote address
        return if (isGooglePhotosUri(uri)) uri.lastPathSegment
        else getDataColumn(context, uri, null, null)
      } else if ("file".equals(uri.scheme!!, ignoreCase = true)) {
        return uri.path
      } // File
      // MediaStore (and general)
    } catch (ignore: Exception) {
      return null
    }
    return null
  }

  fun extractRealPathFromFileProvider(context: Context, uri: Uri, storagePaths: List<String>): String? {
      // for: content://com.etc.launcher.release.fileprovider/external_files/Music/...
      if (uri.authority?.contains("fileprovider") == true) {
          val pathSegments = uri.pathSegments
          // Skip the first segment (e.g., "external_files")
          if (pathSegments.size > 1) {
              val relativePath = pathSegments.drop(1).joinToString("/")
              val decodedPath = Uri.decode(relativePath)
              val primaryPath = "${Environment.getExternalStorageDirectory()}/$decodedPath"
              if (File(primaryPath).exists()) {
                  return primaryPath
              }

              val firstSegment = decodedPath.substringBefore('/')
              val sdCardPattern = Regex("^[0-9A-F]{4}-[0-9A-F]{4}$")
              if (sdCardPattern.matches(firstSegment)) {
                  // Path already contains SD card ID, use it directly
                  val fullSdPath = "/storage/$decodedPath"
                  if (File(fullSdPath).exists()) {
                      return fullSdPath
                  }
              }

              // fallback to SD card and other external storage volumes
              if (storagePaths.isNotEmpty()) {
                  for (storagePath in storagePaths) {
                      val fullPath = "$storagePath/$decodedPath"
                      if (File(fullPath).exists()) {
                          return fullPath
                      }
                  }
              } else {
                  val externalDirs = context.getExternalFilesDirs(null)
                  externalDirs?.forEach { dir ->
                      if (dir != null) {
                          // Extract the storage root from the external files dir
                          // e.g., /storage/XXXX-XXXX/Android/data/... -> /storage/XXXX-XXXX/
                          val storagePath = extractStorageRoot(dir.absolutePath)
                          if (storagePath != null) {
                              val sdcardPath = "$storagePath/$decodedPath"
                              if (File(sdcardPath).exists()) {
                                  return sdcardPath
                              }
                          }
                      }
                  }
              }
              return primaryPath
          }
      }
      return null
  }

  private fun extractStorageRoot(path: String): String? {
      // Convert /storage/XXXX-XXXX/Android/data/... to /storage/XXXX-XXXX/
      val storagePath = path.substringBefore("/Android/data")
      return if (storagePath != path && storagePath.startsWith("/storage/")) {
          storagePath
      } else {
          null
      }
  }


  /**
   * Get the value of the data column for this Uri. This is useful for MediaStore Uris, and other
   * file-based ContentProviders.
   *
   * @param context The context.
   * @param uri The Uri to query.
   * @param selection (Optional) Filter used in the query.
   * @param selectionArgs (Optional) Selection arguments used in the query.
   * @return The value of the _data column, which is typically a file path.
   * @author Niks
   */
  private fun getDataColumn(
      context: Context,
      uri: Uri?,
      selection: String?,
      selectionArgs: Array<String>?
  ): String? {

    var cursor: Cursor? = null
    val column = "_data"
    val projection = arrayOf(column)

    try {
      cursor = context.contentResolver.query(uri!!, projection, selection, selectionArgs, null)
      if (cursor != null && cursor.moveToFirst()) {
        val index = cursor.getColumnIndexOrThrow(column)
        return cursor.getString(index)
      }
    } finally {
      cursor?.close()
    }
    return null
  }

  /**
   * @param uri The Uri to check.
   * @return Whether the Uri authority is ExternalStorageProvider.
   */
  private fun isExternalStorageDocument(uri: Uri): Boolean {
    return "com.android.externalstorage.documents" == uri.authority
  }

  /**
   * @param uri The Uri to check.
   * @return Whether the Uri authority is DownloadsProvider.
   */
  private fun isDownloadsDocument(uri: Uri): Boolean {
    return "com.android.providers.downloads.documents" == uri.authority
  }

  /**
   * @param uri The Uri to check.
   * @return Whether the Uri authority is MediaProvider.
   */
  private fun isMediaDocument(uri: Uri): Boolean {
    return "com.android.providers.media.documents" == uri.authority
  }

  /**
   * @param uri The Uri to check.
   * @return Whether the Uri authority is Google Photos.
   */
  private fun isGooglePhotosUri(uri: Uri): Boolean {
    return "com.google.android.apps.photos.content" == uri.authority
  }
}
