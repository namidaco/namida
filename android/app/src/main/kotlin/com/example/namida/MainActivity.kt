package com.msob7y.namida

import android.content.Context
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class NamidaMainActivity : FlutterActivity() {
    override fun provideFlutterEngine(@NonNull context: Context): FlutterEngine {
        return AudioServicePlugin.getFlutterEngine(context)
    }
}
