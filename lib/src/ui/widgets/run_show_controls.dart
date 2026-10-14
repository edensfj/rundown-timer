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
    required this.onRestart,
    required this.onToggleAutomatic,
    required this.onToggleFinished,
  });

  final CountdownSnapshot snapshot;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePause;
  final VoidCallback onRestart;
  final VoidCallback onToggleAutomatic;
  final VoidCallback onToggleFinished;

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
          _ControlButton(
            icon: snapshot.isAutomatic
                ? Icons.auto_mode_rounded
                : Icons.lock_clock_outlined,
            tooltip: snapshot.isAutomatic
                ? 'Siguiendo el reloj'
                : 'Volver al modo automático',
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
