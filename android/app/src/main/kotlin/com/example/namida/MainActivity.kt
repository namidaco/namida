package com.msob7y.namida

import android.app.PictureInPictureParams
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import android.widget.Toast
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class NamidaMainActivity : FlutterActivity() {
  private val CHANNELNAME = "namida"
  private val EVENTCHANNELNAME = "namida_events"
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var toast: Toast? = null

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {

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
            toast = Toast.makeText(context, text, duration)
            toast?.show()
            result.success(true)
          } catch (e: Exception) {
            result.error("NAMIDA TOAST", "Error showing toast", e)
            print(e)
          }
        }
        "cancelToast" -> {
          toast?.cancel()
          toast = null
          result.success(true)
        }
        "setCanEnterPip" -> {
          val canEnter = call.argument<Boolean?>("canEnter")
          if (canEnter != null) canEnterPip = canEnter
        }
        "updatePipRatio" -> {
          if (isInPip()) updatePipRatio(call.argument<Int?>("width"), call.argument<Int?>("height"))
        }
        else -> result.notImplemented()
      }
    }

    pipEventChannel = BetterEventChannel(messenger, EVENTCHANNELNAME)
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
    val rational = com.ryanheise.just_audio.MainMethodCallHandler.getVideoRational()
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
}
