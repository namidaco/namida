package com.msob7y.namida

import android.app.Activity
import android.os.Build
import android.view.Display

/// Requesting this from dart used to get dropped whenever the engine ran before an activity existed
/// (it is shared with the audio service), leaving the app at the default rate until it was restarted.
/// by claude
object DisplayRefreshRate {

  @Suppress("DEPRECATION")
  private fun getDisplay(activity: Activity): Display? {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      activity.display
    } else {
      activity.windowManager?.defaultDisplay
    }
  }

  fun applyMax(activity: Activity) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
    try {
      val display = getDisplay(activity) ?: return
      val window = activity.window ?: return

      val activeMode = display.mode
      var bestMode = activeMode
      for (mode in display.supportedModes) {
        // -- resolution is kept as is, switching it would resize the whole ui
        if (mode.physicalWidth != activeMode.physicalWidth) continue
        if (mode.physicalHeight != activeMode.physicalHeight) continue
        if (mode.refreshRate > bestMode.refreshRate) bestMode = mode
      }

      val params = window.attributes
      if (params.preferredDisplayModeId == bestMode.modeId && params.preferredRefreshRate == bestMode.refreshRate) return
      params.preferredDisplayModeId = bestMode.modeId
      // -- roms that ignore the mode id can still honour a plain rate request
      params.preferredRefreshRate = bestMode.refreshRate
      window.attributes = params
    } catch (_: Exception) {
    }
  }
}
