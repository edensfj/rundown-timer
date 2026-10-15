import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_formatters.dart';
import '../../models/countdown_phase.dart';
import '../../state/countdown_provider.dart';
import '../../state/marquee_provider.dart';
import '../../state/quick_timer_provider.dart';
import '../../state/run_show_provider.dart';
import '../../state/stage_mode_provider.dart';
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusDot(
                  phase: snapshot.phase,
                  showClock: snapshot.showClock,
                  isStopped: snapshot.isStopped,
                  marqueeOnAir: snapshot.marquee != null,
                ),
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
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _StageModeSwitch(),
          ),
          if (snapshot.showClock) ...[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _ClockFormatSwitch(),
            ),
          ],
          const SizedBox(height: 10),
          _PreviewDetails(onOpenFullscreen: onOpenFullscreen),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({
    required this.phase,
    this.showClock = false,
    this.isStopped = false,
    this.marqueeOnAir = false,
  });

  final CountdownPhase phase;

  /// En modo reloj la fase de la cuenta atrás no manda: se muestra un estado
  /// neutro para no confundir al operador.
  final bool showClock;

  /// La actividad está detenida a mano. En el escenario eso no se ve —la sala ve
  /// una pantalla en negro—, así que el aviso es solo de aquí.
  final bool isStopped;

  /// Hay un texto cruzando la pantalla. Manda sobre la fase cuando no hay nada
  /// más en marcha: el escenario no está «en espera», está enseñando el mensaje.
  final bool marqueeOnAir;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final marquesina = marqueeOnAir && phase == CountdownPhase.idle;

    final accent = isStopped
        ? scheme.outline
        : marquesina
        ? scheme.primary
        : showClock
        ? Colors.white70
        : phase.accent;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          isStopped
              ? 'DETENIDA'
              : marquesina
              ? 'MARQUESINA'
              : showClock
              ? 'HORA ACTUAL'
              : _label(phase),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  String _label(CountdownPhase phase) => switch (phase) {
    CountdownPhase.idle => 'EN ESPERA',
    CountdownPhase.preShow => 'PREVIO',
    CountdownPhase.normal => 'EN CURSO',
    CountdownPhase.warning => 'ÚLTIMOS MINUTOS',
    CountdownPhase.overtime => 'EXCEDIDO',
    CountdownPhase.finished => 'FINALIZADO',
  };
}

/// Conmutador de lo que se proyecta: cuenta atrás o hora actual.
///
/// Vive en el panel de vista previa porque es lo que el operador ve salir al
/// escenario. Al cambiar, la instantánea cambia y el controlador la empuja a
/// la ventana sin más.
///
/// Con una actividad en marcha, la hora actual queda **desactivada**: cambiar el
/// modo cambia lo que está viendo la sala.
class _StageModeSwitch extends ConsumerWidget {
  const _StageModeSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(stageModeProvider);
    final snapshot = ref.watch(countdownProvider);

    // Con una actividad en marcha la hora actual se desactiva: cambiar el modo
    // cambia lo que está viendo la sala, y eso en directo no se decide por
    // curiosidad. Para marcar la hora hay que detener antes la actividad.
    final enMarcha =
        snapshot.phase == CountdownPhase.normal ||
        snapshot.phase == CountdownPhase.warning ||
        snapshot.phase == CountdownPhase.overtime;

    // Al 100 % del ancho: los segmentos se reparten el espacio en vez de
    // quedar apelotonados a la izquierda.
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<StageMode>(
        segments: [
          const ButtonSegment(
            value: StageMode.countdown,
            icon: Icon(Icons.timer_outlined, size: 16),
            label: Text('Cuenta atrás'),
          ),
          ButtonSegment(
            value: StageMode.clock,
            enabled: !enMarcha,
            tooltip: enMarcha
                ? 'No se puede cambiar con una actividad en marcha'
                : 'Proyectar solo la hora',
            icon: const Icon(Icons.schedule_rounded, size: 16),
            label: const Text('Hora actual'),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (seleccion) =>
            ref.read(stageModeProvider.notifier).setMode(seleccion.first),
        style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
      ),
    );
  }
}

/// Formato 12 h / 24 h del modo reloj. Solo se enseña en modo reloj.
class _ClockFormatSwitch extends ConsumerWidget {
  const _ClockFormatSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = ref.watch(stageClockFormatProvider);

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<StageClockFormat>(
        segments: const [
          ButtonSegment(value: StageClockFormat.h24, label: Text('24 h')),
          ButtonSegment(value: StageClockFormat.h12, label: Text('12 h')),
        ],
        selected: {format},
        onSelectionChanged: (seleccion) => ref
            .read(stageClockFormatProvider.notifier)
            .setFormat(seleccion.first),
        style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
      ),
    );
  }
}

