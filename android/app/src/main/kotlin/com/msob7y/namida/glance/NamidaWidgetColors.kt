package com.msob7y.namida.glance

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.core.graphics.ColorUtils

class NamidaWidgetColors(
  val boxColor: Color,
  val imageColor: Color,
  val titleColor: Color,
  val subtitleColor: Color,
  val iconsColor: Color,
  /** raw artwork color, used for glows & gradient backdrops. */
  val accentColor: Color,
) {

  companion object {
    private val light =
      NamidaWidgetColors(
        Color.getPlainColor(240, 255),
        Color.getPlainColor(190),
        Color.getPlainColor(0, 180),
        Color.getPlainColor(0, 160),
        Color.getPlainColor(0, 160),
        Color.getPlainColor(170, 255),
      )

    private val dark =
      NamidaWidgetColors(
        Color.getPlainColor(16, 255),
        Color.getPlainColor(120),
        Color.getPlainColor(220),
        Color.getPlainColor(200),
        Color.getPlainColor(200),
        Color.getPlainColor(90, 255),
      )

    fun getDefault(isDark: Boolean): NamidaWidgetColors = if (isDark) dark else light

    fun buildColors(mainColor: Int?, accent: Int?, isDark: Boolean): NamidaWidgetColors {
      val base = getDefault(isDark)
      if (mainColor == null) return base
      val accentColor = Color.getArgbColor(accent ?: mainColor, 255)
      return if (isDark) {
        NamidaWidgetColors(
          Color.getArgbColor(mixColors(mainColor, base.boxColor, 0.8f), 255),
          Color.getArgbColor(mixColors(mainColor, base.imageColor, 0.8f)),
          Color.getArgbColor(mixColors(mainColor, base.titleColor, 0.8f)),
          Color.getArgbColor(mixColors(mainColor, base.subtitleColor, 0.8f)),
          Color.getArgbColor(mixColors(mainColor, base.iconsColor, 0.8f)),
          accentColor,
        )
      } else {
        NamidaWidgetColors(
          Color.getArgbColor(mixColors(mainColor, base.boxColor, 0.7f), 255),
          Color.getArgbColor(mixColors(mainColor, base.imageColor, 0.7f)),
          Color.getArgbColor(mixColors(mainColor, base.titleColor, 0.8f), 180),
          Color.getArgbColor(mixColors(mainColor, base.subtitleColor, 0.8f), 160),
          Color.getArgbColor(mixColors(mainColor, base.iconsColor, 0.8f), 160),
          accentColor,
        )
      }
    }

    private fun mixColors(color1: Int, color2: Color, ratio: Float): Int {
      return ColorUtils.blendARGB(color1, color2.toArgb(), ratio)
    }
  }
}

private fun Color.Companion.getPlainColor(channelValue: Int, alpha: Int = channelValue): Color {
  return Color(channelValue, channelValue, channelValue, alpha)
}

internal fun Color.Companion.getArgbColor(argbValue: Int, alpha: Int = 255): Color {
  return Color(
    red = android.graphics.Color.red(argbValue),
    green = android.graphics.Color.green(argbValue),
    blue = android.graphics.Color.blue(argbValue),
    alpha = alpha,
  )
}

internal fun Color.withOpacityPercent(percent: Int): Color {
  if (percent >= 100) return this
  return copy(alpha = alpha * (percent.coerceIn(0, 100) / 100f))
}
