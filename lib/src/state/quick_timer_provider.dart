import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ids.dart';
import '../core/time_formatters.dart';
import '../models/quick_timer.dart';

/// Contador suelto activo, o `null` si el escenario debe seguir el itinerario.
///
/// Es la **única fuente de verdad** del modo: mientras haya un temporizador
/// configurado, el escenario lo proyecta a él; al limpiarlo vuelve solo al
/// cronograma. No hace falta un provider de "modo" aparte.
class QuickTimerNotifier extends Notifier<QuickTimerConfig?> {
  @override
  QuickTimerConfig? build() => null;

  /// Arranca un contador nuevo, reemplazando el que hubiera.
  void start({required Duration duration, String? label}) {
    final clean = label?.trim() ?? '';
    state = QuickTimerConfig(
      id: newId(),
      label: clean.isEmpty ? _defaultLabel(duration) : clean,
      duration: duration,
      startedAt: DateTime.now(),
    );
  }

  /// Vuelve al itinerario programado.
  void clear() => state = null;

  static String _defaultLabel(Duration duration) =>
      'Contador · ${TimeFormatters.humanDuration(duration)}';
}

final quickTimerProvider =
    NotifierProvider<QuickTimerNotifier, QuickTimerConfig?>(
  QuickTimerNotifier.new,
);

/// Rango razonable para un contador rápido: de 1 segundo a 24 horas.
const Duration kQuickTimerMin = Duration(seconds: 1);
const Duration kQuickTimerMax = Duration(hours: 24);
