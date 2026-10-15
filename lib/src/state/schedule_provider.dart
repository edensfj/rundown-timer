import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_config.dart';
import '../models/activity_item.dart';
import '../models/event_day.dart';
import '../models/scheduled_activity.dart';
import 'clock_provider.dart';
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

  final day = ref.watch(activeDayProvider);
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
/// Es lo que pinta la lista del panel: no lo toca el contador rápido, que es
/// algo suelto y no forma parte del programa del día. Si un contador rápido
/// activo cambiara esta lista, la programación del día parecería borrada.
final dayScheduleProvider = Provider<List<ScheduledActivity>>((ref) {
  final day = ref.watch(activeDayProvider);
  if (day == null) return const [];

  // Un día en marcha se lee desplazado: la primera actividad empieza en el
  // instante en que el operador le dio al play y las siguientes caen donde
  // toquen, respetando su duración y sus huecos.
  final anchor = ref.watch(runAnchorProvider);
  final activities = anchor == null
      ? day.activities
      : day.activitiesStartingAt(anchor);

  return resolveSchedule(
    activities,
    lastDuration: AppConfig.defaultLastActivityDuration,
  );
});

/// Cronograma que se está **proyectando**: el del día, o el contador rápido.
///
/// Con un contador rápido activo se construye un cronograma virtual de una sola
/// actividad: así todo el motor del escenario (countdown, fases, alerta roja,
/// pausa, reinicio) funciona igual sin duplicar una línea de lógica. Ojo: esto
/// es solo para el escenario; la lista del panel usa [dayScheduleProvider].
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

  return ref.watch(dayScheduleProvider);
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
final activityStatusProvider = Provider<Map<String, ActivityStatus>>((ref) {
  final schedule = ref.watch(dayScheduleProvider);
  if (schedule.isEmpty) return const {};

  final runIndex = ref.watch(
    runShowProvider.select((run) => run.indexOverride),
  );
  final isDayRun = ref.watch(quickTimerProvider) == null;

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
