import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lo que se proyecta en la ventana del escenario.
enum StageMode {
  /// La cuenta atrás de la actividad en curso (lo de siempre).
  countdown('Cuenta atrás'),

  /// La hora actual, a lo grande. Para marcar la hora en la pantalla sin
  /// necesidad de tener un itinerario en marcha.
  clock('Hora actual');

  const StageMode(this.label);

  final String label;
}

/// Modo de proyección elegido por el operador.
///
/// Viaja al escenario dentro de la instantánea (ver `showClock` en
/// [CountdownSnapshot]), por el mismo canal que el reloj: así llega igual a
/// la segunda ventana de Windows y al proceso aparte de Linux, sin canal
/// nuevo. No se persiste: al abrir la app siempre se empieza contando.
class StageModeNotifier extends Notifier<StageMode> {
  @override
  StageMode build() => StageMode.countdown;

  void setMode(StageMode mode) {
    if (state != mode) state = mode;
  }
}

final stageModeProvider = NotifierProvider<StageModeNotifier, StageMode>(
  StageModeNotifier.new,
);

/// Formato de la hora en el modo reloj del escenario.
enum StageClockFormat {
  /// `14:05:07`. Sin ambigüedad y solo dígitos.
  h24('24 h'),

  /// `2:05:07 p. m.`, como el resto de la app.
  h12('12 h');

  const StageClockFormat(this.label);

  final String label;
}

/// Formato elegido por el operador. Como el modo, viaja al escenario dentro
/// de la instantánea y no se persiste.
class StageClockFormatNotifier extends Notifier<StageClockFormat> {
  @override
  StageClockFormat build() => StageClockFormat.h24;

  void setFormat(StageClockFormat format) {
    if (state != format) state = format;
  }
}

final stageClockFormatProvider =
    NotifierProvider<StageClockFormatNotifier, StageClockFormat>(
      StageClockFormatNotifier.new,
    );
