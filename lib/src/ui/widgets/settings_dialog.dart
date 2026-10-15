import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/stage_projection_provider.dart';
import 'flash_settings_dialog.dart';
import 'rundown_transfer.dart';

/// **Un solo sitio** para todo lo que se ajusta.
///
/// Antes esto estaba repartido en tres botones de la barra —parpadeos, importar y
/// exportar— y los que se acababan olvidando eran justo los menos usados. Aquí
/// está todo junto, y se añade lo que faltaba: qué hace el escenario cuando no
/// hay nada en marcha.
class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const SettingsDialog(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Configuración',
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _SectionLabel(
                      icon: Icons.slideshow_rounded,
                      title: 'Escenario',
                    ),
                    _PreShowCountdownSwitch(),
                    Divider(height: 28),
                    _SectionLabel(
                      icon: Icons.flash_on_rounded,
                      title: 'Parpadeos',
                    ),
                    FlashSettingsSection(),
                    Divider(height: 28),
                    _SectionLabel(
                      icon: Icons.import_export_rounded,
                      title: 'Programación (archivo JSON)',
                    ),
                    _TransferSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Qué se proyecta **antes** de que empiece el evento.
///
/// Apagado, el escenario se queda en negro mientras no haya nada en marcha; la
/// cuenta atrás previa solo aparece cuando el operador la pide, o cuando ya hay
/// una actividad en pantalla. Es lo que evita que la pantalla de la sala esté
/// tres días diciendo «faltan 79 horas» mientras se programa el guion de mañana.
class _PreShowCountdownSwitch extends ConsumerWidget {
  const _PreShowCountdownSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final enabled = ref.watch(showPreShowCountdownProvider);
    final notifier = ref.read(showPreShowCountdownProvider.notifier);

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: enabled,
      onChanged: notifier.set,
      title: const Text('Contar atrás antes de empezar'),
      subtitle: Text(
        enabled
            ? 'Con nada en marcha, el escenario muestra cuánto falta para la '
                  'primera actividad.'
            : 'Con nada en marcha, el escenario se queda en negro. La cuenta '
                  'atrás aparece al ejecutar una actividad o empezar el día.',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

/// Importar y exportar la programación, como botones y no como menú escondido.
class _TransferSection extends ConsumerWidget {
  const _TransferSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Guarda la programación en un archivo o cárgala desde otro equipo. '
          'Importar no borra nada sin preguntar.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => exportRundown(context, ref),
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Exportar a JSON…'),
            ),
            OutlinedButton.icon(
              onPressed: () => importRundown(context, ref),
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Importar desde JSON…'),
            ),
          ],
        ),
      ],
    );
  }
}