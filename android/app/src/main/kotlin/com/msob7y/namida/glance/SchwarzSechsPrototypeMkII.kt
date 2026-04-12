package com.msob7y.namida.glance

import es.antonborri.home_widget.HomeWidgetGlanceState 
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition 
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.KeyEvent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.LocalSize
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.lifecycle.Lifecycle
import androidx.palette.graphics.Palette
import com.msob7y.namida.NamidaConstants
import com.msob7y.namida.NamidaMainActivity

class SchwarzSechsPrototypeMkII : GlanceAppWidget() {

  /** Needed for Updating */
  override val stateDefinition = HomeWidgetGlanceStateDefinition()

  override suspend fun provideGlance(context: Context, id: GlanceId) {
    provideContent { GlanceContent(context, currentState()) }
  }

  private var _latestImagePath: String? = null
  private var _currentImageProviderWrapper: ImageProviderWrapper? = null
  private var _fallbackImageProvider: Bitmap? = null

  override val sizeMode = SizeMode.Responsive(
    setOf(
      DpSize(180.dp, 80.dp),
      DpSize(180.dp, 110.dp),
      DpSize(270.dp, 80.dp),
      DpSize(270.dp, 110.dp),
      DpSize(360.dp, 80.dp),
      DpSize(360.dp, 110.dp),
      DpSize(400.dp, 80.dp),
      DpSize(400.dp, 130.dp),
    )
  )

  @Composable
  private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {

    val data = currentState.preferences

    val title = data.getString("title", "")!!
    val message = data.getString("message", "")!!
    val isPlaying = data.getBoolean("playing", false)
    val isFav = data.getBoolean("favourite", false)
    val imagePath = data.getString("image", null)

    val size = LocalSize.current
    val w = size.width
    val h = size.height

    val imageCornerRadiusFloat = 64f
    val buttonHeight = h * 0.35f
    val buttonWidth = buttonHeight * 1.1f
    val titleFontSize = (h.value * 0.20f).sp
    val subtitleFontSize = (h.value * 0.18f).sp
    val padding = w * 0.06f
    val gapSmall = w * 0.018f
    val imageSize = minOf(w, h) * 0.95f


    if (imagePath == null) {
      _currentImageProviderWrapper = null
    } else {
      if (_currentImageProviderWrapper == null ||
        _latestImagePath != imagePath ||
        data.getBoolean("evict", false)
      ) {
        _currentImageProviderWrapper?.bitmap?.recycle()
        try {
          val targetPx = imageSize.toPxInt(context) * 2
          val bitmap = try {
            decodeSampledBitmap(context, imagePath, targetPx)
          } catch (_: Exception) {
            null
          }
          if (bitmap != null) {
            val roundedBitmap = bitmap.toRoundedBitmap(imageCornerRadiusFloat)
            val mainColor: Int = Palette.from(bitmap) 
                  .maximumColorCount(8)
                  .generate()
                  .getMutedColor(0)
            _currentImageProviderWrapper = ImageProviderWrapper(
              roundedBitmap,
              mainColor.takeIf { it != 0 }
            )
            bitmap.recycle()
          } else {
            _currentImageProviderWrapper = null
          }
        } catch (_: Exception) {
          _currentImageProviderWrapper = null
        }
      }
    }

    val isDark = isDarkModeEnabled(context)
    val mainColor = _currentImageProviderWrapper?.mainColor;
    val colors: NamidaWidgetColors = remember(mainColor, isDark) { NamidaWidgetColors.buildColors(mainColor, isDark) }

    val boxColor = colors.boxColor
    val imageColor = colors.imageColor
    val titleColor = colors.titleColor
    val subtitleColor = colors.subtitleColor
    val iconsColor = colors.iconsColor

    if (_currentImageProviderWrapper == null) {
      if (_fallbackImageProvider == null) {
        val imageSizeInt = imageSize.toPxInt(context)
        val bitmap =
          ImageWrapper.createRoundedBitmap(
            imageSizeInt * 2,
            imageSizeInt * 2,
            imageCornerRadiusFloat,
            imageColor.toArgb()
          )
        _fallbackImageProvider = bitmap
      }
    }

    val finalBitmap = _currentImageProviderWrapper?.bitmap ?: _fallbackImageProvider!!
    _latestImagePath = imagePath


    Box(
      contentAlignment = Alignment.CenterStart,
      modifier =
      GlanceModifier.cornerRadius(24.dp)
        .background(boxColor)
        .fillMaxSize()
        .clickable { _startCustomActivity<NamidaMainActivity>(context) }
    ) {
      Row(
        verticalAlignment = Alignment.Vertical.CenterVertically,
        modifier = GlanceModifier.fillMaxWidth().height(h),
      ) {
        HorizontalSpace(padding.value.toInt())

        Image(
          androidx.glance.ImageProvider(
            finalBitmap
          ),
          null,
          modifier = GlanceModifier.fillMaxHeight().size(imageSize)
        )

        HorizontalSpace((gapSmall * 2).value.toInt())

        Column(
          verticalAlignment = Alignment.Vertical.CenterVertically,
          horizontalAlignment = Alignment.Horizontal.Start,
          modifier = GlanceModifier.fillMaxWidth().fillMaxHeight(),
        ) {
          Spacer(GlanceModifier.height(h * 0.04f))
          Text(
            title,
            style = TextStyle(
              fontSize = titleFontSize,
              fontWeight = FontWeight.Bold,
              color = ColorProvider(titleColor)
            ),
            maxLines = 1,
          )
          Text(
            message,
            style = TextStyle(
              fontSize = subtitleFontSize,
              fontWeight = FontWeight.Medium,
              color = ColorProvider(subtitleColor)
            ),
            maxLines = 1,
          )

          Spacer(GlanceModifier.height(h * 0.04f))
          Row(
            verticalAlignment = Alignment.Vertical.CenterVertically,
            horizontalAlignment = Alignment.Start,
          ) {
            val additionalModifier =
              GlanceModifier.padding(buttonHeight * 0.15f).width(buttonWidth).height(buttonHeight)
            if (isFav)
              MediaControlButton(
                color = iconsColor,
                drawableRes = com.msob7y.namida.R.drawable.unheart,
                contentDescription = "Unfavourite",
                keyEvent = KeyEvent.KEYCODE_MEDIA_FAST_FORWARD,
                additionalModifier = additionalModifier
              )
            else
              MediaControlButton(
                color = iconsColor,
                drawableRes = com.msob7y.namida.R.drawable.heart,
                contentDescription = "Set Favourite",
                keyEvent = KeyEvent.KEYCODE_MEDIA_REWIND,
                additionalModifier = additionalModifier
              )

            HorizontalSpace(gapSmall.value.toInt())
            MediaControlButton(
              color = iconsColor,
              drawableRes = com.msob7y.namida.R.drawable.previous,
              contentDescription = "Previous",
              keyEvent = KeyEvent.KEYCODE_MEDIA_PREVIOUS,
              additionalModifier = additionalModifier
            )
            HorizontalSpace(gapSmall.value.toInt())
            if (isPlaying)
              MediaControlButton(
                color = iconsColor,
                drawableRes = com.msob7y.namida.R.drawable.pause,
                contentDescription = "Pause",
                keyEvent = KeyEvent.KEYCODE_MEDIA_PAUSE,
                additionalModifier = additionalModifier
              )
            else
              MediaControlButton(
                color = iconsColor,
                drawableRes =
                com.msob7y.namida.R.drawable.play,
                contentDescription = "Play",
                keyEvent = KeyEvent.KEYCODE_MEDIA_PLAY,
                additionalModifier = additionalModifier
              )
            HorizontalSpace(gapSmall.value.toInt())
            MediaControlButton(
              color = iconsColor,
              drawableRes = com.msob7y.namida.R.drawable.next,
              contentDescription = "Next",
              keyEvent = KeyEvent.KEYCODE_MEDIA_NEXT,
              additionalModifier = additionalModifier
            )
          }

          Spacer(GlanceModifier.height(h * 0.04f))
        }
        
        HorizontalSpace(padding.value.toInt())
      }
    }

  }
}

