package com.msob7y.namida

import android.content.Context
import android.media.MediaScannerConnection
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.*
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.util.Base64
import kotlin.collections.List
import kotlin.collections.Map
import kotlinx.coroutines.*
import org.jaudiotagger.audio.AudioFile
import org.jaudiotagger.audio.AudioFileIO
import org.jaudiotagger.audio.AudioHeader
import org.jaudiotagger.audio.flac.metadatablock.MetadataBlockDataPicture
import org.jaudiotagger.audio.mp3.MP3File
import org.jaudiotagger.tag.FieldKey
import org.jaudiotagger.tag.Tag
import org.jaudiotagger.tag.flac.FlacTag
import org.jaudiotagger.tag.id3.ID3v23Tag
import org.jaudiotagger.tag.id3.valuepair.ImageFormats
import org.jaudiotagger.tag.images.Artwork
import org.jaudiotagger.tag.images.ArtworkFactory
import org.jaudiotagger.tag.mp4.Mp4Tag
import org.jaudiotagger.tag.reference.PictureTypes
import org.jaudiotagger.tag.vorbiscomment.VorbisCommentFieldKey
import org.jaudiotagger.tag.vorbiscomment.VorbisCommentTag

public class FAudioTagger : FlutterPlugin, MethodCallHandler {

  lateinit var channel: MethodChannel
  lateinit var binaryMessenger: BinaryMessenger
  val eventChannels = HashMap<Long, BetterEventChannel>()
  lateinit var context: Context

