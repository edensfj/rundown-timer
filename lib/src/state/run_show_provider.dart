import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_notice.dart';
import '../models/run_show_state.dart';
import '../models/scheduled_activity.dart';
import 'clock_provider.dart';
import 'marquee_provider.dart';
import 'on_air_provider.dart';
import 'schedule_provider.dart';

/// Estado del temporizador del modo escenario.
///
/// Lo que se ve aquí es el del programa **que se está proyectando**, que no siempre
/// es el que el operador está mirando: el estado vive en [runStoreProvider]
/// guardado por fuente, así que revisar el guion de otro día no borra el directo
/// ni su desfase de plan, y al volver se encuentra todo como estaba.
///
/// El programa **no avanza solo**: cuando llega la hora de la primera actividad
/// se fija el índice y de ahí en adelante la pantalla se queda en esa actividad
/// —pase lo que pase, aunque se retrase— hasta que el operador pulse «siguiente».
/// Un rundown se lleva con la sala, no con el reloj, y en directo el reloj va
/// siempre por detrás. Lo único que arranca solo es el evento: antes de que
/// llegue, el escenario muestra la cuenta atrás previa —si el operador la ha
/// dejado proyectada—.
class RunShowNotifier extends Notifier<RunShowState> {
  @override
  RunShowState build() {
    final source = ref.watch(stageSourceIdProvider);
    // Se **observa**, no se lee: así cualquier cambio del almacén —pausar,
    // detener, sumar un minuto— reconstruye esto y llega a la pantalla, aunque
    // no haya cambiado de día.
    final store = ref.watch(runStoreProvider);

    ref.listen(clockProvider, (previous, next) => _fijarAlEmpezar(next));

    return store[source] ?? RunShowState(sourceId: source);
  }

  /// Estado **de la fuente que se está proyectando ahora mismo**, leído del
  /// almacén y no de aquí: si hace un momento cambió el aire, lo que llevaría
  /// este notifier es el estado del programa anterior.
  RunShowState get _current => _storedFor(ref.read(stageSourceIdProvider));

  /// Estado guardado de la fuente [source], o uno nuevo si esa fuente aún no ha
  /// tenido directo.
  ///
  /// Va en un almacén aparte y no en el propio notifier porque este se
  /// reconstruye al cambiar de fuente: si el estado viviera aquí, mirar el guion
  /// de otro día —o poner en marcha el suyo— borraría el directo que estaba en
  /// marcha. Guardándolo por fuente, cada programa conserva el suyo y solo se
  /// pierde lo que no se ha hecho aún.
  RunShowState _storedFor(String? source) {
    final saved = ref.read(runStoreProvider)[source];
    return saved ?? RunShowState(sourceId: source);
  }

  /// Todo cambio pasa por aquí, para que quede guardado por fuente y no se pierda
  /// al cambiar de programa.
  void _set(RunShowState next) => ref.read(runStoreProvider.notifier).put(next);

  /// Fija la actividad en la que arranca el evento, una sola vez.
  ///
  /// Mientras el reloj no haya llegado a la primera actividad se sigue a la
  /// espera (cuenta atrás previa). En cuanto llega, el índice se clava y deja de
  /// seguir al reloj.
  void _fijarAlEmpezar(DateTime now) {
    if (_current.indexOverride != null) return;

    final schedule = ref.read(activeScheduleProvider);
    if (schedule.isEmpty) return;

    final index = resolveRunIndex(schedule, _current.effectiveNow(now));
    if (index < 0) return;

    _set(_current.copyWith(indexOverride: index));
  }

  List<ScheduledActivity> get _schedule => ref.read(activeScheduleProvider);

  /// Avanza manualmente. Queda fijado al índice alcanzado: el programa no vuelve
  /// solo al reloj.
  void goToNext() {
    final schedule = _schedule;
    if (schedule.isEmpty) return;
    _moveTo((_currentIndex() + 1).clamp(0, schedule.length - 1));
  }

  void goToPrevious() {
    final schedule = _schedule;
    if (schedule.isEmpty) return;
    _moveTo((_currentIndex() - 1).clamp(0, schedule.length - 1));
  }

  void goToIndex(int index) {
    final schedule = _schedule;
    if (schedule.isEmpty) return;
    _moveTo(index.clamp(0, schedule.length - 1));
  }

  /// Pone [index] en el escenario **empezando ahora**.
  ///
  /// Es el botón «ejecutar» de una tarjeta: salta a esa actividad y la pone en
  /// marcha desde cero, con su duración completa, y con las horas reales de este
  /// momento.
  ///
  /// Con [dayId] ese día **toma el aire**: ejecutar algo es la forma clara de
  /// decir que ese programa es el que se proyecta, aunque el operador luego se
  /// vaya a mirar otro día.
  void runActivity(int index, {String? dayId}) {
    if (dayId != null) ref.read(onAirDayIdProvider.notifier).take(dayId);

    final schedule = _schedule;
    if (schedule.isEmpty) return;
    _moveTo(index.clamp(0, schedule.length - 1), unpause: true);
  }