fun sendMediaButtonIntent(context: Context, keyCode: Int) {
  val isCreated =
    NamidaMainActivity.currentLifecycle?.currentState?.isAtLeast(Lifecycle.State.CREATED) ==
        true
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

private class ModifierClick {
  companion object {
    fun mediaClick(event: Int): GlanceModifier {
      return GlanceModifier.clickable(
        rippleOverride = com.msob7y.namida.R.drawable.ripple,
        onClick =
        actionRunCallback<MediaButtonAction>(
          actionParametersOf(ActionParameters.Key<Int>("t") to event)
        )
      )
    }

    @Composable
    fun startActivity(context: Context, message: String): GlanceModifier {
      return GlanceModifier.clickable {
        _startCustomActivity<NamidaMainActivity>(
          context,
          Uri.parse("home_widget://msg?t=$message")
        )
      }
    }
  }
}

@Composable
fun MediaControlButton(
  color: Color,
  drawableRes: Int,
  contentDescription: String,
  keyEvent: Int,
  additionalModifier: GlanceModifier,
) {
  Image(
    provider = androidx.glance.ImageProvider(drawableRes),
    colorFilter = androidx.glance.ColorFilter.tint(ColorProvider(color)),
    contentDescription = contentDescription,
    modifier = ModifierClick.mediaClick(keyEvent).then(additionalModifier)
  )
}

class MediaButtonAction : ActionCallback {
  override suspend fun onAction(
    context: Context,
    glanceId: GlanceId,
    parameters: ActionParameters,
  ) {
    val event = parameters[ActionParameters.Key<Int>("t")] ?: return
    sendMediaButtonIntent(context, event)
  }
}

private class ImageProviderWrapper(val bitmap: Bitmap, val mainColor: Int?) { }

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

@Composable
private fun HorizontalSpace(width: Int): Unit {
  return Spacer(GlanceModifier.width(width.dp))
}

private fun Dp.toPxInt(context: Context): Int {
  val density = context.resources.displayMetrics.density
  return (this.value * density).toInt()
}

private fun isDarkModeEnabled(context: Context): Boolean {
  return context.resources.configuration.uiMode and
      Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
}


private fun decodeSampledBitmap(context: Context, imagePath: String, maxPx: Int): Bitmap? {
  val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
  if (imagePath.startsWith("content://")) {
    val uri = Uri.parse(imagePath)
    context.contentResolver.openInputStream(uri)?.use {
      BitmapFactory.decodeStream(it, null, opts)
    }
  } else {
    BitmapFactory.decodeFile(imagePath, opts)
  }

  opts.inSampleSize = calculateInSampleSize(opts, maxPx, maxPx)
  opts.inJustDecodeBounds = false

  return if (imagePath.startsWith("content://")) {
    val uri = Uri.parse(imagePath)
    context.contentResolver.openInputStream(uri)?.use {
      BitmapFactory.decodeStream(it, null, opts)
    }
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