import 'package:flutter/foundation.dart';

import 'countdown_phase.dart';
import 'marquee.dart';
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
    this.showClock = false,
    this.clockUse24Hour = true,
    this.marquee,
  });

  /// Sin actividades: la pantalla muestra un estado vacío.
  const CountdownSnapshot.empty({
    this.showClock = false,
    this.clockUse24Hour = true,
    this.marquee,
  }) : current = null,
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

  /// `true` cuando el escenario tiene que mostrar la hora actual en vez de la
  /// cuenta atrás. Viaja en la instantánea para que llegue a la segunda
  /// ventana (o al proceso aparte de Linux) por el canal de siempre.
  final bool showClock;

  /// Formato del reloj cuando [showClock] es `true`: 24 h por defecto.
  final bool clockUse24Hour;

  /// Mensaje de marquesina al aire, si lo hay.
  ///
  /// Cuando llega, el escenario encoge el reloj arriba y hace cruzar el texto
  /// por la franja de abajo. Al terminar el pase, esta vuelve a ser `null` y el
  /// reloj recupera su tamaño: por eso el campo viaja en la instantánea, como
  /// el modo reloj.
  final MarqueeOverlay? marquee;

  bool get hasActivities => current != null;

  bool get isLast => next == null;

  /// Instantánea para previsualizar una actividad concreta como si estuviera
  /// en curso: lo que vería el público si esa actividad saliera al escenario
  /// ahora mismo, con su duración completa por delante.
  ///
  /// No toca el estado de la ejecución: es solo una foto para el diálogo de
  /// vista previa de la tarjeta.
  factory CountdownSnapshot.preview({
    required List<ScheduledActivity> slots,
    required int index,
  }) {
    assert(slots.isNotEmpty, 'previsualizar exige al menos una actividad');
    final safe = index.clamp(0, slots.length - 1);
    final current = slots[safe];
    return CountdownSnapshot(
      current: current,
      next: safe + 1 < slots.length ? slots[safe + 1] : null,
      index: safe,
      total: slots.length,
      remaining: current.endTime.difference(current.startTime),
      phase: CountdownPhase.normal,
      startTime: current.startTime,
    );
  }

  /// Empaqueta la instantánea para enviarla a la ventana del escenario.
  ///
  /// Cada ventana de Flutter tiene su propio motor y no comparten memoria, así
  /// que lo que se ve proyectado tiene que viajar como datos. Es lo único que
  /// cruza entre las dos ventanas.
  Map<String, dynamic> toJson() => {
    'current': current?.toJson(),
    'next': next?.toJson(),
    'index': index,
    'total': total,
    'remainingMs': remaining.inMilliseconds,
    'phase': phase.name,
    'isPaused': isPaused,
    'isAutomatic': isAutomatic,
    'isFinished': isFinished,
    'isQuickTimer': isQuickTimer,
    'startTime': startTime?.toIso8601String(),
    'showClock': showClock,
    'clockUse24Hour': clockUse24Hour,
    'marquee': marquee?.toJson(),
  };

  factory CountdownSnapshot.fromJson(Map<dynamic, dynamic> json) =>
      CountdownSnapshot(
        current: _readActivity(json['current']),
        next: _readActivity(json['next']),
        index: (json['index'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        remaining: Duration(
          milliseconds: (json['remainingMs'] as num?)?.toInt() ?? 0,
        ),
        phase: _readPhase(json['phase']),
        isPaused: json['isPaused'] as bool? ?? false,
        isAutomatic: json['isAutomatic'] as bool? ?? true,
        isFinished: json['isFinished'] as bool? ?? false,
        isQuickTimer: json['isQuickTimer'] as bool? ?? false,
        startTime: _readDate(json['startTime']),
        showClock: json['showClock'] as bool? ?? false,
        clockUse24Hour: json['clockUse24Hour'] as bool? ?? true,
        marquee: _readMarquee(json['marquee']),
      );

  static MarqueeOverlay? _readMarquee(Object? value) {
    if (value is! Map) return null;
    return MarqueeOverlay.fromJson(value.cast<dynamic, dynamic>());
  }

  static ScheduledActivity? _readActivity(Object? value) {
    if (value is! Map) return null;
    return ScheduledActivity.fromJson(value);
  }

  static DateTime? _readDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  /// Una fase desconocida (versiones distintas de la app) no puede tumbar el
  /// reloj en mitad de un evento: se cae al estado previo al inicio.
  static CountdownPhase _readPhase(Object? value) {
    for (final phase in CountdownPhase.values) {
      if (phase.name == value) return phase;
    }
    return CountdownPhase.preShow;
  }

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
          other.startTime == startTime &&
          other.showClock == showClock &&
          other.clockUse24Hour == clockUse24Hour &&
          // El pase entero, con sus ajustes: cambiarlos mientras el texto está
          // en pantalla tiene que notarlo la ventana del escenario.
          other.marquee == marquee;

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
    showClock,
    clockUse24Hour,
    marquee,
  );
}
