package com.msob7y.namida.glance

import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.NoRippleOverride
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.lifecycle.Lifecycle
import androidx.palette.graphics.Palette
import com.msob7y.namida.NamidaConstants
import com.msob7y.namida.NamidaMainActivity
import com.msob7y.namida.getAudioServiceInstance
import com.msob7y.namida.R

// rewrite by claude
class SchwarzSechsPrototypeMkII : GlanceAppWidget() {

  /** Needed for Updating */
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override val sizeMode = SizeMode.Exact

  override fun onCompositionError(context: Context, glanceId: GlanceId, appWidgetId: Int, throwable: Throwable) {
    Log.e(kLogTag, "widget composition failed for id=$appWidgetId", throwable)
    super.onCompositionError(context, glanceId, appWidgetId, throwable)
  }

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    val appWidgetId =
      try {
        GlanceAppWidgetManager(context).getAppWidgetId(id)
      } catch (_: Exception) {
        0
      }
    val config = NamidaWidgetConfig.load(context, appWidgetId)
    provideContent {
      val state = currentState<HomeWidgetGlanceState>()
      if (state.preferences.getBoolean("evict", false)) ArtworkStore.evict()
      NamidaWidgetContent(context, WidgetPayload.from(state), config, interactive = true)
    }
  }
}

internal class WidgetPayload(
  val title: String,
  val subtitle: String,
  val isPlaying: Boolean,
  val isFav: Boolean,
  val repeat: WidgetRepeat,
  val repeatCount: Int,
  val imagePath: String?,
) {
  companion object {
    fun from(state: HomeWidgetGlanceState): WidgetPayload {
      val data = state.preferences
      return WidgetPayload(
        title = data.getString("title", "") ?: "",
        subtitle = data.getString("message", "") ?: "",
        isPlaying = data.getBoolean("playing", false),
        isFav = data.getBoolean("favourite", false),
        repeat = WidgetRepeat.parse(data.getString("repeat", null)),
        repeatCount = data.getInt("repeatCount", 1),
        imagePath = data.getString("image", null),
      )
    }
  }
}

/** mirrors `PlayerRepeatMode` and its `PlayerRepeatModeL10n` icons. */
internal enum class WidgetRepeat(val drawableRes: Int, val secondaryRes: Int?) {
  NONE(R.drawable.repeate_music, null),
  ONE(R.drawable.repeate_one, null),
  FOR_N_TIMES(R.drawable.status, null),
  ALL(R.drawable.repeat, null),
  ALL_SHUFFLE(R.drawable.repeat, R.drawable.shuffle),
  SHUFFLE(R.drawable.shuffle, null);

  companion object {
    fun parse(name: String?): WidgetRepeat =
      when (name) {
        "one" -> ONE
        "forNtimes" -> FOR_N_TIMES
        "all" -> ALL
        "allShuffle" -> ALL_SHUFFLE
        "shuffle" -> SHUFFLE
        else -> NONE
      }
  }
}

// ================================ content ================================

@Composable
internal fun NamidaWidgetContent(
  context: Context,
  payload: WidgetPayload,
  config: NamidaWidgetConfig,
  interactive: Boolean,
) {
  val size = LocalSize.current
  val w = size.width
  val h = size.height
  val layout = config.layout.resolveFor(w, h)
  val isDark = config.theme.isDark(context)

  val artSize = layout.artworkSizeOf(w, h, config)
  val decoded = ArtworkStore.decode(context, payload.imagePath, artSize.toPxInt(context))

  val colors =
    if (config.artworkColors) {
      NamidaWidgetColors.buildColors(decoded?.mainColor, decoded?.accentColor, isDark)
    } else {
      NamidaWidgetColors.getDefault(isDark)
    }

  val artwork =
    if (config.showArtwork) ArtworkStore.artwork(context, decoded, artSize, config, colors) else null
  val backdrop = ArtworkStore.backdrop(context, decoded, w, h, config, colors)

  var rootModifier =
    GlanceModifier.fillMaxSize().appWidgetBackground().cornerRadius(config.cornerRadius.dp)
  rootModifier =
    if (backdrop != null) {
      rootModifier.background(ImageProvider(backdrop), ContentScale.FillBounds)
    } else {
      rootModifier.background(colors.boxColor.withOpacityPercent(config.backgroundOpacity))
    }
  rootModifier = rootModifier.tapAction(context, config.backgroundTapAction, interactive)

  Box(contentAlignment = Alignment.Center, modifier = rootModifier) {
    when (layout) {
      WidgetLayout.CARD ->
        CardLayout(context, payload, config, colors, artwork, artSize, w, h, interactive)
      WidgetLayout.COMPACT ->
        CompactLayout(context, payload, config, colors, artwork, artSize, w, h, interactive)
      else -> RowLayout(context, payload, config, colors, artwork, artSize, w, h, interactive)
    }
  }
}

