package com.msob7y.namida

import android.content.Context
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.view.KeyEvent
import androidx.annotation.RequiresApi
import com.msob7y.namida.glance.kActionShuffle
import com.msob7y.namida.glance.sendAudioServiceCustomAction
import com.msob7y.namida.glance.sendMediaButtonIntent
import com.ryanheise.audioservice.AudioService

@RequiresApi(Build.VERSION_CODES.N)
class NamidaQuickSettingsTile : TileService() {

  override fun onTileAdded() {
    updateTile()
  }

  override fun onTileRemoved() {}

  override fun onStartListening() {
    updateTile()
  }

  override fun onStopListening() {
    updateTile()
  }

  override fun onClick() {
    val isPlaying = getIsPlaying()
    val keyCode = if (isPlaying) KeyEvent.KEYCODE_MEDIA_PAUSE else KeyEvent.KEYCODE_MEDIA_PLAY
    sendMediaButtonIntent(applicationContext, keyCode)
    updateTile(!isPlaying)
  }

  private fun updateTile(isNowPlaying: Boolean? = null) {
    val isPlaying = isNowPlaying ?: getIsPlaying()
    val newState = if (isPlaying) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
    val newIcon =
      if (isPlaying) com.ryanheise.audioservice.R.drawable.audio_service_pause else com.ryanheise.audioservice.R.drawable.audio_service_play_arrow
    val defaultLabel = "Namida" // its alr in manifest but whatever
    val newAction = if (isPlaying) "Pause" else "Play"
    qsTile?.apply {
      state = newState
      icon = Icon.createWithResource(applicationContext, newIcon)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        label = defaultLabel
        subtitle = newAction
      } else {
        label = "$defaultLabel $newAction"
      }
      updateTile()
    }
  }

  private fun getIsPlaying(): Boolean {
    val isPlaying = getAudioServiceInstance()?.isPlaying ?: false
    return isPlaying
  }
}

// -- no questioning on this garbage pls
fun getAudioServiceInstance(): AudioService? {
  try {
    val classInst = AudioService::class.java
    return classInst.getDeclaredField("instance").let {
      it.isAccessible = true
      val value = it.get(classInst) as AudioService?
      return@let value
    }
  } catch (_: Exception) {
    return null
  }
}

@RequiresApi(Build.VERSION_CODES.N)
class NamidaShuffleQuickSettingsTile : TileService() {

  override fun onTileAdded() {
    updateTile()
  }

  override fun onTileRemoved() {}

  override fun onStartListening() {
    updateTile()
  }

  override fun onStopListening() {
    updateTile()
  }

  override fun onClick() {
    // -- shuffle has no media keycode, it goes to the audio service as a custom action,
    // -- which is a no-op while the service isnt alive, same as the home widget button.
    if (getAudioServiceInstance() == null) return
    val isShuffling = getIsShuffling()
    sendAudioServiceCustomAction(kActionShuffle)
    updateTile(!isShuffling)
  }

  private fun updateTile(isNowShuffling: Boolean? = null) {
    val isShuffling = isNowShuffling ?: getIsShuffling()
    qsTile?.apply {
      state = if (isShuffling) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
      icon = Icon.createWithResource(applicationContext, R.drawable.shuffle)
      val defaultLabel = "Shuffle"
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        label = defaultLabel
        subtitle = if (isShuffling) "On" else "Off"
      } else {
        label = "$defaultLabel ${if (isShuffling) "On" else "Off"}"
      }
      updateTile()
    }
  }

  // written by `_HomeWidgetsMobile` on the dart side whenever shuffle changes.
  private fun getIsShuffling(): Boolean {
    return try {
      applicationContext
        .getSharedPreferences(kHomeWidgetPreferences, Context.MODE_PRIVATE)
        .getBoolean("shuffle", false)
    } catch (_: Exception) {
      false
    }
  }
}

private const val kHomeWidgetPreferences = "HomeWidgetPreferences"
