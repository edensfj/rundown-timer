import 'package:flutter/material.dart';

import '../../models/countdown_snapshot.dart';

/// Barra de controles del modo escenario.
///
/// Se oculta sola tras unos segundos de inactividad y reaparece al mover el
/// ratón, para no contaminar la proyección.
class RunShowControls extends StatelessWidget {
  const RunShowControls({
    super.key,
    required this.snapshot,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePause,
    required this.onToggleStopped,
    required this.onRestart,
    required this.onToggleAutomatic,
    required this.onToggleFinished,
    required this.onSubtractTime,
    required this.onAddTime,
  });

  final CountdownSnapshot snapshot;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePause;

  /// Termina (o reanuda) la actividad que está en pantalla.
  final VoidCallback onToggleStopped;

  final VoidCallback onRestart;
  final VoidCallback onToggleAutomatic;
  final VoidCallback onToggleFinished;

  /// Resta un minuto al conteo en curso.
  final VoidCallback onSubtractTime;

  /// Suma un minuto al conteo en curso.
  final VoidCallback onAddTime;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.surface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: foreground.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlButton(
            icon: Icons.skip_previous_rounded,
            tooltip: 'Actividad anterior',
            onPressed: onPrevious,
          ),
          const SizedBox(width: 4),
          _ControlButton(
            icon: snapshot.isPaused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            tooltip: snapshot.isPaused ? 'Reanudar' : 'Pausar',
            onPressed: onTogglePause,
            highlighted: snapshot.isPaused,
          ),
          const SizedBox(width: 4),
          _ControlButton(
            // Detener no es pausar: la actividad se da por terminada aunque su
            // hora de fin no hubiera llegado. Es lo que se pulsa cuando alguien
            // se adelanta o se corta el momento.
            icon: Icons.stop_circle_outlined,
            tooltip: snapshot.isStopped ? 'Reanudar el conteo' : 'Detener',
            onPressed: onToggleStopped,
            highlighted: snapshot.isStopped,
          ),
          const SizedBox(width: 4),
          _ControlButton(
            icon: Icons.replay_rounded,
            tooltip: 'Reiniciar el conteo',
            onPressed: onRestart,
          ),
          const SizedBox(width: 4),
          _ControlButton(
            icon: Icons.skip_next_rounded,
            tooltip: 'Actividad siguiente',
            onPressed: onNext,
          ),
          Container(
            width: 1,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: foreground.withValues(alpha: 0.2),
          ),
          // Ajuste fino del tiempo en vivo. Funciona igual con el itinerario
          // que con un contador suelto: si algo se alarga, se suma aquí sin
          // tocar la hora de fin programada.
          _ControlButton(
            icon: Icons.remove_rounded,
            tooltip: 'Quitar 1 minuto',
            onPressed: onSubtractTime,
          ),
          _ControlButton(
            icon: Icons.add_rounded,
            tooltip: 'Añadir 1 minuto',
            onPressed: onAddTime,
          ),
          Container(
            width: 1,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: foreground.withValues(alpha: 0.2),
          ),
          _ControlButton(
            icon: snapshot.isAutomatic
                ? Icons.auto_mode_rounded
                : Icons.lock_clock_outlined,
            // El programa no salta solo de actividad en actividad: este botón no
            // reactiva nada automático, solo recoloca la pantalla en la
            // actividad que le tocaría a esta hora.
            tooltip: snapshot.isAutomatic
                ? 'El evento aún no ha empezado'
                : 'Ir a la actividad de esta hora',
            onPressed: onToggleAutomatic,
            highlighted: !snapshot.isAutomatic,
          ),
          _ControlButton(
            icon: snapshot.isFinished
                ? Icons.play_circle_outline_rounded
                : Icons.stop_circle_outlined,
            tooltip: snapshot.isFinished
                ? 'Reabrir el evento'
                : 'Finalizar evento',
            onPressed: onToggleFinished,
            highlighted: snapshot.isFinished,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.highlighted = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.surface;

    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon),
        color: highlighted ? const Color(0xFF38BDF8) : foreground,
        style: IconButton.styleFrom(
          backgroundColor: highlighted
              ? const Color(0xFF38BDF8).withValues(alpha: 0.18)
              : Colors.transparent,
        ),
      ),
    );
  }
}