@Composable
private fun RowLayout(
  context: Context,
  payload: WidgetPayload,
  config: NamidaWidgetConfig,
  colors: NamidaWidgetColors,
  artwork: Bitmap?,
  artSize: Dp,
  w: Dp,
  h: Dp,
  interactive: Boolean,
) {
  val scale = config.contentScale / 100f
  val padding = minOf(w * 0.04f, h * 0.09f, 13.dp)
  val gap = minOf(w * 0.03f, 10.dp)
  val titleSize = (h.value * 0.17f * scale).coerceIn(11f, 28f)
  val maxButtonHeight = (h * 0.42f * scale).clampDp(32.dp, 50.dp)
  val spacing = (maxButtonHeight * 0.08f).clampDp(2.dp, 5.dp)
  val textsWidth = w - padding * 2 - (if (artwork != null) artSize + gap else 0.dp)

  Row(
    verticalAlignment = Alignment.CenterVertically,
    modifier = GlanceModifier.fillMaxSize().padding(horizontal = padding),
  ) {
    if (artwork != null) {
      Artwork(context, artwork, artSize, config, interactive)
      Spacer(GlanceModifier.width(gap))
    }
    Column(
      verticalAlignment = Alignment.CenterVertically,
      horizontalAlignment = Alignment.Start,
      modifier = GlanceModifier.defaultWeight(),
    ) {
      Titles(payload, config, colors, titleSize, TextAlign.Start)
      if (config.hasAnyControl) {
        Spacer(GlanceModifier.height((h * 0.05f).clampDp(2.dp, 10.dp)))
        MediaControls(
          payload,
          config,
          colors,
          textsWidth,
          maxButtonHeight,
          34.dp * scale,
          spacing,
          interactive,
        )
      }
    }
  }
}

@Composable
private fun CardLayout(
  context: Context,
  payload: WidgetPayload,
  config: NamidaWidgetConfig,
  colors: NamidaWidgetColors,
  artwork: Bitmap?,
  artSize: Dp,
  w: Dp,
  h: Dp,
  interactive: Boolean,
) {
  val scale = config.contentScale / 100f
  val padding = minOf(w * 0.06f, h * 0.06f, 14.dp)
  val titleSize = (minOf(w.value * 0.115f, h.value * 0.105f) * scale).coerceIn(12f, 32f)
  val maxButtonHeight = (h * 0.28f * scale).clampDp(32.dp, 58.dp)
  val spacing = (maxButtonHeight * 0.10f).clampDp(3.dp, 9.dp)

  Column(
    verticalAlignment = Alignment.CenterVertically,
    horizontalAlignment = Alignment.CenterHorizontally,
    modifier = GlanceModifier.fillMaxSize().padding(padding),
  ) {
    if (artwork != null) {
      Artwork(context, artwork, artSize, config, interactive)
      Spacer(GlanceModifier.height((h * 0.05f).clampDp(4.dp, 14.dp)))
    }
    Titles(payload, config, colors, titleSize, TextAlign.Center)
    if (config.hasAnyControl) {
      Spacer(GlanceModifier.height((h * 0.045f).clampDp(4.dp, 14.dp)))
      MediaControls(
        payload,
        config,
        colors,
        w - padding * 2,
        maxButtonHeight,
        40.dp * scale,
        spacing,
        interactive,
      )
    }
  }
}

