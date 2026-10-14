import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/countdown_phase.dart';
import '../models/countdown_snapshot.dart';
import '../models/scheduled_activity.dart';
import 'clock_provider.dart';
import 'run_show_provider.dart';
import 'schedule_provider.dart';

/// Provider derivado que combina reloj + estado de ejecución + cronograma.
///
/// Es el único que la pantalla del modo escenario observa, y se recalcula
/// automáticamente cada segundo por culpa de [clockProvider].
final countdownProvider = Provider<CountdownSnapshot>((ref) {
  final now = ref.watch(clockProvider);
  final schedule = ref.watch(activeScheduleProvider);
  final run = ref.watch(runShowProvider);

  if (schedule.isEmpty) return const CountdownSnapshot.empty();

  final effectiveNow = run.effectiveNow(now);

  final int index;
  final autoIndex = resolveRunIndex(schedule, effectiveNow);

  final override = run.indexOverride;
  if (override != null) {
    index = override.clamp(0, schedule.length - 1);
  } else if (autoIndex < 0) {
    // Todavía no empieza el evento: cuenta hacia la primera actividad.
    final first = schedule.first;
    return CountdownSnapshot(
      current: first,
      next: schedule.length > 1 ? schedule[1] : null,
      index: 0,
      total: schedule.length,
      remaining: first.startTime.difference(effectiveNow),
      phase: CountdownPhase.preShow,
      isPaused: run.isPaused,
      startTime: first.startTime,
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
      startTime: current.startTime,
    );
  }

  final remaining = current.endTime.difference(effectiveNow);

  return CountdownSnapshot(
    current: current,
    next: next,
    index: index,
    total: schedule.length,
    remaining: remaining,
    phase: countdownPhaseFor(remaining),
    isPaused: run.isPaused,
    isAutomatic: run.isAutomatic,
    startTime: current.startTime,
  );
});
