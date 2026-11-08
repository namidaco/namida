// by claude
package com.msob7y.namida

object FileProviderPaths {

  // -- leading segments differ per provider, the longest existing suffix is the most specific match
  fun resolveExistingPath(decodedPathSegments: List<String>, storageRoots: Collection<String>, exists: (String) -> Boolean): String? {
    val relativePath = decodedPathSegments.joinToString("/")
    val lastSuffixStartIndex = decodedPathSegments.size - 2
    var suffixStartOffset = 0
    for (i in 0..lastSuffixStartIndex) {
      val suffix = relativePath.substring(suffixStartOffset)
      val absolutePath = "/$suffix"
      if (exists(absolutePath)) return absolutePath
      for (root in storageRoots) {
        val path = "$root/$suffix"
        if (exists(path)) return path
      }
      suffixStartOffset += decodedPathSegments[i].length + 1
    }
    return null
  }
}