@Composable
private fun CompactLayout(
  context: Context,
  payload: WidgetPayload,
  config: NamidaWidgetConfig,
  colors: NamidaWidgetColors,
  artwork: Bitmap?,
  artSize: Dp,
  w: Dp,
  h: Dp,
  interactive: Boolean,
) {
  val scale = config.contentScale / 100f
  val padding = minOf(w * 0.035f, h * 0.10f, 8.dp)
  val gap = minOf(w * 0.03f, 8.dp)
  val titleSize = (h.value * 0.30f * scale).coerceIn(9f, 17f)
  val maxButtonHeight = minOf(h - padding * 2, 46.dp * scale).clampAtLeast(22.dp)
  val hasTexts = config.showTitle || config.showSubtitle
  val controlsWidth = if (hasTexts) w * 0.5f else w - padding * 2

  Row(
    verticalAlignment = Alignment.CenterVertically,
    modifier = GlanceModifier.fillMaxSize().padding(horizontal = padding),
  ) {
    if (artwork != null) {
      Artwork(context, artwork, artSize, config, interactive)
      Spacer(GlanceModifier.width(gap))
    }
    if (hasTexts) {
      Column(
        verticalAlignment = Alignment.CenterVertically,
        horizontalAlignment = Alignment.Start,
        modifier = GlanceModifier.defaultWeight(),
      ) {
        Titles(payload, config, colors, titleSize, TextAlign.Start)
      }
      Spacer(GlanceModifier.width(gap))
    }
    if (config.hasAnyControl) {
      MediaControls(
        payload,
        config,
        colors,
        controlsWidth,
        maxButtonHeight,
        26.dp * scale,
        2.dp,
        interactive,
        fillWidth = false,
      )
    }
  }
}

@Composable
private fun Artwork(
  context: Context,
  bitmap: Bitmap,
  artSize: Dp,
  config: NamidaWidgetConfig,
  interactive: Boolean,
) {
  // -- the bitmap reserves a transparent margin for the glow, the touch shape follows the art
  val inset =
    if (config.artworkEffect == ArtworkEffect.NONE) 0.dp else artSize * ImageWrapper.kEffectInset
  val visibleSize = artSize - inset * 2
  Box(contentAlignment = Alignment.Center, modifier = GlanceModifier.size(artSize)) {
    Image(
      provider = ImageProvider(bitmap),
      contentDescription = null,
      contentScale = ContentScale.Fit,
      modifier = GlanceModifier.size(artSize),
    )
    Box(
      contentAlignment = Alignment.Center,
      modifier =
        GlanceModifier.size(visibleSize)
          .cornerRadius(visibleSize * (config.artworkRounding / 100f))
          .tapAction(context, config.artworkTapAction, interactive, R.drawable.ripple_artwork),
    ) {
      Spacer(GlanceModifier.fillMaxSize())
    }
  }
}

@Composable
private fun Titles(
  payload: WidgetPayload,
  config: NamidaWidgetConfig,
  colors: NamidaWidgetColors,
  titleSize: Float,
  align: TextAlign,
) {
  if (config.showTitle) {
    Text(
      payload.title.ifBlank { "Namida" },
      style =
        TextStyle(
          fontSize = titleSize.sp,
          fontWeight = FontWeight.Bold,
          color = ColorProvider(colors.titleColor),
          textAlign = align,
        ),
      maxLines = 1,
      modifier = GlanceModifier.fillMaxWidth(),
    )
  }
  if (config.showSubtitle && payload.subtitle.isNotBlank()) {
    Text(
      payload.subtitle,
      style =
        TextStyle(
          fontSize = (titleSize * 0.82f).sp,
          fontWeight = FontWeight.Medium,
          color = ColorProvider(colors.subtitleColor),
          textAlign = align,
        ),
      maxLines = 1,
      modifier = GlanceModifier.fillMaxWidth(),
    )
  }
}

