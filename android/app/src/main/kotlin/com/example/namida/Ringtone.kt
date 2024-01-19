package com.msob7y.namida

import android.content.ContentValues
import android.content.Context
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import java.io.File
import java.io.FileInputStream
import java.io.IOException

public class RingtoneController {

  public fun getCurrentlySet(context: Context, type: Int): String? {
    val defaultRingtoneUri = RingtoneManager.getActualDefaultRingtoneUri(context, type)
    return defaultRingtoneUri.path
  }

  public fun setAsRingtoneOrNotification(context: Context, k: File, type: Int): Exception? {
    try {
      val contentResolver = context.contentResolver
      val values =
          ContentValues().apply {
            put(MediaStore.MediaColumns.TITLE, k.name)
            put(MediaStore.MediaColumns.MIME_TYPE, "audio/mpeg")

            when (type) {
              RingtoneManager.TYPE_RINGTONE -> {
                put(MediaStore.Audio.Media.IS_RINGTONE, true)
                put(MediaStore.Audio.Media.IS_NOTIFICATION, false)
                put(MediaStore.Audio.Media.IS_ALARM, false)
              }
              RingtoneManager.TYPE_NOTIFICATION -> {
                put(MediaStore.Audio.Media.IS_RINGTONE, false)
                put(MediaStore.Audio.Media.IS_NOTIFICATION, true)
                put(MediaStore.Audio.Media.IS_ALARM, false)
              }
              RingtoneManager.TYPE_ALARM -> {
                put(MediaStore.Audio.Media.IS_RINGTONE, false)
                put(MediaStore.Audio.Media.IS_NOTIFICATION, false)
                put(MediaStore.Audio.Media.IS_ALARM, true)
              }
            }
          }

      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        val newUri: Uri? =
            contentResolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
        newUri?.let {
          try {
            contentResolver.openOutputStream(it)?.use { os ->
              FileInputStream(k).use { fileInputStream -> os.write(fileInputStream.readBytes()) }
            }
            RingtoneManager.setActualDefaultRingtoneUri(context, type, it)
            return null
          } catch (e: IOException) {
            return e
          } catch (e: Exception) {
            return e
          }
        }
      } else {
        values.put(MediaStore.MediaColumns.DATA, k.absolutePath)

        val uri: Uri? = MediaStore.Audio.Media.getContentUriForPath(k.absolutePath)
        if (uri == null) {
          return Exception(
              "uri is null for ${k.absolutePath} => MediaStore.Audio.Media.getContentUriForPath()"
          )
        }
        contentResolver.delete(uri, "${MediaStore.MediaColumns.DATA}=\"${k.absolutePath}\"", null)

        val newUri: Uri? = contentResolver.insert(uri, values)
        newUri?.let {
          RingtoneManager.setActualDefaultRingtoneUri(context, type, it)
          val finalUri: Uri? = MediaStore.Audio.Media.getContentUriForPath(k.absolutePath)
          if (finalUri == null) {
            return Exception(
                "finalUri is null for ${k.absolutePath} => MediaStore.Audio.Media.getContentUriForPath()"
            )
          }
          contentResolver.insert(finalUri, values)
          return null
        }
      }
      return null
    } catch (e: Exception) {
      return e
    }
  }
}
