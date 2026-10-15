import 'package:flutter/material.dart';

import '../models/countdown_phase.dart';
import '../models/countdown_snapshot.dart';

/// Decide de qué color —si de alguno— parpadea a pantalla completa el escenario.
///
/// Tres avisos, por orden de prioridad:
///
/// 1. **Rojo** cuando se pasa del tiempo programado (lo de siempre).
/// 2. **Naranja** en los últimos minutos o segundos de la actividad, para
///    anticipar el final.
/// 3. **Verde** unos instantes al empezar una actividad nueva, para cantar el
///    cambio.
///
/// Cuánto dura cada destello y cuál está encendido lo dice
/// [CountdownSnapshot.flashSettings], que el operador ajusta en el diálogo de
/// parpadeos. El rojo es el único sin interruptor propio: con los parpadeos
/// encendidos, siempre avisa al acabarse el tiempo.
///
/// La detección del cambio necesita memoria —hay que comparar con la actividad
/// anterior—, y por eso vive en un objeto con estado y no en el provider
/// derivado, que es puro. Es lógica sin widgets a propósito, para poder probarla
/// sin levantar la pantalla entera.
class StageFlashTracker {
  StageFlashTracker();

  String? _lastActivityId;
  CountdownPhase? _lastPhase;
  DateTime? _changedAt;

  /// El color del destello para [snapshot] en el instante [now], o `null` si la
  /// pantalla debe quedarse en negro.
  ///
  /// Los ajustes se leen de la propia instantánea ([CountdownSnapshot
  /// .flashSettings]): así el escenario —que corre en otro proceso— los obedece
  /// sin más, sin un canal aparte.
  Color? update(CountdownSnapshot snapshot, DateTime now) {
    final settings = snapshot.flashSettings;

    // En modo reloj no hay nada que avisar, y sin actividades tampoco.
    if (snapshot.showClock || !snapshot.hasActivities) {
      _lastActivityId = null;
      _lastPhase = null;
      _changedAt = null;
      return null;
    }

    final id = snapshot.current?.item.id;
    final phase = snapshot.phase;

    // Cambio de actividad: por el reloj (pasó de hora) o por el botón de
    // «siguiente». También cuenta el arranque de la primera, que pasa de
    // «próxima actividad» a «en curso» sin cambiar de id.
    final changedActivity =
        _lastActivityId != null && id != null && id != _lastActivityId;
    final startedFirst =
        _lastPhase == CountdownPhase.preShow && phase == CountdownPhase.normal;
    if (changedActivity || startedFirst) _changedAt = now;

    _lastActivityId = id;
    _lastPhase = phase;

    // Interruptor maestro: apagado, la pantalla no parpadea por nada. La memoria
    // del cambio se sigue actualizando arriba para que, al volver a encenderlo,
    // no salte un verde de un cambio que ya pasó.
    if (!settings.enabled) return null;

    // Rojo del tiempo excedido: sin interruptor, es el aviso que no puede
    // faltar mientras los parpadeos estén encendidos.
    if (phase == CountdownPhase.overtime) return StageColors.alert;
    if (phase == CountdownPhase.finished || phase == CountdownPhase.preShow) {
      return null;
    }

    // Últimos instantes: naranja. Manda sobre el verde de un cambio reciente
    // (por ejemplo, una actividad muy corta).
    if (settings.endingEnabled &&
        snapshot.remaining > Duration.zero &&
        snapshot.remaining <= settings.endingWindow) {
      return StageColors.ending;
    }

    final changedAt = _changedAt;
    if (settings.changeEnabled &&
        changedAt != null &&
        now.difference(changedAt) < settings.changeDuration) {
      return StageColors.change;
    }
    return null;
  }
}
