import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_formatters.dart';
import '../../models/event_day.dart';
import '../../state/rundown_provider.dart';
import '../../state/schedule_provider.dart';
import '../../state/selected_day_provider.dart';

/// Selector horizontal de días del evento, con opción de crear uno nuevo.
///
/// El **toque** selecciona el día. Su menú (renombrar o eliminar) se abre con
/// **clic derecho** en el sitio exacto donde se ha pulsado, o con **pulsación
/// larga** si se usa el dedo: no se meten más botones en una ficha tan pequeña.
class DaySelector extends ConsumerWidget {
  const DaySelector({super.key, required this.onAddDay});

  final VoidCallback onAddDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(sortedDaysProvider);
    final activeDay = ref.watch(activeDayIdProvider);

    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: days.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == days.length) {
            return _AddDayChip(onTap: onAddDay);
          }
          final day = days[index];
          return _DayChip(
            day: day,
            selected: day.id == activeDay,
            onTap: () => ref.read(selectedDayProvider.notifier).select(day.id),
            // Con el dedo no hay clic derecho: la pulsación larga abre lo mismo.
            onLongPress: () => _dayMenu(context, ref, day),
            onSecondaryTap: (position) =>
                _dayMenu(context, ref, day, position: position),
          );
        },
      ),
    );
  }
}

/// Acciones disponibles sobre un día.
enum _DayAction { forceRun, rename, delete }

/// Menú de un día: renombrar o eliminar.
///
/// Con [position] se abre como menú contextual en el punto exacto del clic
/// derecho, que es lo que se espera con un ratón. Sin ella se abre como hoja
/// inferior, que es lo cómodo con el dedo.
Future<void> _dayMenu(
  BuildContext context,
  WidgetRef ref,
  EventDay day, {
  Offset? position,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(rundownProvider.notifier);

  final action = position == null
      ? await showModalBottomSheet<_DayAction>(
          context: context,
          builder: (sheet) => SafeArea(child: _DayActionList(day: day)),
        )
      : await showMenu<_DayAction>(
          context: context,
          // Sale pegado al cursor, sin salirse de la ventana: si el clic fue en
          // el borde de abajo, el menú crece hacia arriba.
          position: RelativeRect.fromRect(
            Rect.fromPoints(position, position),
            Offset.zero & MediaQuery.sizeOf(context),
          ),
          items: [
            const PopupMenuItem(
              value: _DayAction.forceRun,
              child: _DayForceRunItem(),
            ),
            const PopupMenuItem(
              value: _DayAction.rename,
              child: _DayRenameItem(),
            ),
            const PopupMenuItem(
              value: _DayAction.delete,
              child: _DayDeleteItem(),
            ),
          ],
        );

  if (action == null || !context.mounted) return;

  switch (action) {
    case _DayAction.forceRun:
      if (day.forceRun) {
        await notifier.stopDayRun(day.id);
        messenger.showSnackBar(
          SnackBar(content: Text('«${day.name}» vuelve a su fecha.')),
        );
      } else {
        await notifier.startDayRun(day.id);
        messenger.showSnackBar(
          SnackBar(content: Text('«${day.name}» empieza ahora mismo.')),
        );
      }

    case _DayAction.rename:
      final name = await promptForDayName(
        context,
        date: day.date,
        initialValue: day.name,
        title: 'Renombrar día',
      );
      if (name == null) return;
      await notifier.renameDay(day.id, name);

    case _DayAction.delete:
      // Borrar el día se lleva por delante sus actividades, así que se avisa
      // de cuántas son antes de hacerlo.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Eliminar el día'),
          content: Text(
            '¿Eliminar «${day.name}» y sus ${day.activities.length} '
            '${day.activities.length == 1 ? 'actividad' : 'actividades'}? '
            'No se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      await notifier.deleteDay(day.id);
      messenger.showSnackBar(
        SnackBar(content: Text('«${day.name}» eliminado')),
      );
  }
}

/// Filas del menú de un día, compartidas por la hoja inferior y el menú
/// contextual: se escriben una vez para que las dos formas offerscan lo mismo.
class _DayActionList extends StatelessWidget {
  const _DayActionList({required this.day});

  final EventDay day;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(
            day.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${day.activities.length} '
            '${day.activities.length == 1 ? 'actividad' : 'actividades'}',
          ),
        ),
        const Divider(height: 1),
        _DayForceRunItem(day: day),
        const _DayRenameItem(),
        const _DayDeleteItem(),
      ],
    );
  }
}

