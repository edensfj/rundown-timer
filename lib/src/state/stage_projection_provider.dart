import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hive_boxes.dart';
import '../data/rundown_repository.dart';

/// Si el escenario proyecta la cuenta atrás **antes** de que empiece el evento.
///
/// Apagado por defecto. Programando un evento que es de mañana, una pantalla
/// con «faltan 79 horas» no informa de nada: es ruido en el proyector y, peor,
/// parece que hay algo en marcha. Con esto apagado, la pantalla se queda en
/// negro hasta que el operador pone algo en el aire —con el botón de ejecutar de
/// una tarjeta, con «empezar ahora» en el día, o solo cuando llegue la hora— y
/// entonces aparece la cuenta.
///
/// Se persiste: es una forma de trabajar, no un estado de este momento.
class ShowPreShowCountdownNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(repositoryProvider).loadFlag(showPreShowCountdownKey);

  void set(bool value) {
    if (state == value) return;
    state = value;
    ref.read(repositoryProvider).saveFlag(showPreShowCountdownKey, value);
  }
}

final showPreShowCountdownProvider =
    NotifierProvider<ShowPreShowCountdownNotifier, bool>(
      ShowPreShowCountdownNotifier.new,
    );
