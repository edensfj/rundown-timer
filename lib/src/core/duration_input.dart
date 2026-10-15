/// Lectura de duraciones escritas a mano.
///
/// En una plantilla se piensa tanto en minutos («45 de prédica») como en horas
/// («2 h de taller»), así que el campo acepta ambas y se encarga de entenderlo.
/// Formatos admitidos (mayúsculas y espacios dan igual):
///
/// ```
/// 45          → 45 min
/// 45m         → 45 min
/// 1:30        → 1 h 30 min
/// 2h          → 2 h
/// 2h30        → 2 h 30 min
/// 2h30m       → 2 h 30 min
/// 1.5h        → 1 h 30 min
/// 1,5h        → 1 h 30 min   (coma decimal, como se escribe en español)
/// 0.5m        → 30 s         (minutos con parte decimal)
/// 30s         → 30 s
/// 1m30s       → 1 min 30 s
/// ```
///
/// Las duraciones cortas importan: en un rundown una cuenta atrás de 30 segundos
/// es tan normal como una prédica de 45 minutos.
library;

final RegExp _horasMinutos = RegExp(r'^(\d+):(\d{1,2})$');
final RegExp _decimalHoras = RegExp(
  r'^(\d+)[.,](\d+)\s*(?:h|hr|hrs|hora|horas)$',
);
final RegExp _decimalMinutos = RegExp(
  r'^(\d+)[.,](\d+)\s*(?:m|min|mins|minuto|minutos)$',
);
final RegExp _conHoras = RegExp(
  r'^(\d+)\s*(?:h|hr|hrs|hora|horas)\s*(?:(\d+)\s*(?:m|min|mins|minuto|minutos)?)?$',
);
final RegExp _conMinutosYSegundos = RegExp(
  r'^(\d+)\s*(?:m|min|mins|minuto|minutos)\s*(\d+)\s*(?:s|seg|segs|segundo|segundos)?$',
);
final RegExp _soloSegundos = RegExp(
  r'^(\d+)\s*(?:s|seg|segs|segundo|segundos)$',
);
final RegExp _soloMinutos = RegExp(r'^(\d+)\s*(?:m|min|mins|minuto|minutos)?$');

/// Devuelve la duración escrita, o `null` si no se entiende o no es positiva.
Duration? parseDuration(String raw) {
  final texto = raw.trim().toLowerCase();
  if (texto.isEmpty) return null;

  // "1:30" — hora y minutos separados por dos puntos.
  final reloj = _horasMinutos.firstMatch(texto);
  if (reloj != null) {
    return _construir(int.parse(reloj.group(1)!), int.parse(reloj.group(2)!));
  }

  // "1.5h" / "1,5h" — horas con parte decimal.
  final decimalHoras = _decimalHoras.firstMatch(texto);
  if (decimalHoras != null) {
    final entero = int.parse(decimalHoras.group(1)!);
    final fraccion = double.parse('0.${decimalHoras.group(2)!}');
    return _construir(entero, (fraccion * 60).round());
  }

  // "0.5m" / "2,5min" — minutos con parte decimal.
  final decimalMinutos = _decimalMinutos.firstMatch(texto);
  if (decimalMinutos != null) {
    final entero = int.parse(decimalMinutos.group(1)!);
    final fraccion = double.parse('0.${decimalMinutos.group(2)!}');
    return _construir(
      0,
      entero,
      segundos: (fraccion * 60).round(),
      validarMinutos: false,
    );
  }

  // "2h", "2h30", "2h30m", "2 horas".
  final conH = _conHoras.firstMatch(texto);
  if (conH != null) {
    final minutos = conH.group(2) == null ? 0 : int.parse(conH.group(2)!);
    return _construir(int.parse(conH.group(1)!), minutos);
  }

  // "1m30s" / "1min 30seg".
  final minYSeg = _conMinutosYSegundos.firstMatch(texto);
  if (minYSeg != null) {
    return _construir(
      0,
      int.parse(minYSeg.group(1)!),
      segundos: int.parse(minYSeg.group(2)!),
      validarMinutos: false,
    );
  }

  // "30s" / "30 segundos".
  final soloSeg = _soloSegundos.firstMatch(texto);
  if (soloSeg != null) {
    return _construir(0, 0, segundos: int.parse(soloSeg.group(1)!));
  }

  // "45", "45m", "45 minutos".
  final soloMin = _soloMinutos.firstMatch(texto);
  if (soloMin != null) {
    // Aquí los minutos NO se validan contra 59: "90" son 90 minutos, no 1:90.
    return _construir(0, int.parse(soloMin.group(1)!), validarMinutos: false);
  }

  return null;
}

Duration? _construir(
  int horas,
  int minutos, {
  int segundos = 0,
  bool validarMinutos = true,
}) {
  // En formatos con hora, un «1:75» es un error de escritura y hay que avisar.
  // En minutos sueltos no aplica: 90 es una hora y media.
  if (validarMinutos && minutos > 59) return null;

  final total = Duration(hours: horas, minutes: minutos, seconds: segundos);
  return total > Duration.zero ? total : null;
}

/// Texto inicial del campo, en el formato más natural para cada duración.
///
/// Se usa al abrir una plantilla o una actividad guardada para que el usuario
/// vuelva a leer lo mismo que escribió, más o menos.
String formatDurationInput(Duration duration) {
  // Por debajo del minuto se cuenta en segundos: «30», sin más, se leería como
  // media hora.
  if (duration.inMinutes < 1) return '${duration.inSeconds}s';

  final totalMin = duration.inMinutes;
  if (totalMin < 60) {
    // Un resto de segundos («1m30s») se conserva: es un dato, no ruido.
    final resto = duration.inSeconds % 60;
    return resto == 0 ? '$totalMin' : '${totalMin}m${resto}s';
  }

  final horas = duration.inHours;
  final resto = totalMin % 60;
  return resto == 0
      ? '${horas}h'
      : '$horas:${resto.toString().padLeft(2, '0')}';
}
