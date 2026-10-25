import 'package:intl/intl.dart';

import 'app_config.dart';

/// Formateo centralizado de fechas y horas.
///
/// Todo se muestra en formato 12h (AM/PM) con locale español, lo que produce
/// marcadores como «10:30 a. m.». Los datos de locale deben inicializarse con
/// `initializeDateFormatting` antes de usar estos formatos.
class TimeFormatters {
  TimeFormatters._();

  static final DateFormat _time = DateFormat('h:mm a', 'es');
  static final DateFormat _timeWithSeconds = DateFormat('h:mm:ss a', 'es');
  static final DateFormat _fullDate = DateFormat(
    "EEEE d 'de' MMMM 'de' y",
    'es',
  );
  static final DateFormat _shortDate = DateFormat('EEE d MMM', 'es');
  static final DateFormat _dayName = DateFormat('EEEE', 'es');

  /// `10:30 a. m.`
  static String time(DateTime value) => _time.format(value);

  /// `10:30:45 a. m.` — para el reloj de la cabecera.
  static String timeWithSeconds(DateTime value) =>
      _timeWithSeconds.format(value);

  /// `14:05:07` en 24 h — para el modo reloj del escenario.
  ///
  /// A propósito sin AM/PM: en la pantalla solo hay dígitos, y en 24 h no hay
  /// ambigüedad. No usa `intl`: no depende del locale.
  static String stageClock(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  /// `2:05:07 p. m.` — el mismo formato 12 h del resto de la app, para el modo
  /// reloj cuando el operador lo prefiere así.
  static String stageClock12(DateTime value) => _timeWithSeconds.format(value);

  /// `sábado, 18 de octubre de 2026`
  static String fullDate(DateTime value) => _fullDate.format(value);

  /// `sáb 18 oct`
  static String shortDate(DateTime value) => _shortDate.format(value);

  /// `sábado`
  static String dayName(DateTime value) => _dayName.format(value);

  /// `miércoles 14` — nombre por defecto de un día: el que sugiere el diálogo
  /// de creación y el que se usa al crear el día de hoy automáticamente.
  static String dayLabel(DateTime value) => '${dayName(value)} ${value.day}';

  /// Convierte un [DateTime] a medianoche local (sin hora ni minutos).
  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Coloca una hora concreta sobre la fecha [dayDate].
  static DateTime at(DateTime dayDate, int hour, int minute) =>
      DateTime(dayDate.year, dayDate.month, dayDate.day, hour, minute);

  /// Hora de inicio sugerida: la hora actual redondeada hacia arriba al
  /// siguiente bloque de [AppConfig.startTimeRounding], anclada al día del evento.
  static DateTime defaultStartForDay(DateTime dayDate, {DateTime? reference}) {
    final now = reference ?? DateTime.now();
    final slot = AppConfig.startTimeRounding.inMinutes;
    final minutesOfDay = now.hour * 60 + now.minute;
    // El clamp evita que un redondeo a medianoche se salga del día del evento.
    final rounded = ((minutesOfDay / slot).ceil() * slot).clamp(
      0,
      24 * 60 - slot,
    );
    return DateTime(
      dayDate.year,
      dayDate.month,
      dayDate.day,
    ).add(Duration(minutes: rounded));
  }

  /// Formatea el countdown: `MM:SS`, o `H:MM:SS` cuando supera la hora.
  ///
  /// Las duraciones negativas conservan el signo al inicio (`-01:15`) para
  /// mostrar los minutos exactos de retraso.
  static String countdown(Duration duration) {
    final totalSeconds = duration.abs().inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    final body = hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';

    return duration.isNegative ? '-$body' : body;
  }

  /// `1 h 15 min`, `45 min`, `30 s` — para duraciones planned en las tarjetas.
  static String humanDuration(Duration duration) {
    final totalSeconds = duration.abs().inSeconds;
    if (totalSeconds < 60) return '$totalSeconds s';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '$hours h';
    return '$hours h $minutes min';
  }

  /// `105 min` — el equivalente exacto de una duración que lleva horas.
  ///
  /// Devuelve `null` cuando [humanDuration] ya se expresa en minutos o
  /// segundos, para no repetir «45 min» al lado de «45 min».
  static String? minutesEquivalent(Duration duration) {
    final totalSeconds = duration.abs().inSeconds;
    if (totalSeconds < 3600) return null;
    return '${duration.abs().inMinutes} min';
  }

  /// `+1 h 15 min` / `-15 min`, para indicar retraso o adelanto.
  static String signedHumanDuration(Duration duration) {
    final sign = duration.isNegative ? '-' : '+';
    return '$sign${humanDuration(duration)}';
  }
}
