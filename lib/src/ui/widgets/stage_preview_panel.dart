import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_formatters.dart';
import '../../models/countdown_phase.dart';
import '../../state/countdown_provider.dart';
import '../../state/run_show_provider.dart';
import 'stage_view.dart';

/// Vista previa en vivo de lo que se está proyectando.
///
/// El operador programa el itinerario sin perder de vista la salida del
/// escenario: la miniatura es el mismo [StageView] que se muestra a pantalla
/// completa, reducido, así que refleja el countdown, los colores y el
/// parpadeo rojo exactamente igual.
class StagePreviewPanel extends ConsumerWidget {
  const StagePreviewPanel({super.key, required this.onOpenFullscreen});

  final VoidCallback onOpenFullscreen;

  /// Resolución lógica a la que se compone la miniatura antes de escalarla.
  /// Mantiene las proporciones idénticas a una pantalla real.
  static const double _designWidth = 1600;
  static const double _designHeight = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snapshot = ref.watch(countdownProvider);

    return Container(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Icon(Icons.slideshow_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lo que se está presentando',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _StatusDot(phase: snapshot.phase),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = constraints.maxWidth / _designWidth;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: _designHeight * scale,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _designWidth,
                        height: _designHeight,
                        // El mismo widget que se proyecta a pantalla completa.
                        child: const StageView(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          _PreviewDetails(onOpenFullscreen: onOpenFullscreen),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.phase});

  final CountdownPhase phase;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: phase.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _label(phase),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: phase.accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
        ),
      ],
    );
  }

  String _label(CountdownPhase phase) => switch (phase) {
        CountdownPhase.preShow => 'PREVIO',
        CountdownPhase.normal => 'EN CURSO',
        CountdownPhase.warning => 'ÚLTIMOS MINUTOS',
        CountdownPhase.overtime => 'EXCEDIDO',
        CountdownPhase.finished => 'FINALIZADO',
      };
}

/// Detalle compacto y controles rápidos, para operar sin abrir el escenario.
class _PreviewDetails extends ConsumerWidget {
  const _PreviewDetails({required this.onOpenFullscreen});

  final VoidCallback onOpenFullscreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snapshot = ref.watch(countdownProvider);
    final run = ref.read(runShowProvider.notifier);

    if (!snapshot.hasActivities) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Text(
          'Agrega actividades para ver la vista previa.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final current = snapshot.current!.item;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            current.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            [
              'Actividad ${snapshot.index + 1} de ${snapshot.total}',
              if (snapshot.next != null)
                'siguiente ${TimeFormatters.time(snapshot.next!.startTime)}',
            ].join('  ·  '),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.outlined(
                onPressed: () => run.togglePause(),
                tooltip: snapshot.isPaused ? 'Reanudar' : 'Pausar',
                isSelected: snapshot.isPaused,
                icon: Icon(
                  snapshot.isPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                ),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                onPressed: () => run.goToNext(),
                tooltip: 'Actividad siguiente',
                icon: const Icon(Icons.skip_next_rounded),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                onPressed: () => run.restart(),
                tooltip: 'Reiniciar el conteo',
                icon: const Icon(Icons.replay_rounded),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: onOpenFullscreen,
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                label: const Text('Pantalla'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
