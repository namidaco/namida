package com.msob7y.namida.glance

import HomeWidgetGlanceState
import HomeWidgetGlanceStateDefinition
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import androidx.lifecycle.Lifecycle
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

  @Composable
  private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {

    val data = currentState.preferences

    val title = data.getString("title", "")!!
    val message = data.getString("message", "")!!
    val isPlaying = data.getBoolean("playing", false)
    val isFav = data.getBoolean("favourite", false)
    val imagePath = data.getString("image", null)

    val imageSize = 84.dp
    val imageCornerRadiusFloat = 64f

    if (imagePath == null) {
      _currentImageProviderWrapper = null
    } else {
      if (_currentImageProviderWrapper == null ||
        _latestImagePath != imagePath ||
        data.getBoolean("evict", false)
      ) {
        _currentImageProviderWrapper?.bitmap?.recycle()
        try {
          val bitmap = BitmapFactory.decodeFile(imagePath)
          val roundedBitmap = bitmap.toRoundedBitmap(imageCornerRadiusFloat)
          // TODO: provide good color
          _currentImageProviderWrapper = ImageProviderWrapper(roundedBitmap, null)
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
        .fillMaxWidth()
        .padding(12.dp)
        .clickable { _startCustomActivity<NamidaMainActivity>(context) }
    ) {
      Row(
        verticalAlignment = Alignment.Vertical.CenterVertically,
      ) {

        Image(
          androidx.glance.ImageProvider(
            finalBitmap
          ),
          null,
          modifier = GlanceModifier.fillMaxHeight().size(imageSize)
        )

        HorizontalSpace(12)

        Column(
          verticalAlignment = Alignment.Vertical.CenterVertically,
          horizontalAlignment = Alignment.Horizontal.Start,
        ) {
          Spacer(GlanceModifier.height(4.dp))
          Text(
            title,
            style =
            TextStyle(
              fontSize = 15.sp,
              fontWeight = FontWeight.Bold,
              color = ColorProvider(titleColor)
            ),
            maxLines = 1,
          )
          Text(
            message,
            style =
            TextStyle(
              fontSize = 14.sp,
              fontWeight = FontWeight.Medium,
              color = ColorProvider(subtitleColor)
            ),
            maxLines = 1,
          )

          Spacer(GlanceModifier.height(4.dp))
          Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.Vertical.CenterVertically,
            horizontalAlignment = Alignment.Start,
          ) {
            val additionalModifier =
              GlanceModifier.padding(6.dp).width(38.dp).height(33.dp)
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

            HorizontalSpace(4)
            MediaControlButton(
              color = iconsColor,
              drawableRes = com.msob7y.namida.R.drawable.previous,
              contentDescription = "Previous",
              keyEvent = KeyEvent.KEYCODE_MEDIA_PREVIOUS,
              additionalModifier = additionalModifier
            )
            HorizontalSpace(4)
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
            HorizontalSpace(4)
            MediaControlButton(
              color = iconsColor,
              drawableRes = com.msob7y.namida.R.drawable.next,
              contentDescription = "Next",
              keyEvent = KeyEvent.KEYCODE_MEDIA_NEXT,
              additionalModifier = additionalModifier
            )
          }

          Spacer(GlanceModifier.height(4.dp))
        }
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
