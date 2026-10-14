import 'package:flutter/foundation.dart';

const _unset = Object();

/// Estado del modo escenario: qué actividad se está controlando y cómo se
/// corre el reloj.
///
/// Toda la matemática del temporizador se apoya en un único concepto:
/// el **tiempo efectivo**, es decir `ahora` congelado si está en pausa y
/// corregido por el [offset] acumulado.
///
/// ```dart
/// effectiveNow = (pausedAt ?? ahora).subtract(offset)
/// remaining    = endTime - effectiveNow
/// ```
@immutable
class RunShowState {
  const RunShowState({
    this.indexOverride,
    this.pausedAt,
    this.offset = Duration.zero,
    this.eventFinished = false,
    this.dayId,
  });

  /// Índice elegido a mano. `null` significa «seguir el reloj automáticamente».
  final int? indexOverride;

  /// Instante en el que se pausó. `null` significa que está corriendo.
  final DateTime? pausedAt;

  /// Desplazamiento acumulado por pausas y reinicios.
  final Duration offset;

  /// El usuario cerró el evento.
  final bool eventFinished;

  /// Día al que pertenece este estado; al cambiar de día se reinicia.
  final String? dayId;

  bool get isPaused => pausedAt != null;

  /// `true` cuando el índice lo determina el reloj y no el operador.
  bool get isAutomatic => indexOverride == null;

  bool get hasOverride => indexOverride != null;

  /// Reloj de referencia del temporizador, corregido por pausa y offset.
  DateTime effectiveNow(DateTime now) => (pausedAt ?? now).subtract(offset);

  RunShowState copyWith({
    Object? indexOverride = _unset,
    Object? pausedAt = _unset,
    Duration? offset,
    bool? eventFinished,
    String? dayId,
  }) {
    return RunShowState(
      indexOverride:
          identical(indexOverride, _unset) ? this.indexOverride : indexOverride as int?,
      pausedAt: identical(pausedAt, _unset) ? this.pausedAt : pausedAt as DateTime?,
      offset: offset ?? this.offset,
      eventFinished: eventFinished ?? this.eventFinished,
      dayId: dayId ?? this.dayId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RunShowState &&
          other.indexOverride == indexOverride &&
          other.pausedAt == pausedAt &&
          other.offset == offset &&
          other.eventFinished == eventFinished &&
          other.dayId == dayId;

  @override
  int get hashCode =>
      Object.hash(indexOverride, pausedAt, offset, eventFinished, dayId);
}
