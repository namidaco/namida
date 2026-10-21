part of 'youtube_controller.dart';

// by claude
/// Drops downloaded files that were removed from storage out of [YoutubeController.downloadedFilesMap].
/// A group folder is listed again only when its modification time changed, otherwise a check is a single stat.
class _DownloadedFilesValidator {
  _DownloadedFilesValidator();

  static const _kMissing = -2;

  final _groupsModifiedMS = <DownloadTaskGroupName, int>{};
  final _validatingGroups = <DownloadTaskGroupName, Future<bool>>{};

  void seed(Map<DownloadTaskGroupName, int> groupsModifiedMS) => _groupsModifiedMS.addAll(groupsModifiedMS);

  static int getModifiedMSToStore(FileStat stat) {
    if (stat.type != FileSystemEntityType.directory) return _kMissing;
    return stat.getReusableModifiedMS();
  }

  Future<void> validateAll() async {
    final groupNames = YoutubeController.inst.downloadedFilesMap.value.keys;
    await Future.wait(groupNames.map(validateGroup));
  }

  /// true when files were found missing.
  Future<bool> validateGroup(DownloadTaskGroupName groupName) {
    return _validatingGroups[groupName] ??= _validateGroup(groupName).whenComplete(() {
      _validatingGroups.remove(groupName);
    });
  }

  Future<bool> _validateGroup(DownloadTaskGroupName groupName) async {
    final dirPath = YoutubeController._getGroupDirectoryPath(groupName);
    final stat = await FileStat.stat(dirPath);
    final dirExists = stat.type == FileSystemEntityType.directory;
    final currentModifiedMS = dirExists ? stat.modified.millisecondsSinceEpoch : _kMissing;
    if (_groupsModifiedMS[groupName] == currentModifiedMS) return false;

    final modifiedMSToStore = getModifiedMSToStore(stat);
    final entryNames = dirExists ? await _listEntryNames.thready(dirPath) : const <String>{};
    if (entryNames == null) return false;
    _groupsModifiedMS[groupName] = modifiedMSToStore;

    final candidates = _getMissingCandidates(groupName, entryNames);
    if (candidates == null) return false;

    // -- confirmed per file, a download can finish between the listing and now
    final candidatesExist = await Future.wait(candidates.map((e) => e.$2.exists()));

    final groupFiles = YoutubeController.inst.downloadedFilesMap.value[groupName];
    if (groupFiles == null) return false;
    final missingConfigs = <YoutubeItemDownloadConfig>[];
    for (int i = 0; i < candidates.length; i++) {
      if (candidatesExist[i]) continue;
      final (config, file) = candidates[i];
      if (!identical(groupFiles[config.filename], file)) continue;
      groupFiles[config.filename] = null;
      missingConfigs.add(config);
    }
    if (missingConfigs.isEmpty) return false;

    YoutubeController.inst.downloadedFilesMap.refresh();
    YTOnGoingFinishedDownloads.inst.onTasksStatusChanged(groupName, missingConfigs);
    return true;
  }

  List<(YoutubeItemDownloadConfig, File)>? _getMissingCandidates(DownloadTaskGroupName groupName, Set<String> entryNames) {
    final groupFiles = YoutubeController.inst.downloadedFilesMap.value[groupName];
    final groupTasks = YoutubeController.inst.youtubeDownloadTasksMap.value[groupName];
    if (groupFiles == null || groupTasks == null) return null;

    List<(YoutubeItemDownloadConfig, File)>? candidates;
    for (final config in groupTasks.values) {
      if (config.cacheOnly) continue;
      final file = groupFiles[config.filename];
      if (file == null) continue;
      final filename = config.filename.filename;
      if (entryNames.contains(filename)) continue;
      if (config.splitByChapters == true) {
        final chaptersDirName = YoutubeController._getChaptersDirectoryPath(filename);
        if (entryNames.contains(chaptersDirName)) continue;
      }
      (candidates ??= []).add((config, file));
    }
    return candidates;
  }

  /// null when the folder can't be listed, which is the case for paths longer than 260 characters on windows.
  static Set<String>? _listEntryNames(String dirPath) {
    try {
      return Directory(dirPath).listSync().map((e) => e.path.getFilename).toSet();
    } catch (_) {
      return null;
    }
  }
}
