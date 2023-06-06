enum SortType {
  title,
  album,
  albumArtist,
  year,
  artistsList,
  genresList,
  dateAdded,
  dateModified,
  bitrate,
  composer,
  discNo,
  filename,
  duration,
  sampleRate,
  size,
  rating,
}

enum GroupSortType {
  title,
  album,
  albumArtist,
  year,
  artistsList,
  genresList,
  dateModified,
  composer,
  duration,
  numberOfTracks,
  albumsCount,
  creationDate,
  modifiedDate,
}

enum TrackTilePosition {
  row1Item1,
  row1Item2,
  row1Item3,
  row2Item1,
  row2Item2,
  row2Item3,
  row3Item1,
  row3Item2,
  row3Item3,
  rightItem1,
  rightItem2,
  rightItem3,
}

enum TrackTileItem {
  none,
  title,
  album,
  artists,
  albumArtist,
  genres,
  composer,
  trackNumber,
  discNumber,
  duration,
  year,
  size,
  dateAdded,
  dateModified,
  dateModifiedDate,
  dateModifiedClock,
  path,
  folder,
  fileName,
  fileNameWOExt,
  extension,
  comment,
  bitrate,
  sampleRate,
  format,
  channels,
  rating,
  tags,
  moods,
}

enum TrackSearchFilter {
  title,
  album,
  artist,
  albumartist,
  genre,
  composer,
  year,
}

enum LibraryTab {
  tracks,
  albums,
  artists,
  genres,
  playlists,
  folders,
}

enum TrackPlayMode {
  selectedTrack,
  searchResults,
  trackAlbum,
  trackArtist,
  trackGenre,
}

enum RepeatMode {
  none,
  one,
  forNtimes,
  all,
}

enum TrackSource {
  local,
  youtube,
  youtubeMusic,
  lastfm,
}

enum QueueSource {
  allTracks,
  album,
  artist,
  genre,
  playlist,
  folder,
  search,
  queuePage,
  playerQueue,
  mostPlayed,
  history,
  favourites,
  selectedTracks,
  externalFile,
}

enum TagField {
  title,
  artist,
  album,
  albumArtist,
  composer,
  genre,
  year,
  trackNumber,
  discNumber,
  comment,
  lyrics,
  remixer,
  trackTotal,
  discTotal,
  lyricist,
  language,
  recordLabel,
  country,
}

enum WakelockMode {
  none,
  expanded,
  expandedAndVideo,
}