// ================================ controls ================================

private enum class Ctrl {
  FAVOURITE,
  SHUFFLE,
  PREVIOUS,
  PLAY_PAUSE,
  NEXT,
  REPEAT,
  STOP;

  fun drawableRes(payload: WidgetPayload): Int =
    when (this) {
      FAVOURITE -> if (payload.isFav) R.drawable.unheart else R.drawable.heart
      SHUFFLE -> R.drawable.shuffle
      PREVIOUS -> R.drawable.previous
      PLAY_PAUSE -> if (payload.isPlaying) R.drawable.pause else R.drawable.play
      NEXT -> R.drawable.next
      REPEAT -> payload.repeat.drawableRes
      STOP -> R.drawable.stop
    }

  fun action(payload: WidgetPayload): CtrlAction =
    when (this) {
      FAVOURITE ->
        CtrlAction.Media(
          if (payload.isFav) KeyEvent.KEYCODE_MEDIA_FAST_FORWARD
          else KeyEvent.KEYCODE_MEDIA_REWIND
        )
      SHUFFLE -> CtrlAction.Custom(kActionShuffle)
      PREVIOUS -> CtrlAction.Media(KeyEvent.KEYCODE_MEDIA_PREVIOUS)
      PLAY_PAUSE ->
        CtrlAction.Media(
          if (payload.isPlaying) KeyEvent.KEYCODE_MEDIA_PAUSE else KeyEvent.KEYCODE_MEDIA_PLAY
        )
      NEXT -> CtrlAction.Media(KeyEvent.KEYCODE_MEDIA_NEXT)
      REPEAT -> CtrlAction.Custom(kActionCycleRepeat)
      STOP -> CtrlAction.Media(KeyEvent.KEYCODE_MEDIA_STOP)
    }

  fun contentDescription(payload: WidgetPayload): String =
    when (this) {
      FAVOURITE -> if (payload.isFav) "Unfavourite" else "Set Favourite"
      SHUFFLE -> "Shuffle queue"
      PREVIOUS -> "Previous"
      PLAY_PAUSE -> if (payload.isPlaying) "Pause" else "Play"
      NEXT -> "Next"
      REPEAT -> "Repeat mode"
      STOP -> "Stop"
    }

  /** off-state controls are dimmed instead of getting their own drawable. */
  fun isDimmed(payload: WidgetPayload): Boolean =
    this == REPEAT && payload.repeat == WidgetRepeat.NONE

  /** the heart glyph is visually chunkier, give it a touch more breathing room. */
  fun iconPaddingScale(): Float = if (this == FAVOURITE) 1.25f else 1f

  /** drawn small in the corner of the main icon, mirrors `PlayerRepeatModeL10n.toSecondaryIcon`. */
  fun secondaryRes(payload: WidgetPayload): Int? =
    if (this == REPEAT) payload.repeat.secondaryRes else null

  /** repeat-for-n-times shows the remaining count over the icon. */
  fun badgeText(payload: WidgetPayload): String? =
    if (this == REPEAT && payload.repeat == WidgetRepeat.FOR_N_TIMES) {
      payload.repeatCount.coerceIn(0, 99).toString()
    } else {
      null
    }
}

private sealed interface CtrlAction {
  class Media(val keyCode: Int) : CtrlAction

  class Custom(val name: String) : CtrlAction
}

/** least essential first, these get dropped when there is no room for the full set. */
private val kControlsDropOrder =
  listOf(Ctrl.STOP, Ctrl.SHUFFLE, Ctrl.REPEAT, Ctrl.FAVOURITE, Ctrl.PREVIOUS, Ctrl.NEXT)

private val kMinButtonSize = 24.dp

/** trailing breathing room so the controls stop just short of the edge. */
private val kControlsTrailingInset = 12.dp

