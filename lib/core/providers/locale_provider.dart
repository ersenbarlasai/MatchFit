import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Locale Provider — Uygulama genelinde aktif dili yönetir.
/// Varsayılan: Türkçe (tr)
/// 
/// Kullanım:
///   final locale = ref.watch(localeProvider);       // Dinle
///   ref.read(localeProvider.notifier).setLocale('en'); // Değiştir

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    return const Locale('tr');
  }

  void setLocale(String languageCode) {
    if (['tr', 'en'].contains(languageCode)) {
      state = Locale(languageCode);
    }
  }

  void toggleLocale() {
    state = state.languageCode == 'tr' ? const Locale('en') : const Locale('tr');
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
