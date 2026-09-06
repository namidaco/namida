package com.msob7y.namida.glance

import android.content.Context
import android.content.SharedPreferences

enum class WidgetTheme {
  SYSTEM,
  LIGHT,
  DARK,
}

enum class WidgetLayout {
  AUTO,
  ROW,
  CARD,
  COMPACT,
}

enum class WidgetBackdrop {
  SOLID,
  GRADIENT,
  BLURRED_ARTWORK,
}

enum class ArtworkEffect {
  NONE,
  GLOW,
  SHADOW,
}

enum class TapAction {
  OPEN_APP,
  PLAY_PAUSE,
  NONE,
}

// config by claude
data class NamidaWidgetConfig(
  val theme: WidgetTheme = WidgetTheme.SYSTEM,
  val artworkColors: Boolean = true,
  val backdrop: WidgetBackdrop = WidgetBackdrop.GRADIENT,
  val artworkEffect: ArtworkEffect = ArtworkEffect.GLOW,
  val backgroundOpacity: Int = 100,
  val cornerRadius: Int = 14,
  val artworkRounding: Int = 10,
  val layout: WidgetLayout = WidgetLayout.AUTO,
  val contentScale: Int = 100,
  val artworkScale: Int = 100,
  val showArtwork: Boolean = true,
  val showTitle: Boolean = true,
  val showSubtitle: Boolean = true,
  val showFavourite: Boolean = true,
  val showShuffle: Boolean = false,
  val showPrevious: Boolean = true,
  val showPlayPause: Boolean = true,
  val showNext: Boolean = true,
  val showRepeat: Boolean = true,
  val showStop: Boolean = false,
  val backgroundTapAction: TapAction = TapAction.OPEN_APP,
  val artworkTapAction: TapAction = TapAction.OPEN_APP,
) {

  val hasAnyControl: Boolean
    get() =
      showFavourite ||
        showShuffle ||
        showPrevious ||
        showPlayPause ||
        showNext ||
        showRepeat ||
        showStop

  companion object {
    private const val PREFS_NAME = "namida_widget_config"
    private const val KEY_VERSION = "v"
    private const val CURRENT_VERSION = 1

    /**
     * fallback config for widgets that were never configured individually. never a real
     * appWidgetId, so it can share the same prefs file.
     */
    const val DEFAULTS_ID = -1

    val defaults = NamidaWidgetConfig()

    private fun prefs(context: Context): SharedPreferences =
      context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun prefix(appWidgetId: Int) = "w$appWidgetId."

    fun load(context: Context, appWidgetId: Int): NamidaWidgetConfig {
      val p = prefs(context)
      val own = prefix(appWidgetId)
      val fallback = prefix(DEFAULTS_ID)
      val k =
        when {
          p.contains(own + KEY_VERSION) -> own
          p.contains(fallback + KEY_VERSION) -> fallback
          else -> return defaults
        }
      val d = defaults
      return NamidaWidgetConfig(
        theme = p.getEnum(k + "theme", d.theme),
        artworkColors = p.getBoolean(k + "artworkColors", d.artworkColors),
        backdrop = p.getEnum(k + "backdrop", d.backdrop),
        artworkEffect = p.getEnum(k + "artworkEffect", d.artworkEffect),
        backgroundOpacity = p.getInt(k + "backgroundOpacity", d.backgroundOpacity),
        cornerRadius = p.getInt(k + "cornerRadius", d.cornerRadius),
        artworkRounding = p.getInt(k + "artworkRounding", d.artworkRounding),
        layout = p.getEnum(k + "layout", d.layout),
        contentScale = p.getInt(k + "contentScale", d.contentScale),
        artworkScale = p.getInt(k + "artworkScale", d.artworkScale),
        showArtwork = p.getBoolean(k + "showArtwork", d.showArtwork),
        showTitle = p.getBoolean(k + "showTitle", d.showTitle),
        showSubtitle = p.getBoolean(k + "showSubtitle", d.showSubtitle),
        showFavourite = p.getBoolean(k + "showFavourite", d.showFavourite),
        showShuffle = p.getBoolean(k + "showShuffle", d.showShuffle),
        showPrevious = p.getBoolean(k + "showPrevious", d.showPrevious),
        showPlayPause = p.getBoolean(k + "showPlayPause", d.showPlayPause),
        showNext = p.getBoolean(k + "showNext", d.showNext),
        showRepeat = p.getBoolean(k + "showRepeat", d.showRepeat),
        showStop = p.getBoolean(k + "showStop", d.showStop),
        backgroundTapAction = p.getEnum(k + "backgroundTapAction", d.backgroundTapAction),
        artworkTapAction = p.getEnum(k + "artworkTapAction", d.artworkTapAction),
      )
    }

    fun save(context: Context, appWidgetId: Int, config: NamidaWidgetConfig) {
      val k = prefix(appWidgetId)
      prefs(context).edit().apply {
        putInt(k + KEY_VERSION, CURRENT_VERSION)
        putEnum(k + "theme", config.theme)
        putBoolean(k + "artworkColors", config.artworkColors)
        putEnum(k + "backdrop", config.backdrop)
        putEnum(k + "artworkEffect", config.artworkEffect)
        putInt(k + "backgroundOpacity", config.backgroundOpacity)
        putInt(k + "cornerRadius", config.cornerRadius)
        putInt(k + "artworkRounding", config.artworkRounding)
        putEnum(k + "layout", config.layout)
        putInt(k + "contentScale", config.contentScale)
        putInt(k + "artworkScale", config.artworkScale)
        putBoolean(k + "showArtwork", config.showArtwork)
        putBoolean(k + "showTitle", config.showTitle)
        putBoolean(k + "showSubtitle", config.showSubtitle)
        putBoolean(k + "showFavourite", config.showFavourite)
        putBoolean(k + "showShuffle", config.showShuffle)
        putBoolean(k + "showPrevious", config.showPrevious)
        putBoolean(k + "showPlayPause", config.showPlayPause)
        putBoolean(k + "showNext", config.showNext)
        putBoolean(k + "showRepeat", config.showRepeat)
        putBoolean(k + "showStop", config.showStop)
        putEnum(k + "backgroundTapAction", config.backgroundTapAction)
        putEnum(k + "artworkTapAction", config.artworkTapAction)
      }.apply()
    }

    fun delete(context: Context, appWidgetIds: IntArray) {
      val p = prefs(context)
      val all = p.all.keys
      p.edit().apply {
        appWidgetIds.forEach { id ->
          val k = prefix(id)
          all.filter { it.startsWith(k) }.forEach { remove(it) }
        }
      }.apply()
    }
  }
}

private inline fun <reified T : Enum<T>> SharedPreferences.getEnum(key: String, fallback: T): T {
  val name = getString(key, null) ?: return fallback
  return try {
    enumValueOf<T>(name)
  } catch (_: IllegalArgumentException) {
    fallback
  }
}

private fun <T : Enum<T>> SharedPreferences.Editor.putEnum(key: String, value: T) {
  putString(key, value.name)
}
