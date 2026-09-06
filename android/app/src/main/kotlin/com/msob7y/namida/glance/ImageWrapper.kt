package com.msob7y.namida.glance

import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import androidx.core.graphics.ColorUtils

class ImageWrapper {
  companion object {
    /**
     * composes the artwork into a [sizePx] square, optionally surrounded by a glow/shadow.
     * the effect is baked into the same bitmap so the layout doesn't have to reserve extra space.
     */
    fun buildArtwork(
      source: Bitmap?,
      sizePx: Int,
      roundingFraction: Float,
      effect: ArtworkEffect,
      effectColor: Int,
      placeholderColor: Int,
    ): Bitmap {
      val output = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
      val canvas = Canvas(output)
      val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

      val padding = if (effect == ArtworkEffect.NONE) 0f else sizePx * 0.085f
      val artRect = RectF(padding, padding, sizePx - padding, sizePx - padding)
      val radius = artRect.width() * roundingFraction

      if (padding > 0f) {
        fun drawHalo(color: Int, alpha: Int, blur: Float, inset: Float, yOffset: Float) {
          paint.color = ColorUtils.setAlphaComponent(color, alpha)
          paint.maskFilter = BlurMaskFilter(blur, BlurMaskFilter.Blur.NORMAL)
          canvas.drawRoundRect(
            RectF(
              artRect.left + inset,
              artRect.top + inset + yOffset,
              artRect.right - inset,
              artRect.bottom - inset + yOffset,
            ),
            radius,
            radius,
            paint,
          )
        }
        val haloLayer = canvas.saveLayer(null, null)
        if (effect == ArtworkEffect.GLOW) {
          // -- wide soft halo then a tighter core, a single pass reads as a smudge
          drawHalo(effectColor, 120, padding * 1.4f, padding * 0.15f, 0f)
          drawHalo(effectColor, 205, padding * 0.65f, padding * 0.35f, 0f)
        } else {
          drawHalo(0x000000, 150, padding * 0.8f, padding * 0.35f, padding * 0.55f)
        }
        paint.maskFilter = null
        // -- the blur bleeds inwards too, carve out the artwork so it stays strictly behind
        paint.color = -0x1
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_OUT)
        canvas.drawRoundRect(artRect, radius, radius, paint)
        paint.xfermode = null
        canvas.restoreToCount(haloLayer)
      }

      val layer = canvas.saveLayer(artRect, null)
      if (source == null) {
        paint.color = placeholderColor
        canvas.drawRect(artRect, paint)
      } else {
        canvas.drawBitmapCropped(source, artRect, paint)
      }
      canvas.punchOutsideRoundRect(artRect, radius, paint)
      canvas.restoreToCount(layer)

      return output
    }

    /**
     * the widget background. corners are baked in so they hold up on api < 31 where
     * [androidx.glance.appwidget.cornerRadius] can't clip an image background.
     */
    fun buildBackdrop(
      widthPx: Int,
      heightPx: Int,
      cornerPx: Float,
      kind: WidgetBackdrop,
      artwork: Bitmap?,
      baseColor: Int,
      accentColor: Int,
      opacityPercent: Int,
    ): Bitmap {
      val output = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
      val canvas = Canvas(output)
      val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
      val fullRect = RectF(0f, 0f, widthPx.toFloat(), heightPx.toFloat())

      val alpha = (opacityPercent.coerceIn(0, 100) * 255) / 100
      val layer = canvas.saveLayerAlpha(fullRect, alpha)

      when {
        kind == WidgetBackdrop.BLURRED_ARTWORK && artwork != null -> {
          canvas.drawBitmapCropped(artwork.blurred(), fullRect, paint)
          paint.color = ColorUtils.setAlphaComponent(baseColor, 165)
          canvas.drawRect(fullRect, paint)
        }
        kind == WidgetBackdrop.GRADIENT -> {
          paint.shader =
            LinearGradient(
              0f,
              0f,
              widthPx * 0.35f,
              heightPx.toFloat(),
              ColorUtils.blendARGB(accentColor, baseColor, 0.45f),
              baseColor,
              Shader.TileMode.CLAMP,
            )
          canvas.drawRect(fullRect, paint)
          paint.shader = null
        }
        else -> {
          paint.color = baseColor
          canvas.drawRect(fullRect, paint)
        }
      }

      canvas.punchOutsideRoundRect(fullRect, cornerPx, paint)
      canvas.restoreToCount(layer)

      return output
    }
  }
}

/**
 * clears everything outside the rounded rect. drawing the rect itself with DST_IN would leave the
 * corners untouched, since a draw op only ever composites the pixels its own shape covers.
 */
private fun Canvas.punchOutsideRoundRect(rect: RectF, radius: Float, paint: Paint) {
  val path =
    Path().apply {
      addRoundRect(rect, radius, radius, Path.Direction.CW)
      fillType = Path.FillType.INVERSE_WINDING
    }
  paint.shader = null
  paint.color = -0x1
  paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_OUT)
  drawPath(path, paint)
  paint.xfermode = null
}

/** center-crop draw, keeps the source aspect ratio inside [dest]. */
private fun Canvas.drawBitmapCropped(source: Bitmap, dest: RectF, paint: Paint) {
  val scale = maxOf(dest.width() / source.width, dest.height() / source.height)
  val cropW = (dest.width() / scale).toInt().coerceIn(1, source.width)
  val cropH = (dest.height() / scale).toInt().coerceIn(1, source.height)
  val src =
    Rect(
      (source.width - cropW) / 2,
      (source.height - cropH) / 2,
      (source.width + cropW) / 2,
      (source.height + cropH) / 2,
    )
  drawBitmap(source, src, dest, paint)
}

/**
 * downscale-then-upscale blur. bilinear filtering does the smoothing for us, which is far
 * cheaper than a real gaussian pass and indistinguishable at backdrop scale.
 */
private fun Bitmap.blurred(downscaleTo: Int = 16): Bitmap {
  return Bitmap.createScaledBitmap(this, downscaleTo, downscaleTo, true)
}
