import 'package:flutter/foundation.dart';

import 'countdown_phase.dart';
import 'scheduled_activity.dart';

/// Instantánea inmutable que la UI del modo escenario necesita para pintarse.
///
/// Es un provider derivado: se recalcula combinando reloj, estado de ejecución
/// y cronograma, sin efectos secundarios.
@immutable
class CountdownSnapshot {
  const CountdownSnapshot({
    this.current,
    this.next,
    this.index = 0,
    this.total = 0,
    this.remaining = Duration.zero,
    this.phase = CountdownPhase.preShow,
    this.isPaused = false,
    this.isAutomatic = true,
    this.isFinished = false,
    this.isQuickTimer = false,
    this.startTime,
  });

  /// Sin actividades: la pantalla muestra un estado vacío.
  const CountdownSnapshot.empty()
      : current = null,
        next = null,
        index = 0,
        total = 0,
        remaining = Duration.zero,
        phase = CountdownPhase.preShow,
        isPaused = false,
        isAutomatic = true,
        isFinished = false,
        isQuickTimer = false,
        startTime = null;

  /// Actividad bajo control. En [CountdownPhase.preShow] es la primera.
  final ScheduledActivity? current;

  /// Siguiente actividad del cronograma, si la hay.
  final ScheduledActivity? next;

  /// Índice de [current] dentro del cronograma.
  final int index;

  /// Número total de actividades del día.
  final int total;

  /// Tiempo restante. Negativo cuando se pasó del tiempo programado.
  final Duration remaining;

  final CountdownPhase phase;

  final bool isPaused;

  /// `true` si el índice sigue al reloj automáticamente.
  final bool isAutomatic;

  final bool isFinished;

  /// `true` cuando lo que se cuenta es un contador suelto y no una actividad
  /// del itinerario. Cambia los textos de la cabecera y del pie.
  final bool isQuickTimer;

  /// Hora a la que apunta el countdown: el fin programado en curso, o el
  /// inicio de la primera actividad durante el pre-show.
  final DateTime? startTime;

  bool get hasActivities => current != null;

  bool get isLast => next == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountdownSnapshot &&
          other.current?.item.id == current?.item.id &&
          other.next?.item.id == next?.item.id &&
          other.index == index &&
          other.total == total &&
          other.remaining == remaining &&
          other.phase == phase &&
          other.isPaused == isPaused &&
          other.isAutomatic == isAutomatic &&
          other.isFinished == isFinished &&
          other.isQuickTimer == isQuickTimer &&
          other.startTime == startTime;

  @override
  int get hashCode => Object.hash(
        current?.item.id,
        next?.item.id,
        index,
        total,
        remaining,
        phase,
        isPaused,
        isAutomatic,
        isFinished,
        isQuickTimer,
        startTime,
      );
}
