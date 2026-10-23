part of 'home_widgets.dart';

class _HomeWidgetsAndroid extends HomeWidgets {
  @override
  Future<bool?> init() {
    _initHasWidgets();
    return Future.value(null);
  }

  @override
  Set<_HomeWidgetKey> get _shownKeys => _kShownKeys;
  static const _kShownKeys = {..._HomeWidgetKey.values};

  Future<void> _initHasWidgets() async {
    bool hasWidgets;
    try {
      final widgets = await HomeWidget.getInstalledWidgets();
      hasWidgets = widgets.isNotEmpty;
    } catch (_) {
      // -- unknown, keep writing
      hasWidgets = true;
    }
    await setHasWidgets(hasWidgets);
  }

  @override
  Future<void> _saveAndRefresh(Map<String, Object?> data) async {
    await HomeWidget.saveWidgetDataBatch(data);
    await _refresh();
  }

  Future<bool?> _refresh() {
    return HomeWidget.updateWidget(
      qualifiedAndroidName: 'com.msob7y.namida.glance.SchwarzReceiver',
    );
  }
}
