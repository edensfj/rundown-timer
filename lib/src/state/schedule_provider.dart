import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_config.dart';
import '../models/activity_item.dart';
import '../models/event_day.dart';
import '../models/scheduled_activity.dart';
import 'clock_provider.dart';
import 'on_air_provider.dart';
import 'quick_timer_provider.dart';
import 'rundown_provider.dart';
import 'run_show_provider.dart';
import 'selected_day_provider.dart';

/// Día actualmente en edición.
///
/// Si el día guardado ya no existe (fue borrado en otra sesión), cae al
/// primero disponible para no dejar al usuario sin contexto.
final activeDayProvider = Provider<EventDay?>((ref) {
  final days = ref.watch(sortedDaysProvider);
  if (days.isEmpty) return null;

  final selectedId = ref.watch(selectedDayProvider);
  if (selectedId != null) {
    for (final day in days) {
      if (day.id == selectedId) return day;
    }
  }
  return days.first;
});

/// Id del día actualmente en edición (o `null` si no hay días).
final activeDayIdProvider = Provider<String?>(
  (ref) => ref.watch(activeDayProvider)?.id,
);

/// Día del que sale **lo que se proyecta**, que no siempre es el que se está
/// editando.
///
/// Si hay un día en el aire ([onAirDayIdProvider]) manda ese: el operador
/// arrancó algo y mientras eso siga en marcha puede ir mirando otro día sin que
/// la pantalla se mueva. Si no hay nada en el aire, el escenario sigue al día
/// seleccionado, que es lo que se espera al estar programando.
final stageDayProvider = Provider<EventDay?>((ref) {
  final onAirId = ref.watch(onAirDayIdProvider);
  if (onAirId != null) {
    for (final day in ref.watch(sortedDaysProvider)) {
      if (day.id == onAirId) return day;
    }
  }

  return ref.watch(activeDayProvider);
});

/// Id del día que se proyecta, para poder preguntar «¿es el mismo que estoy
/// viendo?» sin traer el día entero.
final stageDayIdProvider = Provider<String?>(
  (ref) => ref.watch(stageDayProvider)?.id,
);

/// Identifica **de dónde sale lo que se está proyectando**: el itinerario del
/// día o un contador suelto.
///
/// El estado del escenario observa este valor para reiniciarse cuando la fuente
/// cambia. Sin esto, al pasar de un contador al itinerario el índice guardado
/// podría apuntar a una actividad que ya no existe.
///
/// También entra el arranque del ensayo: al activarlo las actividades cambian
/// de hora, así que el estado del escenario vuelve a empezar y sigue el reloj
/// desde el principio en vez de quedarse en un índice de la fecha anterior.
final stageSourceIdProvider = Provider<String?>((ref) {
  final quick = ref.watch(quickTimerProvider);
  if (quick != null) return 'quick:${quick.id}';

  final day = ref.watch(stageDayProvider);
  if (day == null) return null;
  final anchor = day.forceRunAt;
  return 'day:${day.id}${anchor == null ? '' : ':run@$anchor'}';
});

/// El día natural de hoy, a medianoche.
///
/// Depende del reloj global, pero como dos días seguidos dan el mismo valor, el
/// resto de providers que lo observan **no** se reconstruyen segundo a segundo:
/// Riverpod solo avisa cuando el valor cambia de verdad.
final todayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(clockProvider);
  return DateTime(now.year, now.month, now.day);
});

/// Instante por el que arranca el día que se está ejecutando por el operador.
///
/// Es el que se guardó al activar la opción. Si se quedó en un día anterior se
/// reancla a la misma hora de hoy: si no, al volver a abrir la app al día
/// siguiente el programa entero aparecería como terminado.
final runAnchorProvider = Provider<DateTime?>((ref) {
  final anchor = ref.watch(activeDayProvider)?.forceRunAt;
  if (anchor == null) return null;

  final today = ref.watch(todayProvider);
  if (!anchor.isBefore(today)) return anchor;
  return DateTime(
    today.year,
    today.month,
    today.day,
    anchor.hour,
    anchor.minute,
  );
});

/// Cronograma del **día** que se está editando, con las horas de fin inferidas.
///
/// Son **las horas del programa, tal y como se escribieron**. Ni el arranque de
/// un ensayo ni los saltos que el operador da durante el directo tocan esta
/// lista: el panel muestra siempre el guion, y las horas de verdad son las del
/// escenario ([activeScheduleProvider]). Si el programa se moviera también en el
/// panel, al corregir el retraso de un directo el operador vería su guion
/// descuadrado y no sabría qué había preparado.
///
/// No lo toca el contador rápido, que es algo suelto y no forma parte del
/// programa del día.
final dayScheduleProvider = Provider<List<ScheduledActivity>>(
  (ref) => resolveDaySchedule(ref.watch(activeDayProvider)),
);

/// Cronograma de un día tal como está escrito, con las horas de fin inferidas.
///
/// Lo usa tanto el guion que se ve en el panel ([dayScheduleProvider]) como el
/// que se proyecta ([activeScheduleProvider]); lo que los separa no son las
/// actividades, sino de qué día se han cogido: el panel muestra el que se está
/// editando y el escenario, el que está en el aire.
List<ScheduledActivity> resolveDaySchedule(EventDay? day) {
  if (day == null) return const [];

  return resolveSchedule(
    day.activities,
    lastDuration: AppConfig.defaultLastActivityDuration,
  );
}

