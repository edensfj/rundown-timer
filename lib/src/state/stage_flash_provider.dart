import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stage_flash.dart';
import 'countdown_provider.dart';

/// A qué actividad pertenece el destello del escenario y de qué color es.
@immutable
class StageFlashState {
  const StageFlashState({this.activityId, this.color});

  /// `null` si no hay ninguna actividad en pantalla.
  final String? activityId;

  /// Verde (cambio), naranja (va a terminar) o rojo (se pasó de tiempo).
  /// `null` si el escenario está en negro.
  final Color? color;

  bool get isActive => color != null && activityId != null;

  /// `true` si este destello es el de [activityId].
  bool concerns(String id) => isActive && activityId == id;
}

/// El destello que el escenario está dando, visto desde el panel.
///
/// Es **el mismo** que ve la sala, no uno parecido: si la pantalla parpadea de
/// verde y el panel dice otra cosa, el operador ya no se fía de ninguno de los
/// dos. Por eso se decide con el mismo [StageFlashTracker] y sobre la misma
/// instantánea que se envía al escenario.
///
/// Aquí no parpadea: el color se queda fijo en el fondo de la tarjeta mientras
/// dure el aviso. Un panel que da lustre cada tres segundos es ilegible; lo que
/// hace falta es ver de un vistazo por qué está parpadeando lo de delante.
class StageFlashNotifier extends Notifier<StageFlashState> {
  /// Necesita memoria del estado anterior para saber que ha cambiado de
  /// actividad, así que es un notifier y no un provider derivado.
  final StageFlashTracker _tracker = StageFlashTracker();

  @override
  StageFlashState build() {
    final snapshot = ref.watch(countdownProvider);
    return StageFlashState(
      activityId: snapshot.current?.item.id,
      color: _tracker.update(snapshot, DateTime.now()),
    );
  }
}

final stageFlashProvider =
    NotifierProvider<StageFlashNotifier, StageFlashState>(
      StageFlashNotifier.new,
    );
