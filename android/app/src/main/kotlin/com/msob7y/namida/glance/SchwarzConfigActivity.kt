package com.msob7y.namida.glance

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.Switch
import android.widget.TextView
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.appwidget.ExperimentalGlanceRemoteViewsApi
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceRemoteViews
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream

// config by claude
class SchwarzConfigActivity : Activity() {

  private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
  private var targetWidgetIds = intArrayOf()
  private var config = NamidaWidgetConfig.defaults

  private val launchedByHost
    get() = appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID

  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
  @OptIn(ExperimentalGlanceRemoteViewsApi::class)
  private val glanceRemoteViews = GlanceRemoteViews()
  private var previewJob: Job? = null

  private lateinit var palette: ConfigPalette
  private lateinit var previewHost: FrameLayout
  private lateinit var payload: WidgetPayload
  private var previewSizes = emptyList<Pair<String, DpSize>>()
  private var previewSizeIndex = 0

  /** rebuilt on every change so option rows reflect the freshly applied config. */
  private lateinit var optionsHost: LinearLayout

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    appWidgetId =
      intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        ?: AppWidgetManager.INVALID_APPWIDGET_ID
    // -- some launchers (hyperos among them) never start this from the widget picker, so it
    // -- doubles as an in-app screen that edits every placed widget at once
    targetWidgetIds = if (launchedByHost) intArrayOf(appWidgetId) else placedWidgetIds()
    if (launchedByHost) setResult(RESULT_CANCELED, resultIntent())

    config =
      NamidaWidgetConfig.load(
        this,
        targetWidgetIds.firstOrNull() ?: NamidaWidgetConfig.DEFAULTS_ID,
      )
    palette = ConfigPalette.of(isSystemDark())
    payload = loadPreviewPayload()
    previewSizes = buildPreviewSizes()

