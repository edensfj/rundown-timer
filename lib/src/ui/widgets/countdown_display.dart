import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/time_formatters.dart';
import '../../models/countdown_phase.dart';
import '../../models/countdown_snapshot.dart';

/// El reloj del modo escenario. Es lo único que se proyecta.
///
/// Dos decisiones hacen que sea realmente grande:
///
/// 1. **Fuente condensada** ([AppConfig.countdownFontFamily]): los dígitos son
///    mucho más estrechos, así que al ajustarse al ancho de la pantalla crecen
///    proporcionalmente en alto. Con una fuente normal, `MM:SS` en una pantalla
///    16:9 queda limitado por el ancho y desperdicia media pantalla.
/// 2. **Sin nada más alrededor**: ni cabecera, ni barra, ni subtítulo. Todo eso
///    le robaba altura, y en una proyección lo único que importa es que se lea
///    el tiempo desde la última fila.
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

  @override
  Widget build(BuildContext context) {
    final phase = snapshot.phase;

    return Center(
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
    );
  }
}

/// Con el evento cerrado, un reloj congelado no diría nada: se anuncia.
class _FinishedMessage extends StatelessWidget {
  const _FinishedMessage();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'FINALIZADO',
      maxLines: 1,
      style: TextStyle(
        fontFamily: AppConfig.countdownFontFamily,
        fontSize: CountdownDisplay._baseFontSize,
        height: 1.0,
        fontWeight: FontWeight.w700,
        color: StageColors.white,
      ),
    );
  }
}
