package com.msob7y.namida

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class SchwarzSechsPrototypeMkII : HomeWidgetProvider() {

  private val HOME_WIDGET_BACKGROUND_ACTION = "com.msob7y.namida.action.BACKGROUND"

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences
  ) {
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.mk2).apply {
            // Open App on Widget Click
            val pendingIntent =
                HomeWidgetLaunchIntent.getActivity(context, NamidaMainActivity::class.java)
            setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            // Swap Title Text by calling Dart Code in the Background
            setTextViewText(R.id.widget_title, widgetData.getString("title", null) ?: "")

            setClickIntent(this, context, R.id.previous, "previous")
            setClickIntent(this, context, R.id.play_pause, "play_pause")
            setClickIntent(this, context, R.id.next, "next")

            val message = widgetData.getString("message", null)
            setTextViewText(R.id.widget_message, message ?: "Unknown")
            // Show Images saved with `renderFlutterWidget`
            val image = widgetData.getString("dashIcon", null)
            if (image != null) {
              setImageViewBitmap(R.id.widget_img, BitmapFactory.decodeFile(image))
              setViewVisibility(R.id.widget_img, View.VISIBLE)
            } else {
              setViewVisibility(R.id.widget_img, View.GONE)
            }

            // Detect App opened via Click inside Flutter
            val pendingIntentWithData =
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    NamidaMainActivity::class.java,
                    Uri.parse("namidaWidget://message?message=$message")
                )
            setOnClickPendingIntent(R.id.widget_message, pendingIntentWithData)
          }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }

  private fun setClickIntent(views: RemoteViews, context: Context, viewId: Int, key: String) {
    val backgroundIntent =
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("namidaWidget://$key"))
    views.setOnClickPendingIntent(viewId, backgroundIntent)

    // val serviceName = ComponentName(context, NamidaMainActivity::class.java)

    // val intent = Intent(HOME_WIDGET_BACKGROUND_ACTION)
    // intent.component = serviceName
    // intent.data = Uri.parse("namidaWidget://$key")
    // val pendingIntent: PendingIntent
    // if (Build.VERSION.SDK_INT >= 23) {
    //   pendingIntent =
    //       PendingIntent.getForegroundService(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)
    // } else {
    //   pendingIntent = PendingIntent.getService(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)
    // }

    // val pendingIntent = buildPendingIntent(context, HOME_WIDGET_BACKGROUND_ACTION, serviceName)
    // views.setOnClickPendingIntent(viewId, pendingIntent)

    // val intent = Intent(context.getApplicationContext(), NamidaMainActivity::class.java)
    // intent.addFlags(
    //     Intent.FLAG_ACTIVITY_CLEAR_TASK or
    //         Intent.FLAG_ACTIVITY_CLEAR_TOP or
    //         Intent.FLAG_ACTIVITY_NEW_TASK
    // )
    // intent.data = Uri.parse("namidaWidget://$key")
    // intent.action = HOME_WIDGET_BACKGROUND_ACTION
    // context.startActivity(intent)

    // val intent = Intent(context, NamidaMainActivity::class.java)
    // intent.data = Uri.parse("namidaWidget://$key")
    // intent.action = HOME_WIDGET_BACKGROUND_ACTION

    // var flags = PendingIntent.FLAG_UPDATE_CURRENT
    // if (Build.VERSION.SDK_INT >= 23) {
    //   flags = flags or PendingIntent.FLAG_IMMUTABLE
    // }

    // val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)
    // val pendingIntentActivity = PendingIntent.getActivity(context, 0, intent, flags)

    // views.setOnClickPendingIntent(viewId, backgroundIntent)
  }

  protected fun buildPendingIntent(
      context: Context,
      action: String,
      serviceName: ComponentName
  ): PendingIntent {
    val intent = Intent(action)
    intent.component = serviceName
    return if (Build.VERSION.SDK_INT >= 23) {
      PendingIntent.getForegroundService(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)
    } else {
      PendingIntent.getService(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)
    }
  }
}