  /// Coloca la pantalla en [index] como si empezara en este instante.
  ///
  /// Lo que se mueve es el **plan**, no un reloj interno: la actividad elegida
  /// pasa a empezar ahora y las siguientes caen donde toque, así que el
  /// escenario enseña horas de verdad —inicio, fin, término programado y la
  /// siguiente— en vez de las que estaban programadas. Con eso, saltar a una
  /// actividad que aún no había llegado cuenta su duración entera y no la hora
  /// que le quedaba al plan.
  void _moveTo(int index, {bool unpause = false}) {
    final schedule = _schedule;
    if (schedule.isEmpty) return;

    // Del almacén y no de aquí: si hace un momento el aire pasó a otro día, lo
    // que llevaría este notifier es el estado del programa anterior, y fijar la
    // actividad sobre ese estado la guardaría en el día equivocado.
    final base = _current;

    final safe = index.clamp(0, schedule.length - 1);
    final slot = schedule[safe];
    final effectiveNow = base.effectiveNow(ref.read(clockProvider));

    // El aviso de cierre de la actividad que se deja sale **antes** de mover
    // nada: en cuanto el plan se desplaza, la anterior ya no es la anterior.
    // Si el evento aún no había empezado (`-1`) no hay nada que cerrar.
    final previous = _onAirIndex(base);
    final cambia = previous != safe;
    if (cambia) {
      final playback = ref.read(marqueePlaybackProvider.notifier);

      // Un aviso va atado a la actividad que lo mandó: al pasar a la siguiente se
      // va con ella, y si la nueva no avisa de nada la pantalla se queda limpia.
      // Un mensaje del chat no se toca —ese lo mandó el operador a propósito—.
      playback.stopNotice();
      if (previous >= 0) {
        _fireNotice(schedule[previous], NoticeTrigger.onEnd);
      }
    }

    // El plan ya trae aplicado el desfase anterior, así que esta resta es lo que
    // falta por mover para que la actividad empiece justo ahora.
    _shiftPlanBy(effectiveNow.difference(slot.startTime));

    _set(
      base.copyWith(
        indexOverride: safe,
        pausedAt: unpause ? null : base.pausedAt,
        // Una actividad nueva nunca nace detenida.
        stopped: false,
        eventFinished: false,
      ),
    );

    if (cambia) _fireNotice(slot, NoticeTrigger.onStart);
  }

  /// Mueve el plan de la fuente que se está proyectando. Cada día lleva la cuenta
  /// aparte: el desfase de un directo no puede arrastrar al guion de otro.
  void _shiftPlanBy(Duration delta) => ref
      .read(planShiftStoreProvider.notifier)
      .add(ref.read(stageSourceIdProvider) ?? '', delta);

  /// Vuelve a la actividad que marca la hora de ahora, y al plan original.
  ///
  /// No reactiva el avance automático —eso no existe—: recoloca la pantalla en
  /// la actividad que correspondería a este momento y deshace los desfases que
  /// se hayan hecho a mano. Es también la vuelta atrás del «día en el aire»: desde
  /// aquí el escenario vuelve a seguir al día que se esté viendo.
  void syncWithClock() {
    final schedule = _schedule;
    final previous = _onAirIndex(_current);

    ref
        .read(planShiftStoreProvider.notifier)
        .reset(ref.read(stageSourceIdProvider) ?? '');
    ref.read(onAirDayIdProvider.notifier).release();
    _set(
      _current.copyWith(
        indexOverride: null,
        stopped: false,
        eventFinished: false,
      ),
    );

    if (schedule.isEmpty) return;
    final next = _onAirIndex(_current);
    if (next == previous) return;

    ref.read(marqueePlaybackProvider.notifier).stopNotice();
    if (previous >= 0) _fireNotice(schedule[previous], NoticeTrigger.onEnd);
    if (next >= 0) _fireNotice(schedule[next], NoticeTrigger.onStart);
  }

  /// Termina la actividad que está en pantalla.
  ///
  /// No es pausar: dar por buena una actividad que se acabó antes de su hora, o
  /// que se cortó a media. El conteo queda en cero y **no** suena la alerta de
  /// retraso —no se ha perdido tiempo, se ha terminado antes— y el escenario lo
  /// enseña como detenida. Volver a pulsar la reanuda con lo que le quedaba.
  void toggleStop() {
    final schedule = _schedule;
    if (schedule.isEmpty) return;

    final base = _current;
    final stopping = !base.stopped;
    _set(base.copyWith(stopped: stopping, pausedAt: null));

    // Detener es detener **todo**: la cuenta se congela y lo que esté cruzando
    // desaparece. En directo, «para la actividad» se entiende como «quita eso de
    // la pantalla», no como «déjalo ahí pasando». Por eso el aviso de «al
    // terminar» no sale por aquí —sale al pasar a la siguiente—: en mitad de un
    // «parad un momento» saltaría un texto que nadie pidió.
    if (stopping) ref.read(marqueePlaybackProvider.notifier).stop();
  }

