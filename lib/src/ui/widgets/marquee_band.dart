import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../models/marquee.dart';

/// La banda de la marquesina: el mensaje cruza la pantalla **una vez**.
///
/// El pase lo marca la duración que viene en [MarqueeOverlay.duration], que
/// calculó el panel. Cuando termina, el panel manda una instantánea sin mensaje
/// y esta banda desaparece, devolviéndole el sitio al reloj.
///
/// El ancho del texto se mide aquí con el motor, porque es lo único que sabe de
/// verdad cuánto ocupa la tipografía; el punto de partida y de llegada son los
/// bordes de la pantalla, de modo que el texto siempre entra y sale entero.
class MarqueeBand extends StatefulWidget {
  const MarqueeBand({super.key, required this.overlay, required this.fontSize});

  final MarqueeOverlay overlay;

  /// Alto de letra en píxeles, ya resuelto por quien compone la pantalla.
  final double fontSize;

  @override
  State<MarqueeBand> createState() => _MarqueeBandState();
}

class _MarqueeBandState extends State<MarqueeBand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.overlay.duration,
    );
    _launch(fromStart: true);
  }

  /// Un pase suelto se ejecuta una vez; uno marcado como bucle no para hasta
  /// que el operador lo corta.
  ///
  /// [fromStart] distingue arrancar de cero de continuar: al cambiar la
  /// velocidad en vivo hay que **reanudar** el texto donde está —no reiniciarlo
  /// en el borde, que a un deslizador por segundo sería un parpadeo constante—
  /// pero con la duración nueva, que es lo que manda la velocidad.
  void _launch({required bool fromStart}) {
    _controller.duration = widget.overlay.duration;

    if (widget.overlay.loop) {
      if (fromStart) {
        _controller
          ..reset()
          ..repeat();
      } else {
        // `repeat()` sin argumentos usa la duración recién asignada; al no
        // reiniciar el valor, el bucle sigue por donde iba.
        _controller.repeat();
      }
    } else if (fromStart) {
      _controller.forward(from: 0);
    } else {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(MarqueeBand oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Un pase nuevo —otro mensaje, o el mismo reenviado— vuelve a empezar. Sin
    // esto, reenviar el texto dejaría la animación al final, ya fuera.
    if (oldWidget.overlay.runId != widget.overlay.runId) {
      _launch(fromStart: true);
      return;
    }

    // Mismo texto pero más rápido, más grande o con otro grosor: cambia la
    // duración del cruce y hay que relanzar la animación para que el cambio se
    // vea de inmediato. El estilo lo repinta solo, el recorrido no.
    if (oldWidget.overlay.duration != widget.overlay.duration) {
      _launch(fromStart: false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.overlay.settings;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final painter = TextPainter(
          text: TextSpan(text: widget.overlay.text, style: _style(settings)),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        final textWidth = painter.width;
        final textHeight = painter.height;

        // De fuera a fuera: el texto entra por un borde y sale por el otro, así
        // que el recorrido es el ancho de la pantalla más el suyo.
        final (from, to) = switch (settings.direction) {
          MarqueeDirection.leftToRight => (-textWidth, width),
          MarqueeDirection.rightToLeft => (width, -textWidth),
        };

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final x = from + (to - from) * _controller.value;
              return Stack(
                children: [
                  Positioned(
                    left: x,
                    top: ((height - textHeight) / 2).clamp(0.0, height),
                    child: child!,
                  ),
                ],
              );
            },
            child: Text(
              widget.overlay.text,
              maxLines: 1,
              softWrap: false,
              style: _style(settings),
            ),
          ),
        );
      },
    );
  }

  /// Misma familia que el reloj, con el grosor elegido: la banda y los dígitos
  /// van a juego.
  TextStyle _style(MarqueeSettings settings) => TextStyle(
    fontFamily: AppConfig.countdownFontFamily,
    fontSize: widget.fontSize,
    height: 1.1,
    fontWeight: settings.weight,
    color: Colors.white,
  );
}
