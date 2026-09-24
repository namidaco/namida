// by claude
package com.msob7y.namida

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import androidx.annotation.RequiresApi
import java.io.File
import java.io.IOException
import kotlin.math.abs

object ProcessExitReporter {
  private const val PREFS_NAME = "namida_exit_reporter"
  private const val KEY_LAST_TIMESTAMP = "lastTimestamp"
  private const val JAVA_CRASH_FILE_NAME = "last_java_crash.txt"
  private const val MAX_EXIT_INFOS = 16
  private const val MAX_BACKTRACE_FRAMES = 64
  private const val MAX_ANR_LINES = 80
  private const val JAVA_CRASH_MATCH_WINDOW_MS = 10_000L

  private var isJavaCrashRecorderInstalled = false

  fun installJavaCrashRecorder(context: Context) {
    if (isJavaCrashRecorderInstalled) return
    isJavaCrashRecorderInstalled = true
    val file = File(context.filesDir, JAVA_CRASH_FILE_NAME)
    val previousHandler = Thread.getDefaultUncaughtExceptionHandler()
    Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
      try {
        file.writeText("thread: ${thread.name}\n${throwable.stackTraceToString()}")
      } catch (_: Throwable) {
      }
      previousHandler?.uncaughtException(thread, throwable)
    }
  }

  fun consume(context: Context): List<Map<String, Any>> {
    val reports = ArrayList<Map<String, Any>>()
    var javaCrash = consumeJavaCrash(context)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      for (info in consumeExitInfos(context)) {
        if (!isAbnormal(info)) continue
        var details = describe(info)
        if (javaCrash != null && info.reason == ApplicationExitInfo.REASON_CRASH && abs(info.timestamp - javaCrash.timestamp) <= JAVA_CRASH_MATCH_WINDOW_MS) {
          details += "\n${javaCrash.trace}"
          javaCrash = null
        }
        reports.add(mapOf("timestamp" to info.timestamp, "details" to details))
      }
    }

    if (javaCrash != null) {
      reports.add(mapOf("timestamp" to javaCrash.timestamp, "details" to "CRASH (uncaught java exception)\n${javaCrash.trace}"))
    }
    return reports
  }

  private fun consumeJavaCrash(context: Context): JavaCrash? {
    val file = File(context.filesDir, JAVA_CRASH_FILE_NAME)
    return try {
      val crash = JavaCrash(file.lastModified(), file.readText())
      file.delete()
      crash
    } catch (_: IOException) {
      null
    }
  }

  @RequiresApi(Build.VERSION_CODES.R)
  private fun consumeExitInfos(context: Context): List<ApplicationExitInfo> {
    val activityManager = context.getSystemService(ActivityManager::class.java) ?: return emptyList()
    val infos = activityManager.getHistoricalProcessExitReasons(context.packageName, 0, MAX_EXIT_INFOS)
    if (infos.isEmpty()) return emptyList()

    val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    val lastTimestamp = prefs.getLong(KEY_LAST_TIMESTAMP, 0L)
    val newestTimestamp = infos.maxOf { it.timestamp }
    if (newestTimestamp <= lastTimestamp) return emptyList()
    prefs.edit().putLong(KEY_LAST_TIMESTAMP, newestTimestamp).apply()

    return infos.filter { it.timestamp > lastTimestamp }.sortedBy { it.timestamp }
  }

  @RequiresApi(Build.VERSION_CODES.R)
  private fun isAbnormal(info: ApplicationExitInfo): Boolean {
    return when (info.reason) {
      ApplicationExitInfo.REASON_CRASH,
      ApplicationExitInfo.REASON_CRASH_NATIVE,
      ApplicationExitInfo.REASON_ANR,
      ApplicationExitInfo.REASON_INITIALIZATION_FAILURE,
      ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE,
      ApplicationExitInfo.REASON_DEPENDENCY_DIED -> true

      // -- killing a cached process is the system's normal cleanup
      ApplicationExitInfo.REASON_LOW_MEMORY,
      ApplicationExitInfo.REASON_SIGNALED,
      ApplicationExitInfo.REASON_OTHER,
      ApplicationExitInfo.REASON_UNKNOWN -> info.importance < ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED

      else -> false
    }
  }

  @RequiresApi(Build.VERSION_CODES.R)
  private fun describe(info: ApplicationExitInfo): String {
    val sb = StringBuilder()
    sb.append(reasonName(info.reason))
      .append(", status ").append(info.status)
      .append(", importance ").append(info.importance)
      .append(", pss ").append(info.pss / 1024).append("MB")
      .append(", rss ").append(info.rss / 1024).append("MB")
    info.description?.let { sb.append('\n').append(it) }
    readTrace(info)?.let { sb.append('\n').append(it) }
    return sb.toString()
  }

  @RequiresApi(Build.VERSION_CODES.R)
  private fun readTrace(info: ApplicationExitInfo): String? {
    return try {
      when (info.reason) {
        ApplicationExitInfo.REASON_CRASH_NATIVE -> {
          if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
          val bytes = info.traceInputStream?.use { it.readBytes() } ?: return null
          TombstoneSummary.decode(bytes, MAX_BACKTRACE_FRAMES)
        }

        ApplicationExitInfo.REASON_ANR -> {
          val trace = info.traceInputStream?.use { String(it.readBytes()) } ?: return null
          mainThreadOfAnr(trace)
        }

        else -> null
      }
    } catch (_: Exception) {
      null
    }
  }

  private fun mainThreadOfAnr(trace: String): String? {
    val start = trace.indexOf("\n\"main\"")
    if (start < 0) return null
    val end = trace.indexOf("\n\n", start + 1).let { if (it < 0) trace.length else it }
    return trace.substring(start + 1, end).lineSequence().take(MAX_ANR_LINES).joinToString("\n")
  }

  private fun reasonName(reason: Int): String {
    return when (reason) {
      ApplicationExitInfo.REASON_EXIT_SELF -> "EXIT_SELF"
      ApplicationExitInfo.REASON_SIGNALED -> "SIGNALED"
      ApplicationExitInfo.REASON_LOW_MEMORY -> "LOW_MEMORY"
      ApplicationExitInfo.REASON_CRASH -> "CRASH"
      ApplicationExitInfo.REASON_CRASH_NATIVE -> "CRASH_NATIVE"
      ApplicationExitInfo.REASON_ANR -> "ANR"
      ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "INITIALIZATION_FAILURE"
      ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "EXCESSIVE_RESOURCE_USAGE"
      ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "DEPENDENCY_DIED"
      ApplicationExitInfo.REASON_OTHER -> "OTHER"
      else -> "UNKNOWN($reason)"
    }
  }
}