/// Detalle compacto y controles rápidos, para operar sin abrir el escenario.
class _PreviewDetails extends ConsumerWidget {
  const _PreviewDetails({required this.onOpenFullscreen});

  final VoidCallback onOpenFullscreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final marquee = ref.watch(marqueePlaybackProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lo que está cruzando manda sobre todo lo demás: es lo que ve la
          // sala, y en directo hay que poder cortarlo sin abrir un diálogo.
          if (marquee != null) ...[
            _MarqueeOnAir(text: marquee.text),
            const SizedBox(height: 14),
          ],
          _buildActivityDetails(context, ref, marqueeOnAir: marquee != null),
        ],
      ),
    );
  }

  /// El detalle de la actividad en curso y sus controles.
  Widget _buildActivityDetails(
    BuildContext context,
    WidgetRef ref, {
    required bool marqueeOnAir,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snapshot = ref.watch(countdownProvider);
    final run = ref.read(runShowProvider.notifier);

    // En modo reloj el detalle de la actividad no pinta nada: el escenario
    // enseña la hora. Se conserva el botón de abrir a pantalla completa.
    if (snapshot.showClock) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'El escenario muestra la hora actual.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              _PantallaButton(onOpenFullscreen: onOpenFullscreen),
            ],
          ),
        ],
      );
    }

    if (!snapshot.hasActivities) {
      return Text(
        marqueeOnAir
            ? 'La marquesina está al aire. Al ejecutar una actividad '
                  'aparecerá la cuenta atrás.'
            : snapshot.phase == CountdownPhase.idle
            // En espera no hay actividad que mirar, pero tampoco es un fallo:
            // el escenario está en negro porque todavía no empieza nada. El
            // interruptor de la cuenta previa vive en Configuración.
            ? 'El escenario está en espera: no hay nada en marcha. Al ejecutar '
                  'una actividad o empezar el día aparecerá la cuenta atrás.'
            : 'Agrega actividades para ver la vista previa.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    final current = snapshot.current!.item;
    final quick = ref.watch(quickTimerProvider) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (quick) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Contador rápido activo',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  ref.read(quickTimerProvider.notifier).clear();
                  ref.read(runShowProvider.notifier).syncWithClock();
                },
                icon: const Icon(Icons.event_note_rounded, size: 16),
                label: const Text('Al itinerario'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
        ],
        Text(
          current.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          snapshot.isStopped
              // El escenario está en negro a propósito: aquí se explica, que
              // quien lo ve es el operador.
              ? 'Detenida a mano · la sala ve la pantalla en negro'
              : [
                  if (!quick)
                    'Actividad ${snapshot.index + 1} de ${snapshot.total}',
                  if (snapshot.next != null)
                    'siguiente ${TimeFormatters.time(snapshot.next!.startTime)}',
                ].join('  ·  '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
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
              // Detener no es pausar: da la actividad por terminada aunque su
              // hora de fin no hubiera llegado. Puliéndolo otra vez, vuelve a
              // contar lo que le quedaba.
              onPressed: () => run.toggleStop(),
              tooltip: snapshot.isStopped
                  ? 'Reanudar el conteo'
                  : 'Detener la actividad',
              isSelected: snapshot.isStopped,
              icon: const Icon(Icons.stop_circle_outlined),
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
            _PantallaButton(onOpenFullscreen: onOpenFullscreen),
          ],
        ),
      ],
    );
  }
}

/// Aviso de que hay un texto cruzando, con el botón para cortarlo.
///
/// Va aquí arriba, en el panel, y no solo dentro del diálogo de la marquesina:
/// en directo lo urgente es poder quitar el texto de la pantalla, y abrir un
/// diálogo para pararlo es un paso de más justo cuando hay prisa.
class _MarqueeOnAir extends ConsumerWidget {
  const _MarqueeOnAir({required this.text});

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Icon(Icons.campaign_rounded, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Marquesina al aire: «$text»',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        TextButton.icon(
          onPressed: () => ref.read(marqueePlaybackProvider.notifier).stop(),
          icon: const Icon(Icons.stop_circle_outlined, size: 16),
          label: const Text('Detener'),
          style: TextButton.styleFrom(
            foregroundColor: scheme.error,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}

/// Botón de abrir el escenario a pantalla completa.
class _PantallaButton extends StatelessWidget {
  const _PantallaButton({required this.onOpenFullscreen});

  final VoidCallback onOpenFullscreen;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onOpenFullscreen,
      icon: const Icon(Icons.open_in_full_rounded, size: 18),
      label: const Text('Pantalla'),
    );
  }
}
