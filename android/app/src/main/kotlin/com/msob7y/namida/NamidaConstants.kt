package com.msob7y.namida

object NamidaConstants {
  const val ACTION_CUSTOM_START = "com.msob7y.namida.CUSTOM_START"
  const val BABE_WAKE_UP = "com.msob7y.namida.BABE_WAKE_UP"

  // set when a media command is sent by us (home widget/quick settings tile),
  // used to differentiate our commands from external ones (bluetooth, system resumption, etc)
  // which shouldn't start playback on a cold start.
  @Volatile @JvmField var selfSentMediaCommand = false
}