/// Ejecutar (o dejar de ejecutar) el día de hoy, esté en el calendario cuando
/// esté.
///
/// La opción cambia con la marca del día: marcada, el itinerario corre con sus
/// horas de hoy aunque la fecha siga en el futuro.
class _DayForceRunItem extends StatelessWidget {
  const _DayForceRunItem({this.day});

  /// En el menú contextual el día ya viene capturado, así que no hace falta
  /// pasarlo otra vez.
  final EventDay? day;

  @override
  Widget build(BuildContext context) {
    final active = day?.forceRun ?? false;

    return ListTile(
      leading: Icon(
        active ? Icons.stop_circle_outlined : Icons.play_circle_outline,
        color: active ? Theme.of(context).colorScheme.error : null,
      ),
      title: Text(active ? 'Dejar de ejecutarlo ahora' : 'Empezar ahora'),
      subtitle: Text(
        active
            ? 'Vuelve a su fecha de calendario.'
            : 'La primera actividad empieza ya y el resto se calcula.',
      ),
      onTap: () => Navigator.of(context).pop(_DayAction.forceRun),
    );
  }
}

class _DayRenameItem extends StatelessWidget {
  const _DayRenameItem();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.edit_outlined),
      title: const Text('Renombrar'),
      onTap: () => Navigator.of(context).pop(_DayAction.rename),
    );
  }
}

class _DayDeleteItem extends StatelessWidget {
  const _DayDeleteItem();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.delete_outline_rounded),
      title: const Text('Eliminar el día'),
      onTap: () => Navigator.of(context).pop(_DayAction.delete),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onSecondaryTap,
  });

  final EventDay day;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// Clic derecho: abre el menú contextual donde se ha pulsado.
  final void Function(Offset position) onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final background = selected ? scheme.primary : scheme.surface;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;
    final countColor = selected
        ? scheme.onPrimary.withValues(alpha: 0.8)
        : scheme.onSurfaceVariant;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      // `InkWell` no dice DÓNDE se ha hecho el clic derecho, y para el menú
      // contextual hace falta: el `GestureDetector` de fuera captura el punto y
      // se lo pasa, sin interferir con el toque ni la pulsación larga.
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapDown: (details) => onSecondaryTap(details.globalPosition),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    // Marca de «ejecutando hoy»: el día corre aunque su fecha no
                    // sea la de hoy, y tiene que verse de un vistazo.
                    if (day.forceRun) ...[
                      Icon(
                        Icons.play_circle_fill_rounded,
                        size: 13,
                        color: foreground,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        '${day.activities.length} '
                        '${day.activities.length == 1 ? 'actividad' : 'actividades'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: countColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddDayChip extends StatelessWidget {
  const _AddDayChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'Nuevo día',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diálogo reutilizable para nombrar un día. Devuelve el nombre o `null`.
Future<String?> promptForDayName(
  BuildContext context, {
  required DateTime date,
  String? initialValue,
  String title = 'Nombre del día',
}) {
  final controller = TextEditingController(
    text: initialValue ?? TimeFormatters.dayLabel(date),
  );
  final formKey = GlobalKey<FormState>();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Sábado, Domingo, Día 1…',
          ),
          onFieldSubmitted: (_) {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(dialogContext).pop(controller.text.trim());
            }
          },
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Escribe un nombre'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(dialogContext).pop(controller.text.trim());
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}
