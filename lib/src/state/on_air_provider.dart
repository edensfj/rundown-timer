import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Id del día que el **escenario** está proyectando, cuando el operador ha
/// decidido que ese día manda por encima del que está mirando en la lista.
///
/// Sin esto, pasar de día en el selector paraba el directo: como la fuente del
/// escenario era el día seleccionado, al pinchar otro día el estado se reiniciaba
/// a cero y la pantalla se caía a la cuenta previa del nuevo —a veces 79 horas,
/// a veces un día vacío («no hay nada que presentar»)— mientras el operador solo
/// quería revisar el guion de mañana.
///
/// Se toma al ejecutar algo ([take]) y se suelta cuando el operador dice que
/// manda el reloj o el día que está viendo ([release]).
class OnAirDayNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Pone [dayId] en el escenario.
  void take(String? dayId) {
    if (state == dayId) return;
    state = dayId;
  }

  /// Devuelve el escenario al día que se está editando.
  void release() => take(null);

  /// Suelta el aire **solo si lo tiene ese día**: para no descolocar al operador
  /// que ya tiene otro en pantalla.
  void releaseDay(String dayId) {
    if (state == dayId) release();
  }
}

final onAirDayIdProvider = NotifierProvider<OnAirDayNotifier, String?>(
  OnAirDayNotifier.new,
);
