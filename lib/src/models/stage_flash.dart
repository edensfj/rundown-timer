import 'package:flutter/material.dart';

import '../models/countdown_phase.dart';
import '../models/countdown_snapshot.dart';

/// Decide de qué color —si de alguno— parpadea a pantalla completa el escenario.
///
/// Tres avisos, por orden de prioridad:
///
/// 1. **Rojo** cuando se pasa del tiempo programado (lo de siempre).
/// 2. **Naranja** en los últimos segundos de la actividad, para anticipar el
///    final.
/// 3. **Verde** unos instantes al empezar una actividad nueva, para cantar el
///    cambio.
///
/// La detección del cambio necesita memoria —hay que comparar con la actividad
/// anterior—, y por eso vive en un objeto con estado y no en el provider
/// derivado, que es puro. Es lógica sin widgets a propósito, para poder probarla
/// sin levantar la pantalla entera.
class StageFlashTracker {
  StageFlashTracker({
    this.changeDuration = const Duration(seconds: 3),
    this.endingWindow = const Duration(seconds: 5),
  });

  /// Cuánto dura el destello verde tras un cambio de actividad.
  final Duration changeDuration;

  /// Con este tiempo o menos por delante, empieza el destello naranja.
  final Duration endingWindow;

  String? _lastActivityId;
  CountdownPhase? _lastPhase;
  DateTime? _changedAt;

  /// El color del destello para [snapshot] en el instante [now], o `null` si la
  /// pantalla debe quedarse en negro.
  Color? update(CountdownSnapshot snapshot, DateTime now) {
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

    if (phase == CountdownPhase.overtime) return StageColors.alert;
    if (phase == CountdownPhase.finished || phase == CountdownPhase.preShow) {
      return null;
    }

    // Últimos segundos: naranja. Manda sobre el verde de un cambio reciente
    // (por ejemplo, una actividad muy corta).
    if (snapshot.remaining > Duration.zero &&
        snapshot.remaining <= endingWindow) {
      return StageColors.ending;
    }

    final changedAt = _changedAt;
    if (changedAt != null && now.difference(changedAt) < changeDuration) {
      return StageColors.change;
    }
    return null;
  }
}
