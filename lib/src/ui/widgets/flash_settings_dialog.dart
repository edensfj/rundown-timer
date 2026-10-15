import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/countdown_phase.dart';
import '../../state/stage_flash_settings_provider.dart';

/// Ajustes de los efectos parpadeantes del escenario.
///
/// El escenario da tres avisos a pantalla completa: **verde** al cambiar de
/// actividad, **naranja** en los últimos instantes y **rojo** cuando se pasa del
/// tiempo. Desde aquí se encienden y se apagan, y se dice con cuánta antelación
/// salta cada uno.
///
/// El rojo no tiene interruptor: mientras los parpadeos estén encendidos,
/// **siempre** avisa al acabarse el tiempo. Es el aviso que no puede faltar.
class FlashSettingsDialog extends ConsumerWidget {
  const FlashSettingsDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const FlashSettingsDialog(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 660),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  Icon(Icons.flash_on_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Parpadeos del escenario',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: const FlashSettingsSection(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El contenido de los ajustes de parpadeo, sin diálogo ni cabecera.
///
/// Vive suelto para poder meterlo dentro de la pantalla de configuración, que
/// es donde conviene mirar: un solo sitio para todo lo que se ajusta. El
/// diálogo de aquí sigue existiendo por si se abre por separado.
class FlashSettingsSection extends ConsumerWidget {
  const FlashSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(stageFlashSettingsProvider);
    final notifier = ref.read(stageFlashSettingsProvider.notifier);
    final on = settings.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.enabled,
          onChanged: (v) => notifier.set(settings.copyWith(enabled: v)),
          title: const Text('Parpadeos activados'),
          subtitle: Text(
            on
                ? 'El escenario avisa parpadeando cuando hace falta.'
                : 'El escenario nunca parpadea: solo el reloj.',
          ),
        ),
        const Divider(height: 24),
        // Todo lo de abajo solo tiene sentido con el aviso maestro
        // encendido; apagado se atenúa y no se puede tocar.
        Opacity(
          opacity: on ? 1 : 0.45,
          child: IgnorePointer(
            ignoring: !on,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  color: StageColors.change,
                  icon: Icons.swap_horiz_rounded,
                  title: 'Verde · cambio de actividad',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: settings.changeEnabled,
                  onChanged: (v) =>
                      notifier.set(settings.copyWith(changeEnabled: v)),
                  title: const Text('Destello al cambiar'),
                  subtitle: const Text(
                    'Avisa de que la siguiente actividad ya está al aire.',
                  ),
                ),
                _SliderRow(
                  label: 'Duración',
                  value: settings.changeDuration.inSeconds.toDouble().clamp(
                    1,
                    30,
                  ),
                  min: 1,
                  max: 30,
                  divisions: 29,
                  display: '${settings.changeDuration.inSeconds} s',
                  onChanged: settings.changeEnabled
                      ? (v) => notifier.set(
                          settings.copyWith(
                            changeDuration: Duration(seconds: v.round()),
                          ),
                          persist: false,
                        )
                      : null,
                  onChangeEnd: notifier.commit,
                ),
                const SizedBox(height: 12),
                _SectionHeader(
                  color: StageColors.ending,
                  icon: Icons.hourglass_bottom_rounded,
                  title: 'Naranja · fin del tiempo',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: settings.endingEnabled,
                  onChanged: (v) =>
                      notifier.set(settings.copyWith(endingEnabled: v)),
                  title: const Text('Aviso antes de acabar'),
                  subtitle: const Text('Anticipa el final de la actividad.'),
                ),
                _SliderRow(
                  label: 'Se activa',
                  value: settings.endingWindow.inSeconds.toDouble().clamp(
                    10,
                    600,
                  ),
                  min: 10,
                  max: 600,
                  divisions: 118,
                  display: _formatWindow(settings.endingWindow),
                  onChanged: settings.endingEnabled
                      ? (v) => notifier.set(
                          settings.copyWith(
                            endingWindow: Duration(seconds: v.round()),
                          ),
                          persist: false,
                        )
                      : null,
                  onChangeEnd: notifier.commit,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Por defecto, los últimos 2 minutos antes de acabar.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _ColorDot(color: StageColors.alert),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rojo · tiempo excedido',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Cuando el tiempo se acaba, el escenario '
                    'parpadea en rojo siempre. No se puede '
                    'desactivar mientras los parpadeos estén '
                    'encendidos.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: notifier.reset,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Restablecer'),
          ),
        ),
      ],
    );
  }
}

/// El tiempo de antelación del aviso naranja: en segundos si es corto, en
/// minutos (y segundos) cuando pasa del minuto, que es como se lee de un vistazo.
String _formatWindow(Duration duration) {
  final seconds = duration.inSeconds;
  if (seconds < 60) return '$seconds s';

  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  return rest == 0 ? '$minutes min' : '$minutes min $rest s';
}

/// Cabecera de una sección: un punto del color del aviso, el icono y el título.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.color,
    required this.icon,
    required this.title,
  });

  final Color color;
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          _ColorDot(color: color),
          const SizedBox(width: 10),
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12),
      ),
    );
  }
}

/// Una fila de deslizador con etiqueta y valor. Con [onChanged] nulo se muestra
/// apagada y no responde, para el caso del parpadeo desactivado.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    required this.onChangeEnd,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double>? onChanged;
  final VoidCallback onChangeEnd;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            onChanged: onChanged,
            onChangeEnd: (_) => onChangeEnd(),
          ),
        ),
        SizedBox(
          width: 66,
          child: Text(
            display,
            textAlign: TextAlign.end,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
