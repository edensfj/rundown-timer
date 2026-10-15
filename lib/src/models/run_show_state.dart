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
    this.sourceId,
  });

  /// Índice de la actividad que se está controlando.
  ///
  /// Lo fija el operador (o el reloj, al empezar el evento) y a partir de ahí no
  /// se mueve solo: el programa avanza cuando el operador lo dice.
  ///
  /// `null` significa que el evento todavía no ha empezado y se está esperando a
  /// que llegue su hora.
  final int? indexOverride;

  /// Instante en el que se pausó. `null` significa que está corriendo.
  final DateTime? pausedAt;

  /// Desplazamiento acumulado por pausas y reinicios.
  final Duration offset;

  /// El usuario cerró el evento.
  final bool eventFinished;

  /// Fuente a la que pertenece este estado (día o contador); al cambiar se reinicia.
  final String? sourceId;

  bool get isPaused => pausedAt != null;

  /// `true` mientras se espera a que llegue la hora del evento: es el único
  /// momento en el que el índice lo decide el reloj.
  bool get isAutomatic => indexOverride == null;

  /// `true` en cuanto hay una actividad fija en pantalla.
  bool get hasOverride => indexOverride != null;

  /// Reloj de referencia del temporizador, corregido por pausa y offset.
  DateTime effectiveNow(DateTime now) => (pausedAt ?? now).subtract(offset);

  RunShowState copyWith({
    Object? indexOverride = _unset,
    Object? pausedAt = _unset,
    Duration? offset,
    bool? eventFinished,
    String? sourceId,
  }) {
    return RunShowState(
      indexOverride: identical(indexOverride, _unset)
          ? this.indexOverride
          : indexOverride as int?,
      pausedAt: identical(pausedAt, _unset)
          ? this.pausedAt
          : pausedAt as DateTime?,
      offset: offset ?? this.offset,
      eventFinished: eventFinished ?? this.eventFinished,
      sourceId: sourceId ?? this.sourceId,
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
          other.sourceId == sourceId;

  @override
  int get hashCode =>
      Object.hash(indexOverride, pausedAt, offset, eventFinished, sourceId);
}