    setContentView(buildRoot())
    rebuildOptions()
    schedulePreview()
  }

  override fun onDestroy() {
    scope.cancel()
    super.onDestroy()
  }

  // ================================ layout ================================

  private fun buildRoot(): View {
    val root =
      LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        setBackgroundColor(palette.background)
        fitsSystemWindows = true
      }

    val pinned =
      LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(dp(16), dp(16), dp(16), 0)
      }
    pinned.addView(buildHeader())
    pinned.addView(buildPreviewCard())
    root.addView(pinned, matchParent(wrapHeight = true))

    val scroll =
      ScrollView(this).apply {
        isFillViewport = true
        clipToPadding = false
        setPadding(dp(16), dp(4), dp(16), dp(16))
      }
    optionsHost = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
    scroll.addView(optionsHost, matchParent(wrapHeight = true))
    root.addView(scroll, LinearLayout.LayoutParams(MATCH, 0, 1f))

    root.addView(buildActionBar())
    return root
  }

  private fun buildHeader(): View {
    val column = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
    column.addView(
      TextView(this).apply {
        text = "Widget settings"
        setTextColor(palette.text)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 21f)
        typeface = Typeface.DEFAULT_BOLD
      }
    )
    val params = matchParent(wrapHeight = true)
    params.bottomMargin = dp(14)
    column.layoutParams = params
    return column
  }

  /**
   * ids stay allocated when a placement is aborted half way, and the system only reaps them
   * lazily. one that was never laid out reports no size, so it can be told apart from a live one.
   */
  private fun placedWidgetIds(): IntArray =
    try {
      val manager = AppWidgetManager.getInstance(this)
      manager
        .getAppWidgetIds(ComponentName(this, SchwarzReceiver::class.java))
        .filter {
          val options = manager.getAppWidgetOptions(it)
          options != null &&
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) > 0
        }
        .toIntArray()
    } catch (_: Throwable) {
      intArrayOf()
    }

  private fun buildPreviewCard(): View {
    val card =
      LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER_HORIZONTAL
        setPadding(dp(14), dp(14), dp(14), dp(10))
        background =
          GradientDrawable().apply {
            cornerRadius = dp(20).toFloat()
            colors = intArrayOf(palette.previewTop, palette.previewBottom)
            orientation = GradientDrawable.Orientation.TL_BR
          }
      }

    previewHost =
      FrameLayout(this).apply {
        // -- purely a mockup, no touch handling needed
        isEnabled = false
      }
    card.addView(previewHost, FrameLayout.LayoutParams(WRAP, WRAP))

    if (previewSizes.size > 1) {
      val chips = chipRow(previewSizes.map { it.first }, previewSizeIndex) { index ->
        previewSizeIndex = index
        schedulePreview()
      }
      chips.setPadding(0, dp(10), 0, 0)
      card.addView(chips, matchParent(wrapHeight = true))
    }

    val params = matchParent(wrapHeight = true)
    params.bottomMargin = dp(18)
    card.layoutParams = params
    return card
  }

  private fun buildActionBar(): View {
    val bar =
      LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        setPadding(dp(16), dp(10), dp(16), dp(16))
        setBackgroundColor(palette.background)
      }
    bar.addView(
      flatButton("Reset") {
        config = NamidaWidgetConfig.defaults
        rebuildOptions()
        schedulePreview()
      }
    )
    bar.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
    bar.addView(flatButton("Cancel") { finish() })
    bar.addView(filledButton("Save") { save() })
    return bar
  }

  // ================================ options ================================

  private fun rebuildOptions() {
    optionsHost.removeAllViews()

    optionsHost.section("Appearance")
    optionsHost.segmented("Theme", WidgetTheme.entries, config.theme, ::labelOf) {
      config = config.copy(theme = it)
    }
    optionsHost.switch("Colors from artwork", config.artworkColors) {
      config = config.copy(artworkColors = it)
    }
    optionsHost.segmented("Background", WidgetBackdrop.entries, config.backdrop, ::labelOf) {
      config = config.copy(backdrop = it)
    }
    optionsHost.segmented("Artwork effect", ArtworkEffect.entries, config.artworkEffect, ::labelOf) {
      config = config.copy(artworkEffect = it)
    }
    optionsHost.slider("Background opacity", config.backgroundOpacity, 20, 100, "%") {
      config = config.copy(backgroundOpacity = it)
    }
    optionsHost.slider("Corner radius", config.cornerRadius, 0, 40, "dp") {
      config = config.copy(cornerRadius = it)
    }
    optionsHost.slider("Artwork rounding", config.artworkRounding, 0, 50, "%") {
      config = config.copy(artworkRounding = it)
    }

    optionsHost.section("Layout")
    optionsHost.segmented("Arrangement", WidgetLayout.entries, config.layout, ::labelOf) {
      config = config.copy(layout = it)
    }
    optionsHost.slider("Content size", config.contentScale, 70, 150, "%") {
      config = config.copy(contentScale = it)
    }
    optionsHost.slider("Artwork size", config.artworkScale, 60, 140, "%") {
      config = config.copy(artworkScale = it)
    }
    optionsHost.switch("Artwork", config.showArtwork) { config = config.copy(showArtwork = it) }
    optionsHost.switch("Title", config.showTitle) { config = config.copy(showTitle = it) }
    optionsHost.switch("Subtitle", config.showSubtitle) { config = config.copy(showSubtitle = it) }

    optionsHost.section("Controls")
    optionsHost.switch("Favourite", config.showFavourite) {
      config = config.copy(showFavourite = it)
    }
    optionsHost.switch("Shuffle queue", config.showShuffle) { config = config.copy(showShuffle = it) }
    optionsHost.switch("Previous", config.showPrevious) { config = config.copy(showPrevious = it) }
    optionsHost.switch("Play / Pause", config.showPlayPause) {
      config = config.copy(showPlayPause = it)
    }
    optionsHost.switch("Next", config.showNext) { config = config.copy(showNext = it) }
    optionsHost.switch("Repeat mode", config.showRepeat) { config = config.copy(showRepeat = it) }
    optionsHost.switch("Stop", config.showStop) { config = config.copy(showStop = it) }

    optionsHost.section("Tap actions")
    optionsHost.segmented("Widget", TapAction.entries, config.backgroundTapAction, ::labelOf) {
      config = config.copy(backgroundTapAction = it)
    }
    optionsHost.segmented("Artwork", TapAction.entries, config.artworkTapAction, ::labelOf) {
      config = config.copy(artworkTapAction = it)
    }
  }

  private fun labelOf(value: Enum<*>): String =
    when (value) {
      WidgetTheme.SYSTEM -> "System"
      WidgetTheme.LIGHT -> "Light"
      WidgetTheme.DARK -> "Dark"
      WidgetBackdrop.SOLID -> "Solid"
      WidgetBackdrop.GRADIENT -> "Gradient"
      WidgetBackdrop.BLURRED_ARTWORK -> "Blurred art"
      ArtworkEffect.NONE -> "None"
      ArtworkEffect.GLOW -> "Glow"
      ArtworkEffect.SHADOW -> "Shadow"
      WidgetLayout.AUTO -> "Auto"
      WidgetLayout.ROW -> "Row"
      WidgetLayout.CARD -> "Card"
      WidgetLayout.COMPACT -> "Compact"
      TapAction.OPEN_APP -> "Open app"
      TapAction.PLAY_PAUSE -> "Play / Pause"
      TapAction.NONE -> "Nothing"
      else -> value.name
    }

  // ================================ preview ================================

  private fun schedulePreview() {
    previewJob?.cancel()
    previewJob =
      scope.launch {
        delay(60)
        renderPreview()
      }
  }

  @OptIn(ExperimentalGlanceRemoteViewsApi::class)
  private suspend fun renderPreview() {
    val size = previewSizes.getOrNull(previewSizeIndex)?.second ?: return
    val currentConfig = config
    val remoteViews =
      try {
        // -- composing decodes & draws the artwork, keep it off the main thread
        withContext(Dispatchers.Default) {
          glanceRemoteViews
            .compose(context = this@SchwarzConfigActivity, size = size) {
              NamidaWidgetContent(
                this@SchwarzConfigActivity,
                payload,
                currentConfig,
                interactive = false,
              )
            }
            .remoteViews
        }
      } catch (_: Throwable) {
        return
      }

    val view =
      try {
        remoteViews.apply(this, previewHost)
      } catch (_: Throwable) {
        return
      }
    previewHost.removeAllViews()
    previewHost.addView(
      view,
      FrameLayout.LayoutParams(dp(size.width.value.toInt()), dp(size.height.value.toInt())),
    )
  }

  private fun buildPreviewSizes(): List<Pair<String, DpSize>> {
    val screenWidthDp = resources.configuration.screenWidthDp
    val wide = (screenWidthDp - 96).coerceIn(170, 260)
    return listOf(
      "Wide" to DpSize(wide.dp, (wide * 0.42f).dp),
      "Large" to DpSize(wide.dp, (wide * 0.88f).dp),
      "Small" to DpSize((wide * 0.52f).dp, (wide * 0.22f).dp),
    )
  }

  private fun loadPreviewPayload(): WidgetPayload {
    val live =
      try {
        WidgetPayload.from(HomeWidgetGlanceState(HomeWidgetPlugin.getData(this)))
      } catch (_: Throwable) {
        null
      }
    return WidgetPayload(
      title = live?.title?.takeIf { it.isNotBlank() } ?: "Namida",
      subtitle = live?.subtitle?.takeIf { it.isNotBlank() } ?: "Artist • Album",
      isPlaying = live?.isPlaying ?: false,
      isFav = live?.isFav ?: true,
      repeat = live?.repeat ?: WidgetRepeat.ALL,
      repeatCount = live?.repeatCount ?: 3,
      imagePath = live?.imagePath ?: sampleArtworkPath(),
    )
  }

  /** so the artwork effects & blurred backdrop are previewable before anything has been played. */
  private fun sampleArtworkPath(): String? =
    try {
      val file = File(cacheDir, "widget_preview_artwork.png")
      if (!file.exists()) {
        val size = 256
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.shader =
          LinearGradient(
            0f,
            0f,
            size.toFloat(),
            size.toFloat(),
            intArrayOf(0xFFC9A87C.toInt(), 0xFF9B6F8E.toInt(), 0xFF3E4B7A.toInt()),
            null,
            Shader.TileMode.CLAMP,
          )
        canvas.drawRect(0f, 0f, size.toFloat(), size.toFloat(), paint)
        paint.shader = null
        paint.color = 0x33FFFFFF
        canvas.drawCircle(size * 0.72f, size * 0.28f, size * 0.26f, paint)
        canvas.drawCircle(size * 0.22f, size * 0.78f, size * 0.18f, paint)
        FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
      }
      file.absolutePath
    } catch (_: Throwable) {
      null
    }

  // ================================ saving ================================

  private fun save() {
    targetWidgetIds.forEach { NamidaWidgetConfig.save(this, it, config) }
    if (launchedByHost) {
      setResult(RESULT_OK, resultIntent())
    } else {
      // -- also the fallback for widgets that never got configured individually
      NamidaWidgetConfig.save(this, NamidaWidgetConfig.DEFAULTS_ID, config)
    }
    scope.launch {
      try {
        val manager = GlanceAppWidgetManager(this@SchwarzConfigActivity)
        val widget = SchwarzSechsPrototypeMkII()
        targetWidgetIds.forEach { id ->
          try {
            widget.update(this@SchwarzConfigActivity, manager.getGlanceIdBy(id))
          } catch (_: Throwable) {}
        }
      } catch (_: Throwable) {
        // -- the broadcast below is the fallback
      }
      requestWidgetUpdate()
      finish()
    }
  }

  /** glance's own update can be throttled by the launcher, this nudges the receiver directly. */
  private fun requestWidgetUpdate() {
    if (targetWidgetIds.isEmpty()) return
    try {
      sendBroadcast(
        Intent(this, SchwarzReceiver::class.java).apply {
          action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
          putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, targetWidgetIds)
        }
      )
    } catch (_: Throwable) {}
  }

  private fun resultIntent() =
    Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)

  // ================================ view builders ================================

  private fun LinearLayout.section(title: String) {
    val view =
      TextView(context).apply {
        text = title.uppercase()
        setTextColor(palette.accent)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
        letterSpacing = 0.09f
        typeface = Typeface.DEFAULT_BOLD
      }
    val params = matchParent(wrapHeight = true)
    params.topMargin = if (childCount == 0) dp(4) else dp(30)
    params.bottomMargin = dp(10)
    addView(view, params)
  }

  private fun <T : Enum<T>> LinearLayout.segmented(
    label: String,
    values: List<T>,
    selected: T,
    labelOf: (T) -> String,
    onSelect: (T) -> Unit,
  ) {
    addView(rowLabel(label), rowParams())
    val chips =
      chipRow(values.map(labelOf), values.indexOf(selected)) { index ->
        onSelect(values[index])
        schedulePreview()
      }
    val params = matchParent(wrapHeight = true)
    params.topMargin = dp(2)
    params.bottomMargin = dp(8)
    addView(chips, params)
  }

  private fun LinearLayout.switch(label: String, value: Boolean, onChange: (Boolean) -> Unit) {
    val row =
      LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
      }
    row.addView(rowLabel(label), LinearLayout.LayoutParams(0, WRAP, 1f))
    row.addView(
      Switch(context).apply {
        isChecked = value
        setOnCheckedChangeListener { _, checked ->
          onChange(checked)
          schedulePreview()
        }
      }
    )
    addView(row, rowParams())
  }

  private fun LinearLayout.slider(
    label: String,
    value: Int,
    min: Int,
    max: Int,
    suffix: String,
    onChange: (Int) -> Unit,
  ) {
    val header =
      LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
      }
    val valueLabel =
      TextView(context).apply {
        text = "$value$suffix"
        setTextColor(palette.textDim)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
      }
    header.addView(rowLabel(label), LinearLayout.LayoutParams(0, WRAP, 1f))
    header.addView(valueLabel)
    addView(header, rowParams())

    val seek =
      SeekBar(context).apply {
        this.max = max - min
        progress = value - min
        setOnSeekBarChangeListener(
          object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(bar: SeekBar?, progress: Int, fromUser: Boolean) {
              val next = progress + min
              valueLabel.text = "$next$suffix"
              onChange(next)
              schedulePreview()
            }

            override fun onStartTrackingTouch(bar: SeekBar?) = Unit

            override fun onStopTrackingTouch(bar: SeekBar?) = Unit
          }
        )
      }
    addView(seek, matchParent(wrapHeight = true).apply { bottomMargin = dp(8) })
  }

  private fun chipRow(labels: List<String>, selectedIndex: Int, onSelect: (Int) -> Unit): View {
    val row =
      LinearLayout(this).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
      }
    var current = selectedIndex
    val chips =
      labels.mapIndexed { index, label ->
        TextView(this).apply {
          text = label
          gravity = Gravity.CENTER
          setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
          setPadding(dp(14), dp(8), dp(14), dp(8))
          setOnClickListener {
            if (current == index) return@setOnClickListener
            current = index
            onSelect(index)
          }
        }
      }

    fun styleChips() {
      chips.forEachIndexed { index, chip ->
        val selected = index == current
        chip.setTextColor(if (selected) palette.onAccent else palette.textDim)
        chip.background =
          GradientDrawable().apply {
            cornerRadius = dp(14).toFloat()
            if (selected) {
              setColor(palette.accent)
            } else {
              setColor(Color.TRANSPARENT)
              setStroke(dp(1), palette.outline)
            }
          }
      }
    }

    chips.forEachIndexed { index, chip ->
      chip.setOnClickListener {
        if (current == index) return@setOnClickListener
        current = index
        styleChips()
        onSelect(index)
      }
      val params = LinearLayout.LayoutParams(WRAP, WRAP)
      if (index > 0) params.leftMargin = dp(8)
      row.addView(chip, params)
    }
    styleChips()

    return HorizontalScrollView(this).apply {
      isHorizontalScrollBarEnabled = false
      addView(row, FrameLayout.LayoutParams(WRAP, WRAP))
    }
  }

  private fun rowLabel(text: String) =
    TextView(this).apply {
      this.text = text
      setTextColor(palette.text)
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
    }

  private fun flatButton(label: String, onClick: () -> Unit) =
    TextView(this).apply {
      text = label
      gravity = Gravity.CENTER
      setTextColor(palette.textDim)
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
      typeface = Typeface.DEFAULT_BOLD
      setPadding(dp(18), dp(12), dp(18), dp(12))
      setOnClickListener { onClick() }
    }

  private fun filledButton(label: String, onClick: () -> Unit) =
    TextView(this).apply {
      text = label
      gravity = Gravity.CENTER
      setTextColor(palette.onAccent)
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
      typeface = Typeface.DEFAULT_BOLD
      minWidth = dp(132)
      setPadding(dp(28), dp(16), dp(28), dp(16))
      background =
        GradientDrawable().apply {
          cornerRadius = dp(20).toFloat()
          setColor(palette.accent)
        }
      setOnClickListener { onClick() }
      layoutParams = LinearLayout.LayoutParams(WRAP, WRAP).apply { leftMargin = dp(8) }
    }

  private fun rowParams() =
    matchParent(wrapHeight = true).apply {
      topMargin = dp(12)
      bottomMargin = dp(4)
    }

  private fun matchParent(wrapHeight: Boolean) =
    LinearLayout.LayoutParams(MATCH, if (wrapHeight) WRAP else MATCH)

  private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

  private fun isSystemDark(): Boolean =
    resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK ==
      Configuration.UI_MODE_NIGHT_YES

  private companion object {
    const val MATCH = ViewGroup.LayoutParams.MATCH_PARENT
    const val WRAP = ViewGroup.LayoutParams.WRAP_CONTENT
  }
}

private class ConfigPalette(
  val background: Int,
  val text: Int,
  val textDim: Int,
  val accent: Int,
  val onAccent: Int,
  val outline: Int,
  val previewTop: Int,
  val previewBottom: Int,
) {
  companion object {
    fun of(isDark: Boolean): ConfigPalette =
      if (isDark) {
        ConfigPalette(
          background = 0xFF121110.toInt(),
          text = 0xFFEDE8E2.toInt(),
          textDim = 0xFF9C948B.toInt(),
          accent = 0xFFC9B296.toInt(),
          onAccent = 0xFF1A1512.toInt(),
          outline = 0xFF3A342E.toInt(),
          previewTop = 0xFF2A2620.toInt(),
          previewBottom = 0xFF14120F.toInt(),
        )
      } else {
        ConfigPalette(
          background = 0xFFFAF7F3.toInt(),
          text = 0xFF221E1A.toInt(),
          textDim = 0xFF6B635B.toInt(),
          accent = 0xFFB89D7D.toInt(),
          onAccent = 0xFFFFFFFF.toInt(),
          outline = 0xFFD9D0C5.toInt(),
          previewTop = 0xFFE7DDCF.toInt(),
          previewBottom = 0xFFCFC2AF.toInt(),
        )
      }
  }
}
