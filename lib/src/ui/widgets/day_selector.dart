import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_formatters.dart';
import '../../models/event_day.dart';
import '../../state/rundown_provider.dart';
import '../../state/schedule_provider.dart';
import '../../state/selected_day_provider.dart';

/// Selector horizontal de días del evento, con opción de crear uno nuevo.
class DaySelector extends ConsumerWidget {
  const DaySelector({
    super.key,
    required this.onAddDay,
    required this.onEditDay,
  });

  final VoidCallback onAddDay;
  final ValueChanged<EventDay> onEditDay;

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
            onLongPress: () => onEditDay(day),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final EventDay day;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final background = selected ? scheme.primary : scheme.surface;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;
    final countColor =
        selected ? scheme.onPrimary.withValues(alpha: 0.8) : scheme.onSurfaceVariant;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
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
              Text(
                '${day.activities.length} '
                '${day.activities.length == 1 ? 'actividad' : 'actividades'}',
                style: theme.textTheme.labelSmall?.copyWith(color: countColor),
              ),
            ],
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
    text: initialValue ?? _defaultDayName(date),
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

String _defaultDayName(DateTime date) {
  final dayName = TimeFormatters.dayName(date);
  return '$dayName ${date.day}';
}