@Composable
private fun MediaControls(
  payload: WidgetPayload,
  config: NamidaWidgetConfig,
  colors: NamidaWidgetColors,
  availableWidth: Dp,
  maxButtonHeight: Dp,
  maxIconSize: Dp,
  spacing: Dp,
  interactive: Boolean,
  fillWidth: Boolean = true,
) {
  val enabled = ArrayList<Ctrl>(Ctrl.entries.size)
  if (config.showFavourite) enabled.add(Ctrl.FAVOURITE)
  if (config.showShuffle) enabled.add(Ctrl.SHUFFLE)
  if (config.showPrevious) enabled.add(Ctrl.PREVIOUS)
  if (config.showPlayPause) enabled.add(Ctrl.PLAY_PAUSE)
  if (config.showNext) enabled.add(Ctrl.NEXT)
  if (config.showRepeat) enabled.add(Ctrl.REPEAT)
  if (config.showStop) enabled.add(Ctrl.STOP)

  // -- `availableWidth` comes from LocalSize, which some launchers under-report. it is only
  // -- used to decide how many buttons fit; the real widths come from weights below.
  fun widthFor(count: Int): Dp = (availableWidth - spacing * (count - 1)) / count
  for (ctrl in kControlsDropOrder) {
    if (enabled.size <= 1 || widthFor(enabled.size) >= kMinButtonSize) break
    enabled.remove(ctrl)
  }
  if (enabled.isEmpty()) return

  val estimatedWidth = widthFor(enabled.size).clampAtLeast(kMinButtonSize)
  // -- kept close to the width so a tall widget doesn't stretch them into pills
  val provisionalHeight =
    minOf(maxButtonHeight, estimatedWidth * 1.45f).clampAtLeast(kMinButtonSize)
  val iconPadding = (provisionalHeight * 0.15f).clampDp(2.dp, 9.dp)
  // -- ContentScale.Fit sizes the icon by the box's smaller side, so capping the height caps
  // -- the icon without ever capping the hitbox width
  val buttonHeight = minOf(provisionalHeight, maxIconSize + iconPadding * 2)

  Row(
    verticalAlignment = Alignment.CenterVertically,
    horizontalAlignment = Alignment.Start,
    modifier =
      if (fillWidth) GlanceModifier.fillMaxWidth().padding(end = kControlsTrailingInset)
      else GlanceModifier,
  ) {
    enabled.forEachIndexed { index, ctrl ->
      // -- the gap lives inside each cell rather than as a Spacer sibling: glance only has
      // -- generated layouts for up to 10 children per container, and 6 buttons + 5 spacers
      // -- silently kills the whole composition, leaving the widget stuck on its initial layout
      val gap = if (index > 0) spacing else 0.dp
      val cell =
        if (fillWidth) GlanceModifier.defaultWeight()
        else GlanceModifier.width(estimatedWidth + gap)
      MediaControlButton(
        color =
          if (ctrl.isDimmed(payload)) colors.iconsColor.copy(alpha = colors.iconsColor.alpha * 0.4f)
          else colors.iconsColor,
        drawableRes = ctrl.drawableRes(payload),
        secondaryRes = ctrl.secondaryRes(payload),
        badgeText = ctrl.badgeText(payload),
        contentDescription = ctrl.contentDescription(payload),
        action = ctrl.action(payload),
        cell = cell.height(buttonHeight).padding(start = gap),
        buttonHeight = buttonHeight,
        iconPadding = iconPadding * ctrl.iconPaddingScale(),
        interactive = interactive,
      )
    }
  }
}

