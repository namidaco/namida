package com.msob7y.namida

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink

class BetterEventChannel(messenger: BinaryMessenger, id: String) : EventSink {
  private var eventSink: EventSink? = null

  init {
    val eventChannel: EventChannel = EventChannel(messenger, id)
    eventChannel.setStreamHandler(
        object : EventChannel.StreamHandler {
          override fun onListen(arguments: Any?, es: EventChannel.EventSink) {
            eventSink = es
          }

          override fun onCancel(arguments: Any?) {
            eventSink = null
          }
        }
    )
  }

  override public fun success(event: Any) {
    if (eventSink != null) eventSink?.success(event)
  }

  override public fun error(errorCode: String, errorMessage: String, errorDetails: Any) {
    if (eventSink != null) eventSink?.error(errorCode, errorMessage, errorDetails)
  }

  override public fun endOfStream() {
    if (eventSink != null) eventSink?.endOfStream()
  }
}
