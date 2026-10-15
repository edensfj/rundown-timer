import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../../core/time_formatters.dart';
import '../../models/activity_item.dart';
import '../../models/countdown_snapshot.dart';
import '../../models/event_day.dart';
import '../../state/displays_provider.dart';
import '../../state/rundown_provider.dart';
import '../../state/schedule_provider.dart';
import '../../state/ui_state_provider.dart';
import '../widgets/activity_card.dart';
import '../widgets/activity_form_drawer.dart';
import '../widgets/activity_preview_dialog.dart';
import '../widgets/day_selector.dart';
import '../widgets/live_clock_header.dart';
import '../widgets/marquee_dialog.dart';
import '../widgets/quick_timer_dialog.dart';
import '../widgets/screen_picker_dialog.dart';
import '../widgets/stage_preview_panel.dart';
import '../widgets/templates_dialog.dart';
import '../../window/stage_window_controller.dart';

/// Vista principal: reloj en vivo, selector de día y lista de actividades.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(activeDayProvider);
    // La lista es siempre la del día: un contador rápido no es parte del
    // programa, así que no cambia lo que se ve aquí.
    final schedule = ref.watch(dayScheduleProvider);
    // Lo que se proyecta sí puede ser el contador rápido; el botón de abrir el
    // escenario depende de eso.
    final onAir = ref.watch(activeScheduleProvider);
    final rundownState = ref.watch(rundownProvider);

    // El escenario avisa cuando se mueve por su cuenta (al desenchufarse la
    // pantalla del reloj): si no se dice nada, la ventana que se encoge de golpe
    // parece un fallo.
    ref.listen<String?>(stageNoticeProvider, (_, message) {
      if (message == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rundown'),
        actions: [
          IconButton(
            onPressed: () => TemplatesDialog.show(context, day: day),
            tooltip: 'Plantillas reutilizables',
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            onPressed: () => MarqueeDialog.show(context),
            tooltip: 'Marquesina (mensajes en pantalla)',
            icon: const Icon(Icons.campaign_rounded),
          ),
          IconButton(
            onPressed: () => _addQuickTimer(context, ref),
            tooltip: 'Contador rápido (fuera del itinerario)',
            icon: const Icon(Icons.timer_outlined),
          ),
          IconButton(
            onPressed: () => ref.read(previewVisibleProvider.notifier).toggle(),
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
                  DaySelector(onAddDay: () => _createDay(context, ref)),
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
                              onDelete: () =>
                                  _confirmDelete(context, ref, day, slot.item),
                              onPreview: () => showActivityPreview(
                                context,
                                CountdownSnapshot.preview(
                                  slots: schedule,
                                  index: index,
                                ),
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
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: StagePreviewPanel(
                onOpenFullscreen: () => _toggleStage(context, ref),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Builder(
            builder: (context) {
              final stage = ref.watch(stageWindowProvider);
              final abierto = stage.isOpen;

              return FloatingActionButton.extended(
                heroTag: 'runShow',
                onPressed: onAir.isEmpty
                    ? null
                    : () => _toggleStage(context, ref),
                icon: Icon(
                  abierto
                      ? Icons.stop_circle_outlined
                      : Icons.slideshow_rounded,
                ),
                label: Text(abierto ? 'Cerrar escenario' : 'Abrir escenario'),
                // Abierto, el botón avisa de dónde está saliendo el reloj.
                backgroundColor: abierto
                    ? Theme.of(context).colorScheme.errorContainer
                    : null,
                foregroundColor: abierto
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : null,
              );
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'addActivity',
            // Sin días no hay nada que desactivar: el botón crea el día de
            // hoy y abre el formulario directamente.
            onPressed: () => day == null
                ? _addFirstActivity(context, ref)
                : _openForm(context, ref, day),
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

    await ref
        .read(rundownProvider.notifier)
        .addDay(
          name: name,
          date: DateTime(date.year, date.month, date.day),
          id: newId(),
        );

    messenger.showSnackBar(SnackBar(content: Text('Día «$name» creado')));
  }

  /// Sin días, agregar actividad crea el día de hoy y abre el formulario
  /// encima: programar no exige crear el día a mano antes.
  Future<void> _addFirstActivity(BuildContext context, WidgetRef ref) async {
    final day = await ref.read(rundownProvider.notifier).ensureToday();
    if (!context.mounted) return;

    await _openForm(context, ref, day);
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
            content: Text(
              existing == null
                  ? 'Actividad «${item.title}» agregada'
                  : 'Actividad actualizada',
            ),
          ),
        );

      case ActivityDeleted(:final id):
        await notifier.deleteActivity(day.id, id);
        messenger.showSnackBar(
          SnackBar(
            content: Text('«${existing?.title ?? 'Actividad'}» eliminada'),
          ),
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

  /// Abre o cierra la ventana del escenario.
  ///
  /// Fíjate en que **no navega**: el reloj vive en su propia ventana y el panel
  /// se queda tal cual, para poder seguir programando mientras se proyecta.
  Future<void> _toggleStage(BuildContext context, WidgetRef ref) async {
    if (ref.read(stageWindowProvider).isOpen) {
      await ref.read(stageWindowProvider.notifier).close();
      return;
    }
    await _openStage(context, ref);
  }

  Future<void> _openStage(BuildContext context, WidgetRef ref) =>
      openStageWindow(context, ref);

  /// Configura un contador suelto y abre el escenario con él.
  Future<void> _addQuickTimer(BuildContext context, WidgetRef ref) async {
    final started = await QuickTimerDialog.show(context);
    if (!started || !context.mounted) return;
    await _openStage(context, ref);
  }
}

/// Abre la ventana del escenario y avisa por pantalla si no se pudo.
///
/// Vive fuera de [DashboardScreen] porque también la usa el estado vacío.
Future<void> openStageWindow(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);

  await ref.read(stageWindowProvider.notifier).open();

  final status = ref.read(stageWindowProvider);
  if (!status.hasError) return;

  messenger.showSnackBar(
    SnackBar(content: Text('No se pudo abrir el escenario: ${status.error}')),
  );
}

/// Acción de la AppBar para elegir en qué pantalla se proyectará el escenario.
class _ScreenAction extends ConsumerWidget {
  const _ScreenAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final count = ref.watch(displaysProvider).value?.length ?? 0;
    final selectedKey = ref.watch(selectedDisplayProvider);
    final active = ref.watch(activeDisplayProvider);

    return Tooltip(
      message: active != null
          ? 'Escenario en esta pantalla: ${active.name?.trim().isNotEmpty == true ? active.name!.trim() : 'sin nombre'}'
          : selectedKey != null && selectedKey.isNotEmpty
          ? 'Escenario elegido, pero esa pantalla no está conectada ya'
          : count > 1
          ? 'Escenario en la otra pantalla · $count detectadas'
          : 'Pantallas conectadas',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: () => ScreenPickerDialog.show(context),
            icon: Icon(
              active != null || (selectedKey?.isNotEmpty ?? false)
                  ? Icons.tv_rounded
                  : Icons.tv_off_rounded,
              color: active != null || (selectedKey?.isNotEmpty ?? false)
                  ? scheme.primary
                  : null,
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_rounded, size: 72, color: scheme.outline),
            const SizedBox(height: 20),
            Text('Sin itinerario todavía', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Crea el primer día con + o con el botón de abajo, o lanza un '
              'contador suelto si solo necesitas medir un tiempo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 320,
              child: FilledButton.icon(
                onPressed: () => _crearDia(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crear día'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 320,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final started = await QuickTimerDialog.show(context);
                  if (!started || !context.mounted) return;
                  await openStageWindow(context, ref);
                },
                icon: const Icon(Icons.timer_outlined),
                label: const Text('Contador rápido'),
              ),
            ),
            const SizedBox(height: 28),
            // Discreto y opcional: las plantillas guardan programas
            // reutilizables para no capturar lo mismo cada vez.
            TextButton.icon(
              onPressed: () => TemplatesDialog.show(context),
              icon: const Icon(Icons.copy_all_outlined, size: 18),
              label: const Text('Plantillas'),
            ),
          ],
        ),
      ),
    );
  }

  void _crearDia(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    ref
        .read(rundownProvider.notifier)
        .addDay(name: TimeFormatters.dayLabel(today), date: today, id: newId());
    messenger.showSnackBar(const SnackBar(content: Text('Día creado')));
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
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
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