@Composable
private fun MediaControlButton(
  color: Color,
  drawableRes: Int,
  secondaryRes: Int?,
  badgeText: String?,
  contentDescription: String,
  action: CtrlAction,
  cell: GlanceModifier,
  buttonHeight: Dp,
  iconPadding: Dp,
  interactive: Boolean,
) {
  // -- the clickable surface sits inside the cell so the ripple stops at the gap
  var modifier =
    GlanceModifier.fillMaxSize().cornerRadius((buttonHeight * 0.28f).clampDp(6.dp, 16.dp))
  if (interactive) {
    val parameters =
      when (action) {
        is CtrlAction.Media -> actionParametersOf(kMediaActionParam to action.keyCode)
        is CtrlAction.Custom -> actionParametersOf(kCustomActionParam to action.name)
      }
    modifier =
      modifier.clickable(
        rippleOverride = R.drawable.ripple,
        onClick = actionRunCallback<MediaButtonAction>(parameters),
      )
  }
  val tint = ColorProvider(color)
  Box(modifier = cell) {
    Box(contentAlignment = Alignment.Center, modifier = modifier) {
      // -- fills whatever the box ended up being, so it never depends on a reported width
      Image(
        provider = ImageProvider(drawableRes),
        colorFilter = ColorFilter.tint(tint),
        contentDescription = contentDescription,
        contentScale = ContentScale.Fit,
        modifier = GlanceModifier.fillMaxSize().padding(iconPadding),
      )
      if (badgeText != null) {
        Text(
          badgeText,
          style =
            TextStyle(
              fontSize = (buttonHeight.value * 0.30f).sp,
              fontWeight = FontWeight.Bold,
              color = tint,
              textAlign = TextAlign.Center,
            ),
          maxLines = 1,
        )
      }
      if (secondaryRes != null) {
        Box(contentAlignment = Alignment.BottomEnd, modifier = GlanceModifier.fillMaxSize()) {
          Image(
            provider = ImageProvider(secondaryRes),
            colorFilter = ColorFilter.tint(tint),
            contentDescription = null,
            contentScale = ContentScale.Fit,
            modifier = GlanceModifier.size(buttonHeight * 0.34f),
          )
        }
      }
    }
  }
}

internal const val kLogTag = "NamidaWidget"

private val kMediaActionParam = ActionParameters.Key<Int>("t")
private val kCustomActionParam = ActionParameters.Key<String>("c")

/** kept in sync with `HomeWidgetController` on the dart side. */
private const val kActionShuffle = "namida_widget_shuffle"
private const val kActionCycleRepeat = "namida_widget_repeat"

class MediaButtonAction : ActionCallback {
  override suspend fun onAction(
    context: Context,
    glanceId: GlanceId,
    parameters: ActionParameters,
  ) {
    parameters[kMediaActionParam]?.let {
      sendMediaButtonIntent(context, it)
      return
    }
    parameters[kCustomActionParam]?.let { sendAudioServiceCustomAction(it) }
  }
}

// ================================ sizing ================================

internal fun WidgetLayout.resolveFor(w: Dp, h: Dp): WidgetLayout =
  when (this) {
    WidgetLayout.AUTO ->
      when {
        h < 72.dp || w < 140.dp -> WidgetLayout.COMPACT
        h >= 150.dp && w < h * 1.7f -> WidgetLayout.CARD
        else -> WidgetLayout.ROW
      }
    else -> this
  }

private fun WidgetLayout.artworkSizeOf(w: Dp, h: Dp, config: NamidaWidgetConfig): Dp {
  val scale = config.artworkScale / 100f
  val base =
    when (this) {
      WidgetLayout.CARD -> minOf(w * 0.66f, h * 0.56f)
      WidgetLayout.COMPACT -> minOf(w * 0.34f, h * 0.92f)
      else -> minOf(w * 0.44f, h * 0.90f)
    }
  // -- never let it eat the whole widget once scaled up
  return minOf(base * scale, w * 0.72f, h * 0.94f).clampAtLeast(24.dp)
}

