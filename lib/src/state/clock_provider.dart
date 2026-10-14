import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reloj global de la app, actualizado segundo a segundo.
///
/// Es la única fuente de tiempo para toda la UI: el dashboard, la cabecera y el
/// countdown del modo escenario dependen de este provider, de modo que nunca
/// hay dos temporizadores desincronizados.
///
/// No es auto-dispose, así que sobrevive aunque ninguna pantalla lo observe.
class ClockNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Riverpod 3 lanza si se toca `ref` tras el dispose del provider.
      if (!ref.mounted) return;
      state = DateTime.now();
    });

    ref.onDispose(timer.cancel);
    return DateTime.now();
  }
}

final clockProvider = NotifierProvider<ClockNotifier, DateTime>(ClockNotifier.new);
