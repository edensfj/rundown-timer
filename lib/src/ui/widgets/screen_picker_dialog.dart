import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';

import '../../state/displays_provider.dart';

/// Diálogo para ver las pantallas conectadas y **elegir en cuál** se mostrará
/// el modo escenario.
///
/// La elección se guarda; el modo escenario abre directamente en esa pantalla.
/// Así el operador decide antes de entrar y no tiene que buscar el botón con
/// el evento ya proyectándose.
class ScreenPickerDialog extends ConsumerWidget {
  const ScreenPickerDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ScreenPickerDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displays = ref.watch(displaysProvider);
    final selectedId = ref.watch(selectedDisplayProvider);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.tv_rounded),
          SizedBox(width: 10),
          Text('Pantalla del escenario'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: displays.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 40),
                const SizedBox(height: 12),
                const Text('No se pudieron detectar las pantallas.'),
                const SizedBox(height: 6),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(displaysProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
          data: (list) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (list.length <= 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Solo hay una pantalla conectada. Enchufe un proyector o '
                    'un segundo monitor para proyectar el escenario.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _DisplayTile(
                    display: list[index],
                    index: index,
                    selected: list[index].id.isNotEmpty &&
                selectedId != null &&
                list[index].id == selectedId,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _DisplayTile extends ConsumerWidget {
  const _DisplayTile({
    required this.display,
    required this.index,
    required this.selected,
  });

  final Display display;
  final int index;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = display.visibleSize ?? display.size;
    final scale = display.scaleFactor;

    return Material(
      color: selected
          ? Color.lerp(scheme.surfaceContainerHighest, scheme.primary, 0.18)
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        onTap: () => ref
            .read(selectedDisplayProvider.notifier)
            .select(selected ? null : display.id),
        leading: Icon(
          selected
              ? Icons.check_circle_rounded
              : Icons.desktop_windows_rounded,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(
          display.name?.trim().isNotEmpty == true
              ? display.name!
              : 'Pantalla ${index + 1}',
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          [
            '${size.width.toInt()} × ${size.height.toInt()} px',
            if (scale != null)
              '${scale.toStringAsFixed(scale % 1 == 0 ? 0 : 1)}×',
            if (display.visiblePosition != null)
              'pos (${display.visiblePosition!.dx.toInt()}, '
                  '${display.visiblePosition!.dy.toInt()})',
          ].join('  ·  '),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        trailing: selected
            ? Text(
                'Seleccionada',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }
}