@Composable
private fun GlanceModifier.tapAction(
  context: Context,
  action: TapAction,
  interactive: Boolean,
  rippleRes: Int = NoRippleOverride,
): GlanceModifier {
  if (!interactive || action == TapAction.NONE) return this
  return when (action) {
    TapAction.PLAY_PAUSE ->
      clickable(
        onClick =
          actionRunCallback<MediaButtonAction>(
            actionParametersOf(kMediaActionParam to KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
          ),
        rippleOverride = rippleRes,
      )
    else -> clickable(rippleOverride = rippleRes) { _startCustomActivity<NamidaMainActivity>(context) }
  }
}

// ================================ artwork ================================

internal class DecodedArtwork(
  val key: String,
  val bitmap: Bitmap,
  val mainColor: Int?,
  val accentColor: Int?,
)

internal object ArtworkStore {
  /**
   * buckets keep the caches warm while the widget is being resized. capped low on purpose:
   * every bitmap here crosses the RemoteViews IPC on each update, which has a ~1mb budget.
   */
  private val kSizeBuckets = intArrayOf(96, 128, 160, 200, 256, 320)
  private const val kBackdropMaxPx = 180f

  private val decodedCache = LruMap<String, DecodedArtwork>(2)
  private val artworkCache = LruMap<String, Bitmap>(3)
  private val backdropCache = LruMap<String, Bitmap>(2)

  fun evict() {
    decodedCache.clear()
    artworkCache.clear()
    backdropCache.clear()
  }

  private fun bucketOf(targetPx: Int) = kSizeBuckets.firstOrNull { it >= targetPx } ?: kSizeBuckets.last()

  fun decode(context: Context, imagePath: String?, targetPx: Int): DecodedArtwork? {
    if (imagePath == null) return null
    val bucket = bucketOf(targetPx)
    val key = "$imagePath|$bucket"
    decodedCache[key]?.let { return it }

    val bitmap =
      try {
        decodeSampledBitmap(context, imagePath, bucket)
      } catch (_: Throwable) {
        null
      } ?: return null

    val palette =
      try {
        Palette.from(bitmap).resizeBitmapArea(64 * 64).maximumColorCount(12).generate()
      } catch (_: Throwable) {
        null
      }
    val main =
      palette?.let { it.getMutedColor(0).nullIfZero() ?: it.getDominantColor(0).nullIfZero() }
    val accent =
      palette?.let {
        it.getVibrantColor(0).nullIfZero()
          ?: it.getLightVibrantColor(0).nullIfZero()
          ?: it.getDarkVibrantColor(0).nullIfZero()
      } ?: main

    return DecodedArtwork(key, bitmap, main, accent).also { decodedCache[key] = it }
  }

  fun artwork(
    context: Context,
    decoded: DecodedArtwork?,
    artSize: Dp,
    config: NamidaWidgetConfig,
    colors: NamidaWidgetColors,
  ): Bitmap {
    val sizePx = bucketOf(artSize.toPxInt(context))
    val effectColor = colors.accentColor.toArgb()
    val placeholder = colors.imageColor.toArgb()
    val key =
      "${decoded?.key}|$sizePx|${config.artworkRounding}|${config.artworkEffect}|$effectColor|$placeholder"
    artworkCache[key]?.let { return it }

    return ImageWrapper.buildArtwork(
        source = decoded?.bitmap,
        sizePx = sizePx,
        roundingFraction = config.artworkRounding / 100f,
        effect = config.artworkEffect,
        effectColor = effectColor,
        placeholderColor = placeholder,
      )
      .also { artworkCache[key] = it }
  }

  fun backdrop(
    context: Context,
    decoded: DecodedArtwork?,
    w: Dp,
    h: Dp,
    config: NamidaWidgetConfig,
    colors: NamidaWidgetColors,
  ): Bitmap? {
    val source = decoded?.bitmap
    val kind =
      if (config.backdrop == WidgetBackdrop.BLURRED_ARTWORK && source == null) WidgetBackdrop.SOLID
      else config.backdrop
    if (kind == WidgetBackdrop.SOLID) return null

    val scale = kBackdropMaxPx / maxOf(w.value, h.value, 1f)
    val bw = (w.value * scale).toInt().coerceAtLeast(1)
    val bh = (h.value * scale).toInt().coerceAtLeast(1)
    val base = colors.boxColor.toArgb()
    val accent = colors.accentColor.toArgb()
    val key =
      "${decoded?.key}|$bw|$bh|$kind|$base|$accent|${config.cornerRadius}|${config.backgroundOpacity}"
    backdropCache[key]?.let { return it }

    return ImageWrapper.buildBackdrop(
        widthPx = bw,
        heightPx = bh,
        cornerPx = config.cornerRadius * scale,
        kind = kind,
        artwork = source,
        baseColor = base,
        accentColor = accent,
        opacityPercent = config.backgroundOpacity,
      )
      .also { backdropCache[key] = it }
  }
}

private class LruMap<K, V>(private val maxSize: Int) {
  private val map =
    object : LinkedHashMap<K, V>(maxSize + 1, 0.75f, true) {
      override fun removeEldestEntry(eldest: MutableMap.MutableEntry<K, V>) = size > maxSize
    }

  @Synchronized operator fun get(key: K): V? = map[key]

  @Synchronized operator fun set(key: K, value: V) {
    map[key] = value
  }

  @Synchronized fun clear() = map.clear()
}

private fun Int.nullIfZero(): Int? = if (this == 0) null else this

// ================================ misc ================================

/**
 * shuffle & repeat have no media keycode, so they go straight to the audio service as custom
 * actions. no-op when nothing is playing, since there'd be no queue to act on anyway.
 */
fun sendAudioServiceCustomAction(action: String) {
  val service = getAudioServiceInstance() ?: return
  // -- ends up on a method channel, has to be the main thread
  Handler(Looper.getMainLooper()).post {
    try {
      service.handleOnCustomAction(action, null)
    } catch (_: Throwable) {}
  }
}

fun sendMediaButtonIntent(context: Context, keyCode: Int) {
  NamidaConstants.selfSentMediaCommand = true
  val isCreated =
    NamidaMainActivity.currentLifecycle?.currentState?.isAtLeast(Lifecycle.State.CREATED) == true
  if (!isCreated) {
    _startCustomActivity<NamidaMainActivity>(context, isWakeIntent = true)
  }

  val intent =
    Intent(Intent.ACTION_MEDIA_BUTTON).apply {
      setPackage(context.packageName)
      putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
    }
  context.sendBroadcast(intent)
}

inline fun <reified T : Activity> _startCustomActivity(
  context: Context,
  uri: Uri? = null,
  isWakeIntent: Boolean = false,
) {
  val intentAction =
    if (isWakeIntent) NamidaConstants.BABE_WAKE_UP else NamidaConstants.ACTION_CUSTOM_START
  val intent =
    Intent(context, T::class.java).apply {
      data = uri
      action = intentAction
      flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION
    }
  context.startActivity(intent)
}

internal fun WidgetTheme.isDark(context: Context): Boolean =
  when (this) {
    WidgetTheme.LIGHT -> false
    WidgetTheme.DARK -> true
    WidgetTheme.SYSTEM ->
      context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
        Configuration.UI_MODE_NIGHT_YES
  }

internal fun Dp.toPxInt(context: Context): Int {
  val density = context.resources.displayMetrics.density
  return (this.value * density).toInt()
}

private fun Dp.clampDp(min: Dp, max: Dp): Dp = if (this < min) min else if (this > max) max else this

private fun Dp.clampAtLeast(min: Dp): Dp = if (this < min) min else this

private fun decodeSampledBitmap(context: Context, imagePath: String, maxPx: Int): Bitmap? {
  val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
  if (imagePath.startsWith("content://")) {
    val uri = Uri.parse(imagePath)
    context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) }
  } else {
    BitmapFactory.decodeFile(imagePath, opts)
  }

  opts.inSampleSize = calculateInSampleSize(opts, maxPx, maxPx)
  opts.inJustDecodeBounds = false

  return if (imagePath.startsWith("content://")) {
    val uri = Uri.parse(imagePath)
    context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) }
  } else {
    BitmapFactory.decodeFile(imagePath, opts)
  }
}

private fun calculateInSampleSize(opts: BitmapFactory.Options, reqW: Int, reqH: Int): Int {
  val (h, w) = opts.outHeight to opts.outWidth
  var inSampleSize = 1
  if (h > reqH || w > reqW) {
    val halfH = h / 2
    val halfW = w / 2
    while (halfH / inSampleSize >= reqH && halfW / inSampleSize >= reqW) {
      inSampleSize *= 2
    }
  }
  return inSampleSize
}