/// fields from system/core/debuggerd/proto/tombstone.proto, output mimics text tombstones so ndk-stack can symbolize it.
private object TombstoneSummary {
  private const val TOMBSTONE_TID = 6
  private const val TOMBSTONE_SIGNAL = 10
  private const val TOMBSTONE_ABORT_MESSAGE = 14
  private const val TOMBSTONE_CAUSES = 15
  private const val TOMBSTONE_THREADS = 16

  private const val SIGNAL_NAME = 2
  private const val SIGNAL_CODE_NAME = 4
  private const val SIGNAL_HAS_FAULT_ADDRESS = 8
  private const val SIGNAL_FAULT_ADDRESS = 9

  private const val CAUSE_HUMAN_READABLE = 1

  private const val MAP_ENTRY_KEY = 1
  private const val MAP_ENTRY_VALUE = 2

  private const val THREAD_ID = 1
  private const val THREAD_NAME = 2
  private const val THREAD_BACKTRACE = 4

  private const val FRAME_REL_PC = 1
  private const val FRAME_FUNCTION_NAME = 4
  private const val FRAME_FUNCTION_OFFSET = 5
  private const val FRAME_FILE_NAME = 6
  private const val FRAME_BUILD_ID = 8

  fun decode(bytes: ByteArray, maxFrames: Int): String {
    var crashingTid = 0L
    var signal: String? = null
    var abortMessage: String? = null
    val causes = ArrayList<String>()
    val threads = HashMap<Long, ProtoReader>()

    val reader = ProtoReader(bytes, 0, bytes.size)
    while (reader.next()) {
      when (reader.field) {
        TOMBSTONE_TID -> crashingTid = reader.varint()
        TOMBSTONE_SIGNAL -> signal = decodeSignal(reader.message())
        TOMBSTONE_ABORT_MESSAGE -> abortMessage = reader.string()
        TOMBSTONE_CAUSES -> decodeCause(reader.message())?.let(causes::add)
        TOMBSTONE_THREADS -> {
          val entry = reader.message()
          var tid = 0L
          var thread: ProtoReader? = null
          while (entry.next()) {
            when (entry.field) {
              MAP_ENTRY_KEY -> tid = entry.varint()
              MAP_ENTRY_VALUE -> thread = entry.message()
              else -> entry.skip()
            }
          }
          if (thread != null) threads[tid] = thread
        }

        else -> reader.skip()
      }
    }

    val sb = StringBuilder()
    signal?.let { sb.append(it).append('\n') }
    abortMessage?.let { sb.append("Abort message: '").append(it).append("'\n") }
    for (cause in causes) sb.append("Cause: ").append(cause).append('\n')
    threads[crashingTid]?.let { appendThread(sb, it, maxFrames) }
    return sb.toString().trimEnd()
  }

