// by claude

import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

class ProgressPercentage {
  final RxBaseCore<int> _doneRx;
  final RxBaseCore<int> _totalRx;

  ProgressPercentage(this._doneRx, this._totalRx) {
    _doneRx.addListener(_refresh);
    _totalRx.addListener(_refresh);
    _refresh();
  }

  /// 0-100, null when the total is unknown. notifies only when the whole number changes.
  RxBaseCore<int?> get percentageRx => _percentageRx;
  final _percentageRx = Rxn<int>();

  void _refresh() {
    final total = _totalRx.value;
    if (total <= 0) {
      _percentageRx.value = null;
      return;
    }
    final done = _doneRx.value.withMaximum(total);
    _percentageRx.value = done * 100 ~/ total;
  }
}
