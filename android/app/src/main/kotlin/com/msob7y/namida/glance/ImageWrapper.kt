package com.msob7y.namida.glance

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.glance.appwidget.cornerRadius
import androidx.glance.layout.height
import androidx.glance.layout.width

class ImageWrapper {
  companion object {
    fun createRoundedBitmap(width: Int, height: Int, radius: Float, color: Color): Bitmap {
      val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
      val canvas = Canvas(bitmap)
      val paint = Paint(Paint.ANTI_ALIAS_FLAG)
      paint.color = color.toArgb()

      val rect = RectF(0f, 0f, width.toFloat(), height.toFloat())
      val path = Path().apply { addRoundRect(rect, radius, radius, Path.Direction.CW) }

      canvas.drawPath(path, paint)

      return bitmap
    }
  }
}

fun Bitmap.toRoundedBitmap(cornerRadius: Float): Bitmap {
  // -- ensure the bitmap is square
  val size = if (width < height) width else height
  val xOffset = (width - size) / 2
  val yOffset = (height - size) / 2
  val squareBitmap = Bitmap.createBitmap(this, xOffset, yOffset, size, size)

  val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
  val canvas = Canvas(output)
  val paint = Paint(Paint.ANTI_ALIAS_FLAG)

  val rect = RectF(0f, 0f, size.toFloat(), size.toFloat())
  val path = Path().apply { addRoundRect(rect, cornerRadius, cornerRadius, Path.Direction.CW) }

  canvas.drawPath(path, paint)
  paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
  canvas.drawBitmap(squareBitmap, 0f, 0f, paint)

  return output
}