  void togglePause() {
    final base = _current;
    if (!base.isPaused) {
      _set(base.copyWith(pausedAt: DateTime.now()));
      return;
    }

    // Lo que duró la pausa se corre el plan: al reanudar, el conteo sigue donde
    // se quedó en vez de comerse el tiempo que estuvo parado.
    final pausedFor = DateTime.now().difference(base.pausedAt!);
    _shiftPlanBy(pausedFor);
    _set(base.copyWith(pausedAt: null));
  }

  /// Reinicia el conteo de la actividad actual: vuelve a empezar desde su
  /// duración completa, como si arrancara en este momento.
  ///
  /// Su aviso vuelve a salir. Reiniciar **es** empezar la actividad otra vez —si
  /// es un DESCANSO con su «pueden salir del salón», al repetirlo se repite
  /// también— así que el texto se manda igual que al ejecutarla por primera vez.
  void restart() {
    final schedule = _schedule;
    if (schedule.isEmpty) return;

    final index = _currentIndex();
    _moveTo(index, unpause: true);
    _fireNotice(schedule[index], NoticeTrigger.onStart);
  }

  /// Cierra el evento. La actividad que estaba en pantalla se da por terminada,
  /// así que su aviso de cierre sale aquí.
  void finishEvent() {
    final schedule = _schedule;
    final playback = ref.read(marqueePlaybackProvider.notifier);
    final index = _onAirIndex(_current);

    playback.stopNotice();
    if (index >= 0) _fireNotice(schedule[index], NoticeTrigger.onEnd);
    _set(_current.copyWith(eventFinished: true));
  }

  void resumeEvent() => _set(_current.copyWith(eventFinished: false));

  /// Lanza el aviso de [activity] si toca [trigger].
  ///
  /// Va por la marquesina, no por un canal nuevo: el escenario ya sabe pintar
  /// eso, y el texto cruza con los ajustes que el operador tenga puestos. Se
  /// quita solo al cumplir su límite —un rato o un número de pasadas—, así que
  /// nadie tiene que acordarse de pararlo.
  void _fireNotice(ScheduledActivity? activity, NoticeTrigger trigger) {
    final notice = activity?.item.notice;
    if (notice == null || notice.trigger != trigger) return;
    ref.read(marqueePlaybackProvider.notifier).showNotice(notice);
  }

  /// Suma (o resta, con delta negativo) tiempo al conteo en curso.
  ///
  /// Corre el plan entero: el fin de la actividad que está en pantalla y también
  /// el inicio de las siguientes. Si a alguien le hacen falta dos minutos, se
  /// los lleva —y el resto del programa se retrasa con él—, pero el guion
  /// guardado no se toca.
  void addTime(Duration delta) => _shiftPlanBy(delta);

  /// Índice de la actividad que está al aire según [base], o `-1` si el evento
  /// todavía no ha empezado —entonces no hay nada en el escenario que cerrar—.
  ///
  /// Es distinto de [_currentIndex], que nunca devuelve negativo porque se usa
  /// para moverse por la lista: aquí interesa saber si hay algo al aire de verdad.
  int _onAirIndex(RunShowState base) {
    final schedule = _schedule;
    if (schedule.isEmpty) return -1;

    final override = base.indexOverride;
    if (override != null) return override.clamp(0, schedule.length - 1);

    return resolveRunIndex(
      schedule,
      base.effectiveNow(ref.read(clockProvider)),
    );
  }

  /// Índice efectivo: el fijado si lo hay, si no el que deduce el reloj.
  ///
  /// Sin índice fijado solo se está esperando a que empiece el evento; en cuanto
  /// llega, [clockProvider] lo clava y este caso deja de darse.
  int _currentIndex() {
    final schedule = _schedule;
    if (schedule.isEmpty) return 0;

    final base = _current;
    final override = base.indexOverride;
    if (override != null) return override.clamp(0, schedule.length - 1);

    final auto = resolveRunIndex(
      schedule,
      base.effectiveNow(ref.read(clockProvider)),
    );
    return auto < 0 ? 0 : auto;
  }
}

/// Estado del directo de cada programa, indexado por [stageSourceIdProvider].
///
/// Es lo que sobrevive a los cambios de fuente: el notifier se reconstruye al
/// cambiar de día y este mapa le devuelve el estado que tenía ese día, con su
/// actividad en pantalla y sus marcas de pausa o de parada.
class RunShowStore extends Notifier<Map<String?, RunShowState>> {
  @override
  Map<String?, RunShowState> build() => const {};

  void put(RunShowState next) => state = {...state, next.sourceId: next};
}

final runStoreProvider =
    NotifierProvider<RunShowStore, Map<String?, RunShowState>>(
      RunShowStore.new,
    );

final runShowProvider = NotifierProvider<RunShowNotifier, RunShowState>(
  RunShowNotifier.new,
);
