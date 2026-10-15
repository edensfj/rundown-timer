import 'package:flutter/foundation.dart';

const _unset = Object();

/// Estado del modo escenario: qué actividad se está controlando y cómo se
/// corre el reloj.
///
/// Toda la matemática del temporizador se apoya en un único concepto:
/// el **tiempo efectivo**, es decir `ahora` congelado si está en pausa.
///
/// ```dart
/// effectiveNow = pausedAt ?? ahora
/// remaining    = endTime - effectiveNow
/// ```
///
/// Los desfases del directo —empezar una actividad a mano, darle un minuto
/// más— no se hacen moviendo este reloj, sino desplazando el **plan**
/// ([planShiftProvider]): así las horas que se ven en el escenario son las de
/// verdad y no las que estaban programadas hace media hora.
@immutable
class RunShowState {
  const RunShowState({
    this.indexOverride,
    this.pausedAt,
    this.stopped = false,
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

  /// El operador terminó la actividad que está en pantalla.
  ///
  /// No es una pausa: la actividad se da por **acabada** aunque su hora de fin
  /// no hubiera llegado todavía (terminó antes, o se cortó). El conteo se queda
  /// en cero, sin parpadeo de retraso, y de ahí solo se sale pulsando
  /// «siguiente» o volviendo a arrancarla.
  final bool stopped;

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

  /// Reloj de referencia del temporizador: el de ahora, congelado si está en
  /// pausa.
  DateTime effectiveNow(DateTime now) => pausedAt ?? now;

  RunShowState copyWith({
    Object? indexOverride = _unset,
    Object? pausedAt = _unset,
    bool? stopped,
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
      stopped: stopped ?? this.stopped,
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
          other.stopped == stopped &&
          other.eventFinished == eventFinished &&
          other.sourceId == sourceId;

  @override
  int get hashCode =>
      Object.hash(indexOverride, pausedAt, stopped, eventFinished, sourceId);
}
