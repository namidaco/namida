package com.msob7y.namida.glance

import android.content.Context
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class SchwarzReceiver : HomeWidgetGlanceWidgetReceiver<SchwarzSechsPrototypeMkII>() {
  override val glanceAppWidget = SchwarzSechsPrototypeMkII()

  // -- dart skips widget writes while none exist
  override fun onEnabled(context: Context) {
    super.onEnabled(context)
    sendAudioServiceCustomAction(kActionWidgetsEnabled)
  }

  override fun onDisabled(context: Context) {
    sendAudioServiceCustomAction(kActionWidgetsDisabled)
    super.onDisabled(context)
  }

  override fun onDeleted(context: Context, appWidgetIds: IntArray) {
    NamidaWidgetConfig.delete(context, appWidgetIds)
    super.onDeleted(context, appWidgetIds)
  }

  companion object {
    private const val kActionWidgetsEnabled = "namida_widget_enabled"
    private const val kActionWidgetsDisabled = "namida_widget_disabled"
  }
}