  private fun decodeSignal(signal: ProtoReader): String {
    var name = ""
    var codeName = ""
    var hasFaultAddress = false
    var faultAddress = 0L
    while (signal.next()) {
      when (signal.field) {
        SIGNAL_NAME -> name = signal.string()
        SIGNAL_CODE_NAME -> codeName = signal.string()
        SIGNAL_HAS_FAULT_ADDRESS -> hasFaultAddress = signal.varint() != 0L
        SIGNAL_FAULT_ADDRESS -> faultAddress = signal.varint()
        else -> signal.skip()
      }
    }
    val faultText = if (hasFaultAddress) ", fault addr 0x${java.lang.Long.toHexString(faultAddress)}" else ""
    return "signal $name ($codeName)$faultText"
  }

  private fun decodeCause(cause: ProtoReader): String? {
    while (cause.next()) {
      if (cause.field == CAUSE_HUMAN_READABLE) return cause.string()
      cause.skip()
    }
    return null
  }

  private fun appendThread(sb: StringBuilder, thread: ProtoReader, maxFrames: Int) {
    var id = 0L
    var name = ""
    val frames = ArrayList<ProtoReader>()
    while (thread.next()) {
      when (thread.field) {
        THREAD_ID -> id = thread.varint()
        THREAD_NAME -> name = thread.string()
        THREAD_BACKTRACE -> if (frames.size < maxFrames) frames.add(thread.message()) else thread.skip()
        else -> thread.skip()
      }
    }
    sb.append("thread: ").append(name).append(" (").append(id).append(")\nbacktrace:\n")
    for ((index, frame) in frames.withIndex()) appendFrame(sb, index, frame)
  }

  private fun appendFrame(sb: StringBuilder, index: Int, frame: ProtoReader) {
    var relPc = 0L
    var functionName = ""
    var functionOffset = 0L
    var fileName = ""
    var buildId = ""
    while (frame.next()) {
      when (frame.field) {
        FRAME_REL_PC -> relPc = frame.varint()
        FRAME_FUNCTION_NAME -> functionName = frame.string()
        FRAME_FUNCTION_OFFSET -> functionOffset = frame.varint()
        FRAME_FILE_NAME -> fileName = frame.string()
        FRAME_BUILD_ID -> buildId = frame.string()
        else -> frame.skip()
      }
    }
    sb.append("      #").append(index.toString().padStart(2, '0'))
      .append(" pc ").append(java.lang.Long.toHexString(relPc).padStart(16, '0'))
      .append("  ").append(fileName)
    if (functionName.isNotEmpty()) sb.append(" (").append(functionName).append('+').append(functionOffset).append(')')
    if (buildId.isNotEmpty()) sb.append(" (BuildId: ").append(buildId).append(')')
    sb.append('\n')
  }
}

private class ProtoReader(private val bytes: ByteArray, private var position: Int, private val end: Int) {
  var field = 0
    private set
  private var wireType = 0

  fun next(): Boolean {
    if (position >= end) return false
    val key = readVarint()
    field = (key ushr 3).toInt()
    wireType = (key and 7L).toInt()
    return true
  }

  fun varint(): Long = readVarint()

  fun string(): String {
    val length = readVarint().toInt()
    val value = String(bytes, position, length, Charsets.UTF_8)
    position += length
    return value
  }

  fun message(): ProtoReader {
    val length = readVarint().toInt()
    val message = ProtoReader(bytes, position, position + length)
    position += length
    return message
  }

  fun skip() {
    when (wireType) {
      WIRE_VARINT -> readVarint()
      WIRE_FIXED64 -> position += 8
      WIRE_LENGTH_DELIMITED -> {
        val length = readVarint().toInt()
        position += length
      }
      WIRE_FIXED32 -> position += 4
      else -> position = end
    }
  }

  private fun readVarint(): Long {
    var result = 0L
    var shift = 0
    while (position < end) {
      val byte = bytes[position++].toInt()
      result = result or ((byte and 0x7F).toLong() shl shift)
      if (byte and 0x80 == 0) break
      shift += 7
    }
    return result
  }

  private companion object {
    const val WIRE_VARINT = 0
    const val WIRE_FIXED64 = 1
    const val WIRE_LENGTH_DELIMITED = 2
    const val WIRE_FIXED32 = 5
  }
}

private class JavaCrash(val timestamp: Long, val trace: String)
