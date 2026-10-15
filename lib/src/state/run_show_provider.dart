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
///
/// El programa **no avanza solo**: cuando llega la hora de la primera actividad
/// se fija el índice y de ahí en adelante la pantalla se queda en esa actividad
/// —pase lo que pase, aunque se retrase— hasta que el operador pulse «siguiente».
/// Un rundown se lleva con la sala, no con el reloj, y en directo el reloj va
/// siempre por detrás. Lo único que arranca solo es el evento: antes de que
/// llegue, el escenario muestra la cuenta atrás previa.
class RunShowNotifier extends Notifier<RunShowState> {
  @override
  RunShowState build() {
    final source = ref.watch(stageSourceIdProvider);

    ref.listen(clockProvider, (previous, next) => _fijarAlEmpezar(next));

    return RunShowState(sourceId: source);
  }

  /// Fija la actividad en la que arranca el evento, una sola vez.
  ///
  /// Mientras el reloj no haya llegado a la primera actividad se sigue a la
  /// espera (cuenta atrás previa). En cuanto llega, el índice se clava y deja de
  /// seguir al reloj.
  void _fijarAlEmpezar(DateTime now) {
    if (state.indexOverride != null) return;

    final schedule = ref.read(activeScheduleProvider);
    if (schedule.isEmpty) return;

    final index = resolveRunIndex(schedule, state.effectiveNow(now));
    if (index < 0) return;

    state = state.copyWith(indexOverride: index);
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

  /// Vuelve a la actividad que marca la hora de ahora.
  ///
  /// No reactiva el avance automático —eso no existe—: solo recoloca la pantalla
  /// en la actividad que correspondería a este momento, por ejemplo después de
  /// haber ido saltando a mano o al abrir la app con el evento ya empezado.
  void syncWithClock() => state = state.copyWith(indexOverride: null);

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

  /// Índice efectivo: el fijado si lo hay, si no el que deduce el reloj.
  ///
  /// Sin índice fijado solo se está esperando a que empiece el evento; en cuanto
  /// llega, [clockProvider] lo clava y este caso deja de darse.
  int _currentIndex() {
    final schedule = _schedule;
    if (schedule.isEmpty) return 0;

    final override = state.indexOverride;
    if (override != null) return override.clamp(0, schedule.length - 1);

    final auto = resolveRunIndex(schedule, state.effectiveNow(DateTime.now()));
    return auto < 0 ? 0 : auto;
  }
}

final runShowProvider = NotifierProvider<RunShowNotifier, RunShowState>(
  RunShowNotifier.new,
);
