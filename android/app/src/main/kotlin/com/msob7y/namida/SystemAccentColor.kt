// by claude
package com.msob7y.namida

import android.content.Context
import android.os.Build
import java.util.Locale

object SystemAccentColor {
  // -- android 12 roms without wallpaper colors still return the stock palette. list from material's DynamicColors
  private val supportedManufacturers = setOf(
    "fcnt", "google", "hmd global", "infinix", "infinix mobility limited", "itel", "kyocera", "lenovo", "lge", "motorola", "nothing", "oneplus",
    "oppo", "realme", "sharp", "sony", "tcl", "tecno", "tecno mobile limited", "vivo", "xiaomi",
  )
  private val supportedBrands = setOf("asus", "jio")
  private const val SAMSUNG_MIN_ONE_UI = 40100L

  private val isSupportedRom by lazy {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) return@lazy true
    val manufacturer = Build.MANUFACTURER.lowercase(Locale.ROOT)
    if (manufacturer == "samsung") return@lazy getOneUiVersion() >= SAMSUNG_MIN_ONE_UI
    if (manufacturer in supportedManufacturers) return@lazy true
    val brand = Build.BRAND.lowercase(Locale.ROOT)
    brand in supportedBrands
  }

  private fun getOneUiVersion(): Long {
    return try {
      val getLong = Build::class.java.getDeclaredMethod("getLong", String::class.java)
      getLong.isAccessible = true
      getLong.invoke(null, "ro.build.version.oneui") as Long
    } catch (_: Exception) {
      -1L
    }
  }

  // -- tone 60 of the primary palette
  fun get(context: Context): Int? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || !isSupportedRom) return null
    return context.resources.getColor(android.R.color.system_accent1_400, null)
  }
}
