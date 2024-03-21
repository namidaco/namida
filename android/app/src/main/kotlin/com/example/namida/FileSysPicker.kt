package com.msob7y.namida

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Parcelable
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.Serializable

object FileSysPicker {

  var pendingPickerResult: MethodChannel.Result? = null

  fun updatePendingResult(result: MethodChannel.Result?) {
    if (pendingPickerResult != null) {
      finishWithError(
          "Error selecting item",
          "Another request was recieved before finishing this one."
      )
    }
    pendingPickerResult = result
  }

  fun pickDirectory(result: MethodChannel.Result?, activity: Activity, requestCode: Int): String? {
    updatePendingResult(result)
    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
    return openPicker(intent, requestCode, activity)
  }

  fun pickFile(
      result: MethodChannel.Result?,
      activity: Activity,
      requestCode: Int,
      multiple: Boolean,
      extensions: List<String>?,
      type: String?
  ): String? {
    updatePendingResult(result)

    val intent: Intent

    if (type.equals("image/*")) {
      intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
    } else {
      intent = Intent(Intent.ACTION_GET_CONTENT)
      intent.addCategory(Intent.CATEGORY_OPENABLE)
    }
    val uri: Uri = Uri.parse(Environment.getExternalStorageDirectory().getPath() + File.separator)

    intent.setDataAndType(uri, type)
    intent.setType(type)
    intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
    intent.putExtra("multi-pick", multiple)

    var allowedMemetypes = ArrayList<String>()
    if (extensions != null && extensions.isNotEmpty()) {
      allowedMemetypes = getMimeTypes(extensions)
    } else if (type != null) {
      if (type.contains(",")) {
        for (t in type.split(",")) allowedMemetypes.add(t)
      } else {
        allowedMemetypes.add(type)
      }
    }

    if (allowedMemetypes.isNotEmpty()) {
      intent.putExtra(Intent.EXTRA_MIME_TYPES, allowedMemetypes)
    }

    return openPicker(intent, requestCode, activity)
  }

  private fun openPicker(intent: Intent, requestCode: Int, activity: Activity): String? {
    try {
      activity.startActivityForResult(intent, requestCode)
    } catch (notFound: ActivityNotFoundException) {
      return "No File Picker was found, Make sure you have a file explorer installed."
    } catch (e: Exception) {
      return e.message
    }
    return null
  }

  fun onPickerResult(data: Intent?, storageUtils: StorageUtils) {
    if (data == null) return
    storageUtils.fillStoragePaths() // for late mounts

    val files = mutableListOf<String>()

    try {
      val clipData: ClipData? = data.getClipData()
      if (clipData != null) {
        val count = clipData.getItemCount()
        var currentItem: Int = 0
        while (currentItem < count) {
          val contentUri: Uri? = clipData.getItemAt(currentItem).getUri()
          val contentUriPath = contentUri?.path
          val realPath = storageUtils.contentUriToPath(contentUri)
          if (realPath != null) {
            files.add(realPath)
          } else if (contentUriPath != null) {
            files.add(contentUriPath)
          }

          currentItem++
        }

        finishWithSuccess(files)
        return
      }
    } catch (_: Exception) {}

    val uri = data.getData()
    if (uri != null) {
      val uriPath = uri.path
      val filePath = storageUtils.contentUriToPath(uri)
      if (filePath != null) {
        files.add(filePath)
      } else if (uriPath != null) {
        files.add(uriPath)
      }
      if (files.isNotEmpty()) {
        finishWithSuccess(files)
      } else {
        finishWithError("unknown_path", "Failed to retrieve path.")
      }
    } else if (data.getExtras() != null) {
      val bundle: Bundle? = data.getExtras()
      if (bundle != null && bundle.keySet()?.contains("selectedItems") ?: false) {
        val fileUris = bundle.serializable<ArrayList<Parcelable>>("selectedItems")

        var currentItem = 0
        if (fileUris != null) {
          for (fileUri in fileUris) {
            if (fileUri is Uri) {
              val contentUri = fileUri.path
              val realPath = storageUtils.contentUriToPath(fileUri)
              if (realPath != null) {
                files.add(realPath)
              } else if (contentUri != null) {
                files.add(contentUri)
              }
            }

            currentItem++
          }
        }
        finishWithSuccess(files)
      } else {
        finishWithError("unknown_path", "Failed to retrieve path from bundle.")
      }
    } else {
      finishWithError("unknown_activity", "Unknown activity error, please fill an issue.")
    }
  }

  private fun getMimeTypes(allowedExtensions: List<String>?): ArrayList<String> {
    val mimes = ArrayList<String>()

    if (allowedExtensions == null || allowedExtensions.isEmpty()) {
      return mimes
    }

    for (extension in allowedExtensions) {
      val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
      if (mime == null) continue

      mimes.add(mime)
      if (extension.equals("csv")) mimes.add("text/csv")
    }
    return mimes
  }

  fun finishWithSuccess(data: MutableList<String>) {
    pendingPickerResult?.success(data)
    pendingPickerResult = null
  }

  fun finishWithError(errorCode: String, errorMessage: String) {
    pendingPickerResult?.error(errorCode, errorMessage, null)
    pendingPickerResult = null
  }
}

inline fun <reified T : Serializable> Bundle.serializable(key: String): T? =
    when {
      Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> getSerializable(key, T::class.java)
      else -> @Suppress("DEPRECATION") getSerializable(key) as? T
    }

inline fun <reified T : Serializable> Intent.serializable(key: String): T? =
    when {
      Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU ->
          getSerializableExtra(key, T::class.java)
      else -> @Suppress("DEPRECATION") getSerializableExtra(key) as? T
    }