/// Cuánto se ha movido el plan a mano durante el directo, **por programa**.
///
/// El operador es el que manda: cuando pone una actividad en el escenario o le
/// da un minuto más, el plan entero se corre esa cantidad para que las horas que
/// se ven sean las reales.
///
/// Va indexado por [stageSourceIdProvider] y no en un solo valor porque cada día
/// lleva la cuenta aparte: el desfase del directo de hoy no puede arrastrar al
/// guion de mañana. Con un único valor, mirar otro día y volver lo desmontaba
/// entero y la actividad en pantalla se caía de golpe.
class PlanShiftStore extends Notifier<Map<String, Duration>> {
  @override
  Map<String, Duration> build() => const {};

  void add(String source, Duration delta) {
    if (delta == Duration.zero) return;
    state = {...state, source: (state[source] ?? Duration.zero) + delta};
  }

  void reset(String source) {
    if (!state.containsKey(source)) return;
    state = {...state}..remove(source);
  }
}

final planShiftStoreProvider =
    NotifierProvider<PlanShiftStore, Map<String, Duration>>(PlanShiftStore.new);

/// El desfase que le toca a la fuente que se está proyectando.
final planShiftProvider = Provider<Duration>((ref) {
  final source = ref.watch(stageSourceIdProvider) ?? '';
  return ref.watch(planShiftStoreProvider)[source] ?? Duration.zero;
});

/// Cronograma que se está **proyectando**: el del día en el aire (o el que se
/// está editando, si no hay ninguno), corrido a la hora real, o el contador
/// rápido.
///
/// Sobre el programa del día ([stageScheduleProvider]) se suman **los dos
/// desfases** que solo tienen sentido mientras se proyecta:
///
/// - El arranque del ensayo ([runAnchorProvider]), si el día se está ejecutando
///   aunque su fecha todavía no haya llegado: la primera actividad empieza en el
///   instante en que el operador le dio al play.
/// - Los saltos del directo ([planShiftProvider]): cada vez que el operador pone
///   una actividad en marcha, le da un minuto más o salta a otra, el plan se
///   corre esa cantidad.
///
/// El resultado es que el escenario enseña horas de verdad —inicio, fin, término
/// programado y la siguiente— mientras el panel sigue enseñando el guion tal
/// cual se escribió. Eso es justo lo que se necesita en directo: la sala ve la
/// hora real y el operador, el programa.
///
/// Con un contador rápido activo se construye un cronograma virtual de una sola
/// actividad: así todo el motor del escenario (countdown, fases, alerta roja,
/// pausa, reinicio) funciona igual sin duplicar una línea de lógica.
final activeScheduleProvider = Provider<List<ScheduledActivity>>((ref) {
  final quick = ref.watch(quickTimerProvider);

  if (quick != null) {
    return resolveSchedule([
      ActivityItem(
        id: quick.id,
        title: quick.label,
        startTime: quick.startedAt,
        // Con hora de fin explícita, la duración pedida manda.
        endTime: quick.endsAt,
      ),
    ]);
  }

  final day = ref.watch(stageDayProvider);
  final anchor = day == null ? null : ref.watch(runAnchorProvider);
  final shift =
      (anchor != null && day != null
          ? day.shiftToStartAt(anchor)
          : Duration.zero) +
      ref.watch(planShiftProvider);

  return shiftSchedule(resolveDaySchedule(day), shift);
});

/// Estado de cada actividad (pasada / en curso / futura) en la lista.
///
/// Cuando el escenario tiene una actividad fija en pantalla, manda el
/// escenario: el operador salta a mano —a la tercera aunque sea la primera la
/// que «tocaría» por la hora— y el «en curso» de la lista tiene que moverse con
/// él, o la lista y lo proyectado acabarían diciendo cosas distintas.
///
/// Con un contador suelto activo, en cambio, la lista del día sigue con sus
/// horas: el contador no forma parte del programa.
///
/// Sin nada fijado se recurre al reloj, que es lo que se ve programando.
///
/// Y si hay otro día en el escenario, la lista va a lo suyo: el «en curso» que se
/// ve al revisar mañana no es el del directo de hoy.
final activityStatusProvider = Provider<Map<String, ActivityStatus>>((ref) {
  final schedule = ref.watch(dayScheduleProvider);
  if (schedule.isEmpty) return const {};

  final runIndex = ref.watch(
    runShowProvider.select((run) => run.indexOverride),
  );
  final isDayRun =
      ref.watch(quickTimerProvider) == null &&
      ref.watch(stageDayIdProvider) == ref.watch(activeDayIdProvider);

  if (runIndex != null && isDayRun) {
    final current = runIndex.clamp(0, schedule.length - 1);
    return {
      for (var i = 0; i < schedule.length; i++)
        schedule[i].item.id: i < current
            ? ActivityStatus.past
            : i == current
            ? ActivityStatus.active
            : ActivityStatus.upcoming,
    };
  }

  final now = ref.watch(clockProvider);
  return {for (final slot in schedule) slot.item.id: slot.statusAt(now)};
});
