// by claude
package com.msob7y.namida

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FileProviderPathsTest {

  private val primaryRoot = "/storage/emulated/0"
  private val sdCardRoot = "/storage/1234-5678"
  private val storageRoots = listOf(primaryRoot, sdCardRoot, "/storage")

  private fun resolve(uriPath: String, existingPaths: Set<String>): String? {
    val decodedPathSegments = uriPath.split('/')
    return FileProviderPaths.resolveExistingPath(decodedPathSegments, storageRoots) { existingPaths.contains(it) }
  }

  @Test
  fun samsungDeviceStorage() {
    val realPath = "$primaryRoot/Documents/WaveEditor/Exported Audio/test.mp3"
    val resolved = resolve("device_storage/0/Documents/WaveEditor/Exported Audio/test.mp3", setOf(realPath))
    assertEquals(realPath, resolved)
  }

  @Test
  fun externalFiles() {
    val realPath = "$primaryRoot/Music/a.mp3"
    assertEquals(realPath, resolve("external_files/Music/a.mp3", setOf(realPath)))
  }

  @Test
  fun externalFilesOnSdCard() {
    val realPath = "$sdCardRoot/Music/a.mp3"
    assertEquals(realPath, resolve("external_files/Music/a.mp3", setOf(realPath)))
  }

  @Test
  fun primaryWinsOverSdCardForSameRelativePath() {
    val primaryPath = "$primaryRoot/Music/a.mp3"
    val sdCardPath = "$sdCardRoot/Music/a.mp3"
    assertEquals(primaryPath, resolve("external_files/Music/a.mp3", setOf(sdCardPath, primaryPath)))
  }

  @Test
  fun externalSegment() {
    val realPath = "$primaryRoot/Music/a.mp3"
    assertEquals(realPath, resolve("external/Music/a.mp3", setOf(realPath)))
  }

  @Test
  fun rootAbsolutePath() {
    val realPath = "$primaryRoot/Music/a.mp3"
    assertEquals(realPath, resolve("root/storage/emulated/0/Music/a.mp3", setOf(realPath)))
  }

  @Test
  fun rootAbsolutePathOnSdCard() {
    val realPath = "$sdCardRoot/Music/a.mp3"
    assertEquals(realPath, resolve("root/storage/1234-5678/Music/a.mp3", setOf(realPath)))
  }

  @Test
  fun sdCardIdUnknownToStorageRoots() {
    val realPath = "/storage/ABCD-EF01/Music/a.mp3"
    assertEquals(realPath, resolve("external_files/ABCD-EF01/Music/a.mp3", setOf(realPath)))
  }

  @Test
  fun sdCardIdWithoutPrefixSegment() {
    val realPath = "/storage/ABCD-EF01/Music/a.mp3"
    assertEquals(realPath, resolve("ABCD-EF01/Music/a.mp3", setOf(realPath)))
  }

  @Test
  fun decodedSpacesAndPercent() {
    val realPath = "$primaryRoot/My Music/100% hits/a b.mp3"
    assertEquals(realPath, resolve("files/My Music/100% hits/a b.mp3", setOf(realPath)))
  }

  @Test
  fun longestSuffixWins() {
    val longerPath = "$primaryRoot/0/Documents/a.mp3"
    val shorterPath = "$primaryRoot/Documents/a.mp3"
    assertEquals(longerPath, resolve("device_storage/0/Documents/a.mp3", setOf(shorterPath, longerPath)))
  }

  @Test
  fun bareFilenameNeverMatches() {
    val bareFilenamePaths = setOf("/a.mp3", "$primaryRoot/a.mp3", "$sdCardRoot/a.mp3", "/storage/a.mp3")
    assertNull(resolve("external_files/Music/a.mp3", bareFilenamePaths))
    assertNull(resolve("a.mp3", bareFilenamePaths))
  }

  @Test
  fun nothingExists() {
    assertNull(resolve("device_storage/0/Documents/a.mp3", emptySet()))
  }

  @Test
  fun emptySegments() {
    assertNull(resolve("", setOf("/")))
  }
}
