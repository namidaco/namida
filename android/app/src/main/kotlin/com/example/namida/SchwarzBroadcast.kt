package com.msob7y.namida

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SchwarzBroadcast : BroadcastReceiver() {
  private val HOME_WIDGET_BACKGROUND_ACTION = "com.msob7y.namida.action.BACKGROUND"

  override fun onReceive(context: Context, intentRecieved: Intent) {
    val intent = Intent(context, NamidaMainActivity::class.java)
    intent.data = intentRecieved.data
    intent.action = HOME_WIDGET_BACKGROUND_ACTION
    intent.addFlags(
        Intent.FLAG_ACTIVITY_CLEAR_TASK or
            Intent.FLAG_ACTIVITY_CLEAR_TOP or
            Intent.FLAG_ACTIVITY_NEW_TASK
    )
    context.startActivity(intent)
  }
}
