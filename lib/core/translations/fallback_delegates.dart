import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';

class FallbackMaterialLocalizationsDelegate extends _FallbackLocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationsDelegate() : super(GlobalMaterialLocalizations.delegate);
}

class FallbackCupertinoLocalizationsDelegate extends _FallbackLocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationsDelegate() : super(GlobalCupertinoLocalizations.delegate);
}

class FallbackWidgetsLocalizationsDelegate extends _FallbackLocalizationsDelegate<WidgetsLocalizations> {
  const FallbackWidgetsLocalizationsDelegate() : super(GlobalWidgetsLocalizations.delegate);
}

abstract class _FallbackLocalizationsDelegate<T> extends LocalizationsDelegate<T> {
  final LocalizationsDelegate<T> delegate;
  const _FallbackLocalizationsDelegate(this.delegate);

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) => delegate.load(const Locale('en'));

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}
