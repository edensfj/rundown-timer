import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/countdown_phase.dart';
import '../models/countdown_snapshot.dart';
import '../models/scheduled_activity.dart';
import 'clock_provider.dart';
import 'marquee_provider.dart';
import 'quick_timer_provider.dart';
import 'run_show_provider.dart';
import 'schedule_provider.dart';
import 'stage_flash_settings_provider.dart';
import 'stage_mode_provider.dart';
import 'stage_projection_provider.dart';

/// Provider derivado que combina reloj + estado de ejecución + cronograma.
///
/// Es el único que la pantalla del modo escenario observa, y se recalcula
/// automáticamente cada segundo por culpa de [clockProvider].
final countdownProvider = Provider<CountdownSnapshot>((ref) {
  final now = ref.watch(clockProvider);
  final schedule = ref.watch(activeScheduleProvider);
  final run = ref.watch(runShowProvider);
  final isQuickTimer = ref.watch(quickTimerProvider) != null;

  // El modo de proyección va en la instantánea para que viaje al escenario
  // por el canal de siempre. Al cambiar, la instantánea cambia y el `push`
  // del controlador la manda sin que haya que avisarle.
  final showClock = ref.watch(stageModeProvider) == StageMode.clock;
  final clockUse24Hour =
      ref.watch(stageClockFormatProvider) == StageClockFormat.h24;

  // La marquesina viaja igual: su pase al aire (o su ausencia) cambia la
  // instantánea y el escenario reacciona sin canal nuevo.
  final marquee = ref.watch(marqueePlaybackProvider);

  // Y los ajustes de parpadeo también viajan: el escenario no abre las cajas de
  // Hive, así que los obedece leyéndolos de aquí.
  final flashSettings = ref.watch(stageFlashSettingsProvider);

  if (schedule.isEmpty) {
    return CountdownSnapshot.empty(
      showClock: showClock,
      clockUse24Hour: clockUse24Hour,
      marquee: marquee,
      flashSettings: flashSettings,
    );
  }

  final effectiveNow = run.effectiveNow(now);

  final int index;
  final autoIndex = resolveRunIndex(schedule, effectiveNow);

  final override = run.indexOverride;
  if (override != null) {
    index = override.clamp(0, schedule.length - 1);
  } else if (autoIndex < 0) {
    // Todavía no empieza el evento: cuenta hacia la primera actividad. Salvo
    // que el operador haya pedido no proyectarla —la pantalla se queda a la
    // espera, en negro, con la marquesina si hay alguna en el aire—.
    if (!ref.watch(showPreShowCountdownProvider)) {
      return CountdownSnapshot.idle(
        showClock: showClock,
        clockUse24Hour: clockUse24Hour,
        marquee: marquee,
        flashSettings: flashSettings,
      );
    }

    final first = schedule.first;
    return CountdownSnapshot(
      current: first,
      next: schedule.length > 1 ? schedule[1] : null,
      index: 0,
      total: schedule.length,
      remaining: first.startTime.difference(effectiveNow),
      phase: CountdownPhase.preShow,
      isPaused: run.isPaused,
      isQuickTimer: isQuickTimer,
      startTime: first.startTime,
      showClock: showClock,
      clockUse24Hour: clockUse24Hour,
      marquee: marquee,
      flashSettings: flashSettings,
    );
  } else {
    index = autoIndex;
  }

  final current = schedule[index];
  final next = index + 1 < schedule.length ? schedule[index + 1] : null;

  // El evento cerrado tiene prioridad sobre el cálculo, pero el overtime de la
  // última actividad manda sobre el finished automático: si la última se pasa
  // de tiempo, el operador debe ver el retraso, no un «finalizado».
  if (run.eventFinished) {
    return CountdownSnapshot(
      current: current,
      next: next,
      index: index,
      total: schedule.length,
      remaining: Duration.zero,
      phase: CountdownPhase.finished,
      isPaused: run.isPaused,
      isAutomatic: run.isAutomatic,
      isFinished: true,
      isQuickTimer: isQuickTimer,
      startTime: current.startTime,
      showClock: showClock,
      clockUse24Hour: clockUse24Hour,
      marquee: marquee,
      flashSettings: flashSettings,
    );
  }

  // Actividad detenida a mano: el conteo queda en cero y la fase pasa a
  // «finalizada», para que el escenario la muestre detenida y **no** la pinte de
  // retraso ni haga parpadear el rojo. Aquí no se ha perdido tiempo: se ha
  // terminado antes.
  final remaining = run.stopped
      ? Duration.zero
      : current.endTime.difference(effectiveNow);

  return CountdownSnapshot(
    current: current,
    next: next,
    index: index,
    total: schedule.length,
    remaining: remaining,
    phase: run.stopped ? CountdownPhase.finished : countdownPhaseFor(remaining),
    isPaused: run.isPaused,
    isAutomatic: run.isAutomatic,
    isStopped: run.stopped,
    isQuickTimer: isQuickTimer,
    startTime: current.startTime,
    showClock: showClock,
    clockUse24Hour: clockUse24Hour,
    marquee: marquee,
    flashSettings: flashSettings,
  );
});
