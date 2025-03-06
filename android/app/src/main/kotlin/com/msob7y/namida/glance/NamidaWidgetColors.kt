package com.msob7y.namida.glance

import android.graphics.Bitmap
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.core.graphics.ColorUtils

sealed class NamidaWidgetColors(
  val boxColor: Color,
  val imageColor: Color,
  val titleColor: Color,
  val subtitleColor: Color,
  val iconsColor: Color,
) {

  companion object {
    private val light = BuildLight()
    private val dark = BuildDark()

    fun getDefault(isDark: Boolean): NamidaWidgetColors {
      return if (isDark) dark else light
    }

    fun buildColors(mainColor: Int?, isDark: Boolean): NamidaWidgetColors {
      return if (isDark) {
        if (mainColor == null) dark else BuildDarkColors(mainColor)
      } else {
        if (mainColor == null) light else BuildLightColors(mainColor)
      }
    }


    fun mixColors(color1: Int?, color2: Int, ratio: Float = 0.2f): Int {
      if (color1 == null) return color2
      return ColorUtils.blendARGB(color1, color2, ratio)
    }
  }

  class BuildLight() :
    NamidaWidgetColors(
      Color.getPlainColor(240, 255),
      Color.getPlainColor(190),
      Color.getPlainColor(0, 180),
      Color.getPlainColor(0, 160),
      Color.getPlainColor(0, 160),
    )

  class BuildDark() :
    NamidaWidgetColors(
      Color.getPlainColor(16, 255),
      Color.getPlainColor(120),
      Color.getPlainColor(220),
      Color.getPlainColor(200),
      Color.getPlainColor(200),
    )

  class BuildLightColors(mainColor: Int) :
    NamidaWidgetColors(
      Color.getPlainColor(mixColors(mainColor, light.boxColor.toArgb(), 0.8f), 255),
      Color.getPlainColor(mixColors(mainColor, light.imageColor.toArgb(), 0.8f)),
      Color.getPlainColor(mixColors(mainColor, light.titleColor.toArgb()), 180),
      Color.getPlainColor(mixColors(mainColor, light.subtitleColor.toArgb()), 160),
      Color.getPlainColor(mixColors(mainColor, light.iconsColor.toArgb()), 160),
    )

  class BuildDarkColors(mainColor: Int) :
    NamidaWidgetColors(
      Color.getPlainColor(mixColors(mainColor, dark.boxColor.toArgb(), 0.8f), 255),
      Color.getPlainColor(mixColors(mainColor, dark.imageColor.toArgb(), 0.8f)),
      Color.getPlainColor(mixColors(mainColor, dark.titleColor.toArgb())),
      Color.getPlainColor(mixColors(mainColor, dark.subtitleColor.toArgb())),
      Color.getPlainColor(mixColors(mainColor, dark.iconsColor.toArgb())),
    )

}

private fun Color.Companion.getPlainColor(channelValue: Int, alpha: Int = channelValue): Color {
  return Color(channelValue, channelValue, channelValue, alpha);
}