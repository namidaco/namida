package com.msob7y.namida

import android.app.PictureInPictureParams
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.media.RingtoneManager
import android.media.audiofx.AudioEffect
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Rational
import android.widget.Toast
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class NamidaMainActivity : FlutterActivity() {
  private val CHANNELNAME = "namida"
  private val EVENTCHANNELNAME = "namida_events"
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var toast: Toast? = null

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    flutterEngine.plugins.add(FAudioTagger())

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      pipBuilder = PictureInPictureParams.Builder()
    }

    // GeneratedPluginRegistrant.registerWith(flutterEngine)
    val messenger = flutterEngine.dartExecutor.binaryMessenger
    channel = MethodChannel(messenger, CHANNELNAME)

    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "sdk" -> result.success(Build.VERSION.SDK_INT)
        "showToast" -> {
          try {
            val durInSeconds = call.argument<Number?>("seconds")
            val duration = durInSeconds?.toInt() ?: 1
            val text = call.argument<String?>("text")
            showToast(text, duration)
            result.success(true)
          } catch (e: Exception) {
            result.error("NAMIDA TOAST", "Error showing toast", e)
            println(e)
          }
        }
        "cancelToast" -> {
          cancelToast()
          result.success(true)
        }
        "setCanEnterPip" -> {
          val canEnter = call.argument<Boolean?>("canEnter")
          if (canEnter != null) canEnterPip = canEnter
          result.success(null)
        }
        "updatePipRatio" -> {
          if (isInPip()) {
            updatePipRatio(call.argument<Int?>("width"), call.argument<Int?>("height"))
            result.success(true)
          } else {
            result.success(false)
          }
        }
        "setMusicAs" -> {
          val path = call.argument<String?>("path")
          val types = call.argument<List<Int>?>("types")
          if (path != null && types != null) {
            result.success(setMusicAs(path, types, true))
          } else {
            result.success(false)
          }
        }
        "getCurrentlySet" -> {
          val type = call.argument<Int?>("type")
          if (type != null) {
            result.success(RingtoneController().getCurrentlySet(context, type))
          } else {
            result.success(null)
          }
        }
        "openEqualizer" -> {
          result.success(openSystemEqualizer())
        }
        else -> result.notImplemented()
      }
    }

    pipEventChannel = BetterEventChannel(messenger, EVENTCHANNELNAME)
  }

  private fun showToast(text: String?, duration: Int) {
    cancelToast()
    toast = Toast.makeText(context, text, duration)
    toast?.show()
  }
  private fun cancelToast() {
    toast?.cancel()
    toast = null
  }

  override fun provideFlutterEngine(@NonNull context: Context): FlutterEngine {
    this.context = context
    return AudioServicePlugin.getFlutterEngine(context)
  }

  override fun onUserLeaveHint() {
    channel.invokeMethod("onUserLeaveHint", null)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      if (canEnterPip &&
              com.ryanheise.just_audio.MainMethodCallHandler.willPlayWhenReady() &&
              com.ryanheise.just_audio.MainMethodCallHandler.hasVideo() &&
              !isInPip()
      ) {
        enterPip()
      }
    }
    super.onUserLeaveHint()
  }

  override fun onResume() {
    channel.invokeMethod("onResume", null)
    super.onResume()
  }

  override fun onPostResume() {
    channel.invokeMethod("onPostResume", null)
    super.onPostResume()
  }

  override fun onStop() {
    channel.invokeMethod("onStop", null)
    super.onStop()
  }

  override fun onDestroy() {
    channel.invokeMethod("onDestroy", null)
    pipEventChannel?.endOfStream()
    super.onDestroy()
  }

  override fun onNewIntent(@NonNull intent: Intent) {
    channel.invokeMethod("onNewIntent", null)
    super.onNewIntent(intent)
  }

  // ------- PIP -------

  private var canEnterPip: Boolean = false
  private var pipEventChannel: BetterEventChannel? = null
  private var pipBuilder: PictureInPictureParams.Builder? = null

  public fun isInPip(): Boolean {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
      return isInPictureInPictureMode
    }
    return false
  }

  override public fun onPictureInPictureModeChanged(
      isInPictureInPictureMode: Boolean,
      newConfig: Configuration
  ) {
    pipEventChannel?.success(isInPictureInPictureMode)
  }

  @RequiresApi(api = Build.VERSION_CODES.O)
  private fun enterPip() {
    val rational =
        com.ryanheise.just_audio.MainMethodCallHandler.getVideoRational() ?: Rational(1, 1)
    val pipB = pipBuilder
    if (pipB != null) {
      pipB.setAspectRatio(rational)
      activity.enterPictureInPictureMode(pipB.build())
    }
  }

  @RequiresApi(api = Build.VERSION_CODES.O)
  private fun updatePipRatio(width: Int?, height: Int?) {
    if (width == null || height == null) return
    val pipB = pipBuilder
    if (pipB == null) return
    pipB.setAspectRatio(Rational(width, height))
    activity.setPictureInPictureParams(pipB.build())
  }

  // ------- RINGTONE -------

  private val REQUEST_CODE_WRITE_SETTINGS = 9696
  private var SET_AS_LATEST_FILE_PATH: String? = null
  private var SET_AS_LATEST_TYPES: List<Int>? = null

  private fun setMusicAs(path: String, types: List<Int>, requestPermission: Boolean): Boolean {
    val hasPermission = checkSystemWritePermission(path, types, requestPermission)
    if (!hasPermission) return false

    val successNames = ArrayList<String>()
    for (type in types) {
      val res = RingtoneController().setAsRingtoneOrNotification(context, File(path), type)
      if (res != null) {
        showToast("error setting: ${res.message}", 3)
      } else {

        val typeName =
            when (type) {
              RingtoneManager.TYPE_RINGTONE -> "ringtone"
              RingtoneManager.TYPE_NOTIFICATION -> "notification"
              RingtoneManager.TYPE_ALARM -> "alarm"
              else -> ""
            }
        successNames.add(typeName)
      }
    }

    if (successNames.size == types.size) {
      val names = successNames.joinToString(separator = ", ")
      showToast("successfully set as: ${names}", 3)
      return true
    } else {
      return false
    }
  }

  private fun checkSystemWritePermission(
      path: String,
      types: List<Int>,
      requestPermission: Boolean
  ): Boolean {
    var hasPermission: Boolean = true
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      hasPermission = Settings.System.canWrite(this)
      if (hasPermission) {
        SET_AS_LATEST_FILE_PATH = null
        SET_AS_LATEST_TYPES = null
      } else if (requestPermission) {
        SET_AS_LATEST_FILE_PATH = path
        SET_AS_LATEST_TYPES = types
        showToast("please allow modifying system settings permission", 3)
        openAndroidPermissionsMenu()
      }
    }
    return hasPermission
  }

  private fun openAndroidPermissionsMenu() {
    val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
    intent.data = Uri.parse("package:" + packageName)
    startActivityForResult(intent, REQUEST_CODE_WRITE_SETTINGS)
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)

    if (requestCode == REQUEST_CODE_WRITE_SETTINGS) {
      if (Settings.System.canWrite(this)) {
        if (SET_AS_LATEST_FILE_PATH != null && SET_AS_LATEST_TYPES != null) {
          setMusicAs(SET_AS_LATEST_FILE_PATH!!, SET_AS_LATEST_TYPES!!, false)
        }
      } else {
        showToast("Couldn't set, permission wasn't granted", 3)
      }
      SET_AS_LATEST_FILE_PATH = null
      SET_AS_LATEST_TYPES = null
    }
  }

  // ------- EQUALIZER -------

  private val REQUEST_CODE_OPEN_EQ = 47

  private fun openSystemEqualizer(): Boolean {
    val intent = Intent(AudioEffect.ACTION_DISPLAY_AUDIO_EFFECT_CONTROL_PANEL)
    intent.putExtra(AudioEffect.EXTRA_PACKAGE_NAME, context.getPackageName())
    intent.putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
    intent.setFlags(
        Intent.FLAG_ACTIVITY_LAUNCH_ADJACENT or
            Intent.FLAG_ACTIVITY_NEW_TASK or
            Intent.FLAG_ACTIVITY_MULTIPLE_TASK
    )

    try {
      activity.startActivityForResult(intent, REQUEST_CODE_OPEN_EQ)
      return true
    } catch (notFound: ActivityNotFoundException) {
      showToast("No Built-in Equalizer was found", 3)
      return false
    } catch (e: Exception) {
      showToast(e.message, 3)
      return false
    }
  }
}
