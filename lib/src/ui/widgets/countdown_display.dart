import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/time_formatters.dart';
import '../../models/countdown_phase.dart';
import '../../models/countdown_snapshot.dart';

/// El reloj principal del modo escenario. Es lo más importante de la pantalla,
/// así que se lleva todo el espacio disponible.
///
/// Dos decisiones hacen que sea realmente grande:
///
/// 1. **Fuente condensada** ([AppConfig.countdownFontFamily]): los dígitos son
///    mucho más estrechos, así que al ajustarse al ancho de la pantalla crecen
///    proporcionalmente en alto. Con una fuente normal, `MM:SS` en una pantalla
///    16:9 queda limitado por el ancho y desperdicia media pantalla.
/// 2. **Sin márgenes laterales**: el bloque llega a los bordes.
///
/// El tamaño base es enorme y [FittedBox] lo reduce hasta encajar, de modo que
/// el resultado se adapta a cualquier resolución o proyector.
class CountdownDisplay extends StatelessWidget {
  const CountdownDisplay({
    super.key,
    required this.snapshot,
    required this.alertPulse,
  });

  final CountdownSnapshot snapshot;
  final Animation<double> alertPulse;

  /// Fuente base deliberadamente enorme: `scaleDown` la ajusta al hueco.
  static const double _baseFontSize = 1000;

  /// Alto mínimo para que el subtítulo («Término programado · …») quepa junto a
  /// los dígitos. Por debajo, se muestra solo el reloj.
  static const double _minHeightForSubtitle = 56;

  @override
  Widget build(BuildContext context) {
    final phase = snapshot.phase;

    // Sin badge de estado a propósito: los dígitos gigantes ya comunican todo.
    // «En curso» o «Tiempo excedido» solo ocupaban pantalla y robaban altura al
    // reloj, que es lo único que importa desde la última fila.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Con muy poco alto el subtítulo no cabe y desbordaría, que Flutter
        // pinta como una banda amarilla sobre el reloj. Antes que eso, los
        // dígitos solos: siguen siendo lo importante.
        final cabeSubtitulo = constraints.maxHeight >= _minHeightForSubtitle;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: AnimatedBuilder(
                animation: alertPulse,
                builder: (context, _) => FittedBox(
                  fit: BoxFit.scaleDown,
                  child: phase == CountdownPhase.finished
                      ? const _FinishedMessage()
                      : Text(
                          TimeFormatters.countdown(snapshot.remaining),
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: AppConfig.countdownFontFamily,
                            fontSize: _baseFontSize,
                            height: 1.0,
                            fontWeight: FontWeight.w700,
                            color: phase.foreground,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                ),
              ),
            ),
            if (cabeSubtitulo) ...[
              const SizedBox(height: 10),
              Text(
                _subtitle(snapshot),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: phase.foreground.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  String _subtitle(CountdownSnapshot snapshot) {
    final phase = snapshot.phase;
    final slot = snapshot.current;

    if (phase == CountdownPhase.finished) {
      return 'Puedes cerrar la vista de escenario';
    }
    if (phase == CountdownPhase.preShow) {
      return slot == null
          ? ''
          : 'Primera actividad · ${TimeFormatters.time(slot.startTime)}';
    }
    if (snapshot.isPaused) {
      return 'En pausa · ${TimeFormatters.time(slot!.startTime)}';
    }
    if (snapshot.remaining.isNegative) {
      return 'Retraso acumulado · '
          '${TimeFormatters.signedHumanDuration(snapshot.remaining)}';
    }
    return 'Término programado · ${TimeFormatters.time(slot!.endTime)}';
  }
}

class _FinishedMessage extends StatelessWidget {
  const _FinishedMessage();

  @override
  Widget build(BuildContext context) {
    return Text(
      'FINALIZADO',
      maxLines: 1,
      style: const TextStyle(
        fontFamily: AppConfig.countdownFontFamily,
        fontSize: CountdownDisplay._baseFontSize,
        height: 1.0,
        fontWeight: FontWeight.w700,
        color: StageColors.white,
      ),
    );
  }
}
