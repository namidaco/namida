package com.msob7y.namida

import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class NamidaMainActivity : FlutterActivity() {
    private val CHANNELNAME = "namida"
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var toast: Toast? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        // GeneratedPluginRegistrant.registerWith(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNELNAME)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
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
                else -> result.notImplemented()
            }
        }
    }

    override fun provideFlutterEngine(@NonNull context: Context): FlutterEngine {
        this.context = context
        return AudioServicePlugin.getFlutterEngine(context)
    }

    override fun onUserLeaveHint() {
        channel.invokeMethod("onUserLeaveHint", null)
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
        super.onDestroy()
    }

    override fun onNewIntent(@NonNull intent: Intent) {
        channel.invokeMethod("onNewIntent", null)
        super.onNewIntent(intent)
    }
}
