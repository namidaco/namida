package com.msob7y.namida

import android.os.IBinder
import android.os.Parcel
import java.util.concurrent.Executors

/// Raw binder client of the SuperLyric xposed module (no aar). The module injects its service into
/// the app only while active, otherwise the lookup is null and nothing runs.
/// by claude
object SuperLyricPublisher {
  private const val SERVICE_NAME = "super_lyric"
  private const val DESCRIPTOR = "com.hchen.superlyricapi.ISuperLyricManager"
  private const val LINE_CLASS = "com.hchen.superlyricapi.SuperLyricLine"

  private const val TRANSACTION_REGISTER_PUBLISHER = IBinder.FIRST_CALL_TRANSACTION
  private const val TRANSACTION_UNREGISTER_PUBLISHER = IBinder.FIRST_CALL_TRANSACTION + 1
  private const val TRANSACTION_SEND_LYRIC = IBinder.FIRST_CALL_TRANSACTION + 3
  private const val TRANSACTION_SEND_STOP = IBinder.FIRST_CALL_TRANSACTION + 4

  private val service: IBinder? by lazy { lookupService() }
  private val executor by lazy { Executors.newSingleThreadExecutor() }

  // -- only touched on [executor]
  private var isRegistered = false

  /// [text] null sends a stop. returns false when the module is not active.
  fun send(title: String?, artist: String?, album: String?, text: String?, startMS: Long, endMS: Long): Boolean {
    val binder = service ?: return false
    executor.execute {
      if (!isRegistered) {
        isRegistered = transact(binder, TRANSACTION_REGISTER_PUBLISHER, null)
      }
      val code = if (text == null) TRANSACTION_SEND_STOP else TRANSACTION_SEND_LYRIC
      transact(binder, code) { data ->
        data.writeInt(1)
        data.writeString(title)
        data.writeString(artist)
        data.writeString(album)
        if (text == null) {
          data.writeString(null)
        } else {
          data.writeString(LINE_CLASS)
          data.writeString(text)
          data.writeInt(-1) // words
          data.writeLong(startMS)
          data.writeLong(endMS)
          data.writeLong(endMS - startMS) // delay
        }
        data.writeString(null) // secondary
        data.writeString(null) // translation
        data.writeString(null) // mediaMetadata
        data.writeString(null) // playbackState
        data.writeString(null) // base64Icon
        data.writeInt(-1) // extra
      }
    }
    return true
  }

  fun release() {
    val binder = service ?: return
    executor.execute {
      if (!isRegistered) return@execute
      transact(binder, TRANSACTION_UNREGISTER_PUBLISHER, null)
      isRegistered = false
    }
  }

  private fun transact(binder: IBinder, code: Int, write: ((Parcel) -> Unit)?): Boolean {
    val data = Parcel.obtain()
    val reply = Parcel.obtain()
    return try {
      data.writeInterfaceToken(DESCRIPTOR)
      write?.invoke(data)
      binder.transact(code, data, reply, 0)
      reply.readException()
      true
    } catch (_: Exception) {
      false
    } finally {
      data.recycle()
      reply.recycle()
    }
  }

  private fun lookupService(): IBinder? {
    return try {
      val serviceManager = Class.forName("android.os.ServiceManager")
      serviceManager.getMethod("getService", String::class.java).invoke(null, SERVICE_NAME) as IBinder?
    } catch (_: Exception) {
      null
    }
  }
}