  companion object {
    var logFilePath: String? = null
    var logWriter: BufferedWriter? = null
    private var logWriterUsers: Int = 0

    fun writeError(
        path: String,
        function: String,
        type: String,
        error: String,
    ) {
      if (logWriter != null) {
        try {
          logWriter!!.append("${path}\n=>> ${function}.${type}: ${error}\n\n")
        } catch (_: Exception) {}
      }
    }

    fun _addLogsUser() {
      if (logWriterUsers == 0 && logFilePath != null) {
        File(logFilePath!!).createNewFile()
        if (logWriter == null) logWriter = BufferedWriter(FileWriter(logFilePath))
      }
      logWriterUsers++
    }

    fun _removeLogsUser() {
      logWriter?.flush()
      if (logWriterUsers <= 0) logWriter?.close()
    }
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "faudiotagger")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
    binaryMessenger = flutterPluginBinding.binaryMessenger
  }

  override fun onMethodCall(call: MethodCall, result: Result) {

    when (call.method) {
      "readAllData" -> {
        val path: String? = call.argument<String?>("path")
        if (path != null) {
          val artworkDirectory: String? = call.argument<String?>("artworkDirectory")
          val artworkIdentifiers =
              getArtworkIdentifier(call.argument<List<Int>?>("artworkIdentifiers"))
          val extractArtwork = call.argument<Boolean?>("extractArtwork") ?: true
          val overrideArtwork = call.argument<Boolean?>("overrideArtwork") ?: false

          CoroutineScope(Dispatchers.IO).launch {
            _addLogsUser()
            val map =
                readAllData(
                    path,
                    artworkDirectory,
                    artworkIdentifiers,
                    extractArtwork,
                    overrideArtwork,
                )
            map["path"] = path
            result.success(map)
            _removeLogsUser()
          }
        } else {
          result.error("Failure", "path parameter isn't provided", "")
        }
      }
      "readAllDataAsStream" -> {
        val paths = call.argument<List<String>?>("paths")
        if (paths != null) {
          val artworkDirectory: String? = call.argument<String?>("artworkDirectory")
          val artworkIdentifiers =
              getArtworkIdentifier(call.argument<List<Int>?>("artworkIdentifiers"))
          val extractArtwork = call.argument<Boolean?>("extractArtwork") ?: true
          val overrideArtwork = call.argument<Boolean?>("overrideArtwork") ?: false
          val streamKey = call.argument<Long?>("streamKey") ?: 0
          eventChannels.set(
              streamKey,
              BetterEventChannel(binaryMessenger, "faudiotagger/stream/" + streamKey)
          )
          val eventChannel = eventChannels.get(streamKey)!!
          result.success(true)
          _addLogsUser()
          CoroutineScope(Dispatchers.IO).launch {
            for (p in paths) {
              val map =
                  readAllData(
                      p,
                      artworkDirectory,
                      artworkIdentifiers,
                      extractArtwork,
                      overrideArtwork,
                  )
              map["path"] = p
              withContext(Dispatchers.Main) { eventChannel.success(map) }
            }
            withContext(Dispatchers.Main) { eventChannel.endOfStream() }
            _removeLogsUser()
          }
        } else {
          result.error("Failure", "path parameter isn't provided", "")
        }
      }
      "writeTags" -> {
        val path = call.argument<String>("path")
        val map = call.argument<Map<String?, String?>>("tags")
        if (path != null && map != null) {
          CoroutineScope(Dispatchers.IO).launch {
            _addLogsUser()
            val res = writeTags(path, map, context)
            result.success(res)
            _removeLogsUser()
          }
        } else {
          result.error("Failure", "path or tags parameters aren't provided", "")
        }
      }
      "setLogFile" -> {
        logFilePath = call.argument<String?>("path")
        logWriter?.flush()
        logWriter?.close()
        if (logFilePath != null) {
          logWriter = BufferedWriter(FileWriter(logFilePath))
        } else {
          logWriter = null
        }
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  fun getArtworkIdentifier(fromList: List<Int>?): HashMap<ArtworkIdentifier, Boolean>? {
    if (fromList == null || fromList.isEmpty()) return null
    val map = HashMap<ArtworkIdentifier, Boolean>()
    val all = ArtworkIdentifier.values()
    for (index in fromList) {
      val ident = all[index]
      map[ident] = true
    }
    return map
  }

  fun readAllData(
      path: String,
      artworkDirectory: String?,
      artworkIdentifiers: HashMap<ArtworkIdentifier, Boolean>?,
      extractArtwork: Boolean,
      overrideOldArtwork: Boolean,
  ): HashMap<String, Any> {
    val metadata = HashMap<String, Any>()
    val errorsMap = HashMap<String, String>()
    try {
      val mp3File: File = File(path)
      val audioFile: AudioFile = AudioFileIO.read(mp3File)

      // -- Audio File Info
      try {
        val audioHeader: AudioHeader? = audioFile.getAudioHeader()
        if (audioHeader != null) {
          metadata["isVariableBitRate"] = audioHeader.isVariableBitRate()
          metadata["isLoseless"] = audioHeader.isLossless()
          metadata["encodingType"] = audioHeader.getEncodingType()
          metadata["channels"] = audioHeader.getChannels()
          metadata["bitRate"] = audioHeader.getBitRateAsNumber()
          metadata["sampleRate"] = audioHeader.getSampleRateAsNumber()
          metadata["format"] = audioHeader.getFormat()
          metadata["length"] = audioHeader.getTrackLength()
        }
      } catch (e: Exception) {
        writeError(path, "readAllData", "ERROR_HEADER", e.toString())
        errorsMap["HEADER"] = e.toString()
        metadata["ERROR_FAULTY"] = true
      }

      try {
        val tag: Tag? = audioFile.getTag()
        if (tag != null) {
          // -- Tags
          val year = tag.getFirst(FieldKey.YEAR)
          val album = tag.getFirst(FieldKey.ALBUM)
          val albumArtist = tag.getFirst(FieldKey.ALBUM_ARTIST)
          metadata["country"] = tag.getFirst(FieldKey.COUNTRY)
          metadata["recordLabel"] = tag.getFirst(FieldKey.RECORD_LABEL)
          metadata["language"] = tag.getFirst(FieldKey.LANGUAGE)
          metadata["tempo"] = tag.getFirst(FieldKey.TEMPO)
          metadata["tags"] = tag.getFirst(FieldKey.TAGS)
          metadata["remixer"] = tag.getFirst(FieldKey.REMIXER)
          metadata["rating"] = tag.getFirst(FieldKey.RATING)
          metadata["mood"] = tag.getFirst(FieldKey.MOOD)
          metadata["mixer"] = tag.getFirst(FieldKey.MIXER)
          metadata["djmixer"] = tag.getFirst(FieldKey.DJMIXER)
          metadata["lyricist"] = tag.getFirst(FieldKey.LYRICIST)
          metadata["lyrics"] = tag.getFirst(FieldKey.LYRICS)
          metadata["discTotal"] = tag.getFirst(FieldKey.DISC_TOTAL)
          metadata["discNumber"] = tag.getFirst(FieldKey.DISC_NO)
          metadata["trackTotal"] = tag.getFirst(FieldKey.TRACK_TOTAL)
          metadata["trackNumber"] = tag.getFirst(FieldKey.TRACK)
          metadata["year"] = year
          metadata["comment"] = tag.getFirst(FieldKey.COMMENT)
          metadata["genre"] = tag.getFirst(FieldKey.GENRE)
          metadata["composer"] = tag.getFirst(FieldKey.COMPOSER)
          metadata["artist"] = tag.getFirst(FieldKey.ARTIST)
          metadata["albumArtist"] = albumArtist
          metadata["album"] = album
          metadata["title"] = tag.getFirst(FieldKey.TITLE)

          if (extractArtwork) {
            try {
              // -- Artwork`
              val artwork: Artwork? = tag.getFirstArtwork()
              if (artwork != null) {
                val artworkBytes = artwork.getBinaryData()
                if (artworkBytes != null && artworkBytes.isNotEmpty()) {
                  if (artworkDirectory != null) {
                    try {
                      val filename: String
                      if (artworkIdentifiers == null || artworkIdentifiers.isEmpty()) {
                        filename = path.split("/").last()
                      } else {
                        var parts = ""
                        if (artworkIdentifiers[ArtworkIdentifier.albumName] == true) {
                          if (album != null) parts += album
                        }
                        if (artworkIdentifiers[ArtworkIdentifier.albumArtist] == true) {
                          if (albumArtist != null) parts += albumArtist
                        }
                        if (artworkIdentifiers[ArtworkIdentifier.year] == true) {
                          if (year != null) parts += year
                        }
                        filename = parts
                      }

                      val artworkSavePath = "$artworkDirectory${filename}.png"
                      if (overrideOldArtwork || !File(artworkSavePath.toString()).exists()) {
                        FileOutputStream(artworkSavePath.toString()).use { stream ->
                          stream.write(artworkBytes)
                        }
                      }
                      metadata["artwork"] = artworkSavePath
                      metadata["artworkLength"] = artworkBytes.size
                    } catch (_: Exception) {}
                  } else {
                    metadata["arwork"] = artworkBytes
                    metadata["artworkLength"] = artworkBytes.size
                  }
                }
              }
            } catch (e: Exception) {
              writeError(path, "readAllData", "ERROR_ARTWORK", e.toString())
              errorsMap["ARTWORK"] = e.message.toString()
            }
          }
        }
      } catch (e: Exception) {
        writeError(path, "readAllData", "ERROR_TAG", e.toString())
        errorsMap["TAG"] = e.message.toString()
        metadata["ERROR_FAULTY"] = true
      }
    } catch (e: Exception) {
      writeError(path, "readAllData", "ERROR", e.toString())
      errorsMap["ERROR"] = e.message.toString()
      metadata["ERROR_FAULTY"] = true
    }
    metadata.put("ERRORS", errorsMap)
    return metadata
  }

  fun writeTags(
      path: String,
      map: Map<String?, Any?>,
      context: Context,
  ): String? {
    try {
      val mp3File: File = File(path)
      val audioFile: AudioFile = AudioFileIO.read(mp3File)

      var newTag: Tag? = audioFile.getTag()
      if (newTag == null) {
        return "File tag not found"
      }

      // Convert ID3v1 tag to ID3v23
      if (audioFile is MP3File) {
        if (audioFile.hasID3v1Tag() && !audioFile.hasID3v2Tag()) {
          newTag = ID3v23Tag(audioFile.getID3v1Tag())
          audioFile.setID3v1Tag(null) // remove v1 tags
          audioFile.setTag(newTag) // add v2 tags
        }
      }

      setFieldIfExist(newTag, FieldKey.TITLE, map, "title")
      setFieldIfExist(newTag, FieldKey.ALBUM, map, "album")
      setFieldIfExist(newTag, FieldKey.ALBUM_ARTIST, map, "albumArtist")
      setFieldIfExist(newTag, FieldKey.ARTIST, map, "artist")
      setFieldIfExist(newTag, FieldKey.COMPOSER, map, "composer")
      setFieldIfExist(newTag, FieldKey.GENRE, map, "genre")
      setFieldIfExist(newTag, FieldKey.YEAR, map, "year")
      setFieldIfExist(newTag, FieldKey.COMMENT, map, "comment")
      setFieldIfExist(newTag, FieldKey.TRACK, map, "trackNumber")
      setFieldIfExist(newTag, FieldKey.TRACK_TOTAL, map, "trackTotal")
      setFieldIfExist(newTag, FieldKey.DISC_NO, map, "discNumber")
      setFieldIfExist(newTag, FieldKey.DISC_TOTAL, map, "discTotal")
      setFieldIfExist(newTag, FieldKey.LYRICS, map, "lyrics")
      setFieldIfExist(newTag, FieldKey.LYRICIST, map, "lyricist")
      setFieldIfExist(newTag, FieldKey.DJMIXER, map, "djmixer")
      setFieldIfExist(newTag, FieldKey.MIXER, map, "mixer")
      setFieldIfExist(newTag, FieldKey.MOOD, map, "mood")
      setFieldIfExist(newTag, FieldKey.RATING, map, "rating")
      setFieldIfExist(newTag, FieldKey.REMIXER, map, "remixer")
      setFieldIfExist(newTag, FieldKey.TAGS, map, "tags")
      setFieldIfExist(newTag, FieldKey.TEMPO, map, "tempo")
      setFieldIfExist(newTag, FieldKey.LANGUAGE, map, "language")
      setFieldIfExist(newTag, FieldKey.COUNTRY, map, "country")
      setFieldIfExist(newTag, FieldKey.RECORD_LABEL, map, "recordLabel")

      val artwork = map["artwork"]
      // If field is null, it is ignored
      if (artwork != null) {
        // If field is set to an empty string, the field is deleted, otherwise it is set
        val artworkIsPath = artwork is String && artwork.trim().length > 0
        val artworkIsBytes = artwork is ByteArray && artwork.isNotEmpty()
        if (artworkIsPath || artworkIsBytes) {
          // Delete existing album art

          newTag.deleteArtworkField()

          fun getImageData(): ByteArray {
            if (artworkIsPath) {
              return File(artwork as String).readBytes()
            } else {
              return artwork as ByteArray
            }
          }

          if (newTag is Mp4Tag) {
            newTag.setField(newTag.createArtworkField(getImageData()))
          } else if (newTag is FlacTag) {
            newTag.setField(
                newTag.createArtworkField(
                    getImageData(),
                    PictureTypes.DEFAULT_ID,
                    ImageFormats.MIME_TYPE_JPEG,
                    "artwork",
                    0,
                    0,
                    24,
                    0
                )
            )
          } else if (newTag is VorbisCommentTag) {
            val base64image = Base64.getEncoder().encodeToString(getImageData())
            newTag.setField(newTag.createField(VorbisCommentFieldKey.COVERART, base64image))
            newTag.setField(newTag.createField(VorbisCommentFieldKey.COVERARTMIME, "image/png"))
          } else {
            val cover =
                if (artworkIsPath) ArtworkFactory.createArtworkFromFile(File(artwork as String))
                else
                    ArtworkFactory.createArtworkFromMetadataBlockDataPicture(
                        MetadataBlockDataPicture(ByteBuffer.wrap(artwork as ByteArray))
                    )
            newTag.setField(cover)
          }
        } else {
          newTag.deleteArtworkField()
        }
      }
      audioFile.commit()

      val urls = arrayOf(path)
      val mimes = arrayOf("audio/mpeg")
      MediaScannerConnection.scanFile(context, urls, mimes) { _, _ ->
        Log.i("Audiotagger", "Media scanning success")
      }

      return null
    } catch (e: Exception) {
      writeError(path, "writeTags", "ERROR", e.toString())
      return e.toString()
    }
  }

  fun setFieldIfExist(tag: Tag, field: FieldKey?, map: Map<String?, Any?>, key: String?) {
    val value = map[key]
    // If field is null, it is ignored
    if (value is String) {
      try {
        // If field is set to an empty string, the field is deleted, otherwise it is set
        if (value.trim { it <= ' ' }.length > 0) {
          tag.setField(field, value)
        } else {
          tag.deleteField(field)
        }
      } catch (ignore: Exception) {}
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    logWriter?.flush()
    logWriter?.close()
    for (eventChannel in eventChannels.values) {
      eventChannel.endOfStream()
    }
    eventChannels.clear()
  }
}

enum class ArtworkIdentifier {
  albumName,
  year,
  albumArtist,
}
