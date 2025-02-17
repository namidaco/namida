package com.msob7y.namida.glance

import androidx.compose.ui.graphics.Color

sealed class NamidaWidgetColors(
  val boxColor: Color,
  val imageColor: Color,
  val titleColor: Color,
  val subtitleColor: Color,
  val iconsColor: Color,
) {

  companion object {
    val light = NamidaWidgetColors.buildLight()
    val dark = NamidaWidgetColors.buildDark()
  }

  class buildLight() :
    NamidaWidgetColors(
      Color.getPlainColor(240, 255),
      Color.getPlainColor(190),
      Color.getPlainColor(0, 180),
      Color.getPlainColor(0, 160),
      Color.getPlainColor(0, 160),
    )

  class buildDark() :
    NamidaWidgetColors(
      Color.getPlainColor(16, 255),
      Color.getPlainColor(120),
      Color.getPlainColor(220),
      Color.getPlainColor(200),
      Color.getPlainColor(200),
    )


}

private fun Color.Companion.getPlainColor(channelValue: Int, alpha: Int = channelValue): Color {
  return Color(channelValue, channelValue, channelValue, alpha);
}