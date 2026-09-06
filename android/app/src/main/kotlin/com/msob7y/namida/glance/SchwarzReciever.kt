package com.msob7y.namida.glance

import android.content.Context
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class SchwarzReceiver : HomeWidgetGlanceWidgetReceiver<SchwarzSechsPrototypeMkII>() {
  override val glanceAppWidget = SchwarzSechsPrototypeMkII()

  override fun onDeleted(context: Context, appWidgetIds: IntArray) {
    NamidaWidgetConfig.delete(context, appWidgetIds)
    super.onDeleted(context, appWidgetIds)
  }
}
