package com.msob7y.namida

import android.content.Context
import android.content.Intent
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class NamidaMainActivity : FlutterActivity() {
    private val CHANNELNAME = "namida"
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        // GeneratedPluginRegistrant.registerWith(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNELNAME)
    }

    override fun provideFlutterEngine(@NonNull context: Context): FlutterEngine {
        return AudioServicePlugin.getFlutterEngine(context)
    }

    override fun onUserLeaveHint() {
        channel?.invokeMethod("onUserLeaveHint", null)
        super.onUserLeaveHint()
    }

    override fun onResume() {
        channel?.invokeMethod("onResume", null)
        super.onResume()
    }

    override fun onPostResume() {
        channel?.invokeMethod("onPostResume", null)
        super.onPostResume()
    }

    override fun onStop() {
        channel?.invokeMethod("onStop", null)
        super.onStop()
    }

    override fun onDestroy() {
        channel?.invokeMethod("onDestroy", null)
        super.onDestroy()
    }

    override fun onNewIntent(@NonNull intent: Intent) {
        channel?.invokeMethod("onNewIntent", null)
        super.onNewIntent(intent)
    }
}
