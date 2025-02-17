package com.msob7y.namida

import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.view.KeyEvent
import androidx.annotation.RequiresApi
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
