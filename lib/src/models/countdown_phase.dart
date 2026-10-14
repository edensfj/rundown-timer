import 'package:flutter/material.dart';

import '../core/app_config.dart';

/// Estados visuales del countdown del modo escenario.
enum CountdownPhase {
  /// El evento todavía no empieza: cuenta hacia el inicio de la primera actividad.
  preShow,

  /// Queda más de [warningThreshold].
  normal,

  /// Últimos minutos antes del final programado.
  warning,

  /// Se pasó del tiempo programado: el conteo sigue en negativo y la pantalla
  /// parpadea en rojo.
  overtime,

  /// El usuario cerró el evento explícitamente.
  finished,
}

/// Determina la fase a partir del tiempo restante.
///
/// Un `remaining` negativo o cero es siempre [CountdownPhase.overtime]: es
/// exactamente el caso de «la hora de la siguiente actividad ya pasó».
CountdownPhase countdownPhaseFor(
  Duration remaining, {
  Duration warningThreshold = AppConfig.warningThreshold,
}) {
  if (remaining <= Duration.zero) return CountdownPhase.overtime;
  if (remaining <= warningThreshold) return CountdownPhase.warning;
  return CountdownPhase.normal;
}

/// Paleta del modo escenario.
///
/// Regla única: **texto blanco sobre pantalla negra** en todas las fases. El
/// color se usa solo como acento (badge, barra de progreso) y el rojo se
/// reserva para la alerta de tiempo excedido, que parpadea a pantalla completa.
class StageColors {
  const StageColors._();

  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  /// Rojo de la alerta a pantalla completa.
  static const Color alert = Color(0xFFD50000);

  /// Rojo intenso para texto y bordes en estado de alerta.
  static const Color alertAccent = Color(0xFFFF1744);
}

extension CountdownPhaseStyle on CountdownPhase {
  /// Fondo: siempre negro, para que el countdown sea lo único que ocupe la
  /// pantalla.
  Color get background => StageColors.black;

  /// Texto: siempre blanco de puro contraste.
  Color get foreground => StageColors.white;

  /// Color de acento: badge, barra de progreso e iconos.
  Color get accent => switch (this) {
        CountdownPhase.preShow => const Color(0xFF60A5FA),
        CountdownPhase.normal => const Color(0xFF22C55E),
        CountdownPhase.warning => const Color(0xFFFBBF24),
        CountdownPhase.overtime => StageColors.alertAccent,
        CountdownPhase.finished => const Color(0xFF34D399),
      };

  /// `true` si esta fase activa la alerta parpadeante.
  bool get isAlert => this == CountdownPhase.overtime;
}
