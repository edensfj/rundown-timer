import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../../models/activity_item.dart';
import '../../models/event_day.dart';
import '../../state/displays_provider.dart';
import '../../state/rundown_provider.dart';
import '../../state/schedule_provider.dart';
import '../../state/ui_state_provider.dart';
import '../widgets/activity_card.dart';
import '../widgets/activity_form_drawer.dart';
import '../widgets/day_selector.dart';
import '../widgets/live_clock_header.dart';
import '../widgets/screen_picker_dialog.dart';
import '../widgets/stage_preview_panel.dart';
import 'run_show_screen.dart';

/// Vista principal: reloj en vivo, selector de día y lista de actividades.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(activeDayProvider);
    final schedule = ref.watch(activeScheduleProvider);
    final rundownState = ref.watch(rundownProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rundown'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(previewVisibleProvider.notifier).toggle(),
            tooltip: ref.watch(previewVisibleProvider)
                ? 'Ocultar la vista previa'
                : 'Ver lo que se está presentando',
            isSelected: ref.watch(previewVisibleProvider),
            icon: const Icon(Icons.picture_in_picture_alt_rounded),
          ),
          const _ScreenAction(),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                LiveClockHeader(contextLabel: day?.name),
                if (rundownState.hasError)
                  _ErrorBanner(message: '${rundownState.error}')
                else
                  DaySelector(
                    onAddDay: () => _createDay(context, ref),
                    onEditDay: (EventDay value) => _editDay(context, ref, value),
                  ),
                Expanded(
                  child: day == null
                      ? const _EmptyState()
                      : schedule.isEmpty
                          ? _EmptyDay(
                              day: day,
                              onAdd: () => _openForm(context, ref, day),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                              itemCount: schedule.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final slot = schedule[index];
                                return ActivityCard(
                                  slot: slot,
                                  onTap: () => _openForm(
                                    context,
                                    ref,
                                    day,
                                    existing: slot.item,
                                  ),
                                  onDelete: () => _confirmDelete(
                                    context,
                                    ref,
                                    day,
                                    slot.item,
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          // Vista previa en vivo: el operador ve la salida del escenario sin
          // dejar de programar el itinerario.
          if (ref.watch(previewVisibleProvider))
            Container(
              width: 420,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                ),
              ),
              child: StagePreviewPanel(
                onOpenFullscreen: () => _openRunShow(context),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'runShow',
            onPressed: schedule.isEmpty ? null : () => _openRunShow(context),
            icon: const Icon(Icons.slideshow_rounded),
            label: const Text('Modo Escenario'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'addActivity',
            onPressed: day == null ? null : () => _openForm(context, ref, day),
            tooltip: 'Agregar actividad',
            child: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _createDay(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: 'Fecha del evento',
    );
    if (date == null || !context.mounted) return;

    final name = await promptForDayName(context, date: date);
    if (name == null || !context.mounted) return;

    await ref.read(rundownProvider.notifier).addDay(
          name: name,
          date: DateTime(date.year, date.month, date.day),
          id: newId(),
        );

    messenger.showSnackBar(SnackBar(content: Text('Día «$name» creado')));
  }

  Future<void> _editDay(BuildContext context, WidgetRef ref, EventDay day) async {
    final name = await promptForDayName(
      context,
      date: day.date,
      initialValue: day.name,
      title: 'Renombrar día',
    );
    if (name == null || !context.mounted) return;
    await ref.read(rundownProvider.notifier).renameDay(day.id, name);
  }

  /// Abre el formulario en el drawer lateral y aplica el resultado.
  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref,
    EventDay day, {
    ActivityItem? existing,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(rundownProvider.notifier);

    final result = await showActivityFormDrawer(
      context,
      day: day,
      existing: existing,
    );

    switch (result) {
      case ActivitySaved(:final item):
        await notifier.saveActivity(dayId: day.id, item: item);
        messenger.showSnackBar(
          SnackBar(
            content: Text(existing == null
                ? 'Actividad «${item.title}» agregada'
                : 'Actividad actualizada'),
          ),
        );

      case ActivityDeleted(:final id):
        await notifier.deleteActivity(day.id, id);
        messenger.showSnackBar(
          SnackBar(content: Text('«${existing?.title ?? 'Actividad'}» eliminada')),
        );

      case null:
        break;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    EventDay day,
    ActivityItem item,
  ) async {
    final notifier = ref.read(rundownProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    await notifier.deleteActivity(day.id, item.id);

    messenger.showSnackBar(
      SnackBar(
        content: Text('«${item.title}» eliminada'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => notifier.saveActivity(dayId: day.id, item: item),
        ),
      ),
    );
  }

  void _openRunShow(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RunShowScreen()),
    );
  }
}

/// Acción de la AppBar para elegir en qué pantalla se proyectará el escenario.
class _ScreenAction extends ConsumerWidget {
  const _ScreenAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final count = ref.watch(displaysProvider).value?.length ?? 0;
    final active = ref.watch(activeDisplayProvider);

    return Tooltip(
      message: active != null
          ? 'Escenario en esta pantalla: ${active.name ?? 'sin nombre'}'
          : count > 1
              ? 'Elegir pantalla del escenario · $count detectadas'
              : 'Pantallas conectadas',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: () => ScreenPickerDialog.show(context),
            icon: Icon(
              active != null ? Icons.tv_rounded : Icons.tv_off_rounded,
              color: active != null ? scheme.primary : null,
            ),
          ),
          if (count > 1)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'No se pudo cargar el itinerario.\n$message',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_rounded, size: 72, color: scheme.outline),
            const SizedBox(height: 20),
            Text('Aún no hay días', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Crea el primer día del evento para empezar a armar su itinerario.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final messenger = ScaffoldMessenger.of(context);
                  final now = DateTime.now();
                  ref.read(rundownProvider.notifier).addDay(
                        name: 'Día 1',
                        date: DateTime(now.year, now.month, now.day),
                        id: newId(),
                      );
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Día creado')),
                  );
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crear día'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.day, required this.onAdd});

  final EventDay day;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_add_rounded, size: 64, color: scheme.outline),
            const SizedBox(height: 16),
            Text('Sin actividades', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Agrega la primera actividad de «${day.name}».',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar actividad'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
