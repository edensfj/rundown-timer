import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/run_show_state.dart';
import '../models/scheduled_activity.dart';
import 'clock_provider.dart';
import 'schedule_provider.dart';

/// Estado del temporizador del modo escenario.
///
/// Depende de `stageSourceIdProvider`: al cambiar de fuente (de día o entre
/// itinerario y contador) el notifier se reconstruye y el estado vuelve a cero,
/// así que nunca queda apuntando a un índice que ya no existe.
class RunShowNotifier extends Notifier<RunShowState> {
  @override
  RunShowState build() {
    final source = ref.watch(stageSourceIdProvider);
    return RunShowState(sourceId: source);
  }

  List<ScheduledActivity> get _schedule => ref.read(activeScheduleProvider);

  /// Avanza manualmente. Queda fijado al índice alcanzado hasta que el operador
  /// vuelva al modo automático.
  void goToNext() {
    final schedule = _schedule;
    if (schedule.isEmpty) return;
    final current = _currentIndex();
    final next = (current + 1).clamp(0, schedule.length - 1);
    state = state.copyWith(indexOverride: next, eventFinished: false);
  }

  void goToPrevious() {
    final schedule = _schedule;
    if (schedule.isEmpty) return;
    final next = (_currentIndex() - 1).clamp(0, schedule.length - 1);
    state = state.copyWith(indexOverride: next, eventFinished: false);
  }

  void goToIndex(int index) {
    final schedule = _schedule;
    if (schedule.isEmpty) return;
    state = state.copyWith(
      indexOverride: index.clamp(0, schedule.length - 1),
      eventFinished: false,
    );
  }

  /// Devuelve el control al reloj: el índice vuelve a seguir la hora real.
  void followClock() => state = state.copyWith(indexOverride: null);

  void togglePause() {
    if (state.isPaused) {
      final now = DateTime.now();
      final pausedFor = now.difference(state.pausedAt!);
      state = state.copyWith(pausedAt: null, offset: state.offset + pausedFor);
    } else {
      state = state.copyWith(pausedAt: DateTime.now());
    }
  }

  /// Reinicia el conteo de la actividad actual: vuelve a cero el tiempo
  /// consumido, sin tocar la hora de fin programada.
  void restart() {
    final schedule = _schedule;
    if (schedule.isEmpty) return;
    final index = _currentIndex();
    final slot = schedule[index];
    final now = ref.read(clockProvider);
    final effectiveNow = state.effectiveNow(now);
    // Desplazamos el reloj efectivo hasta el inicio de la actividad.
    state = state.copyWith(
      offset: state.offset + effectiveNow.difference(slot.startTime),
      pausedAt: null,
    );
  }

  void finishEvent() => state = state.copyWith(eventFinished: true);

  void resumeEvent() => state = state.copyWith(eventFinished: false);

  /// Suma (o resta, con delta negativo) tiempo al conteo en curso.
  ///
  /// Funciona desplazando el reloj efectivo, no la hora de fin, así que sirve
  /// igual para el itinerario y para un contador suelto: si alguien necesita
  /// dos minutos más, el fin programado no se toca, solo se corre el tiempo.
  void addTime(Duration delta) {
    state = state.copyWith(offset: state.offset + delta);
  }

  /// Índice efectivo: el manual si lo hay, si no el que deduce el reloj.
  int _currentIndex() {
    final schedule = _schedule;
    if (schedule.isEmpty) return 0;

    final override = state.indexOverride;
    if (override != null) return override.clamp(0, schedule.length - 1);

    final auto = resolveRunIndex(schedule, state.effectiveNow(DateTime.now()));
    return auto < 0 ? 0 : auto;
  }
}

final runShowProvider =
    NotifierProvider<RunShowNotifier, RunShowState>(RunShowNotifier.new);
