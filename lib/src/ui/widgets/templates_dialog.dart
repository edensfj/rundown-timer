import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ids.dart';
import '../../core/time_formatters.dart';
import '../../models/event_day.dart';
import '../../models/rundown_template.dart';
import '../../state/rundown_provider.dart';
import '../../state/templates_provider.dart';
import 'template_editor_dialog.dart';

/// Gestión de plantillas: crear, editar, borrar y **aplicar a un día**.
///
/// Se abre desde el dashboard. Necesita saber sobre qué día se aplican las
/// plantillas, de ahí [day] (puede ser `null` si todavía no hay ningún día).
class TemplatesDialog extends ConsumerWidget {
  const TemplatesDialog({super.key, required this.day});

  final EventDay? day;

  static Future<void> show(BuildContext context, {EventDay? day}) {
    return showDialog<void>(
      context: context,
      builder: (_) => TemplatesDialog(day: day),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plantillas = ref.watch(sortedTemplatesProvider);
    final cargando = ref.watch(templatesProvider).isLoading;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.copy_all_outlined),
          SizedBox(width: 10),
          Text('Plantillas'),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: 440,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Un programa reutilizable, guardado por duraciones. Al aplicarlo a '
              'un día eliges la hora de comienzo y el resto se calcula solo.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            if (cargando)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (plantillas.isEmpty)
              Expanded(child: _SinPlantillas(onCrear: () => _crear(context, ref)))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: plantillas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _TarjetaPlantilla(
                    plantilla: plantillas[i],
                    puedeAplicar: day != null,
                    onAplicar: () => _aplicar(context, ref, plantillas[i]),
                    onEditar: () => _editar(context, ref, plantillas[i]),
                    onEliminar: () => _eliminar(context, ref, plantillas[i]),
                  ),
                ),
              ),

            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _crear(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Nueva plantilla'),
                ),
                const SizedBox(width: 10),
                // Atajo muy útil: montar el programa una vez y guardarlo.
                TextButton.icon(
                  onPressed: day == null || day!.isEmpty
                      ? null
                      : () => _guardarDesdeDia(context, ref, day!),
                  icon: const Icon(Icons.save_alt_rounded, size: 18),
                  label: const Text('Guardar el día actual'),
                ),
              ],
            ),
          ],
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

  Future<void> _crear(BuildContext context, WidgetRef ref) async {
    final plantilla = await TemplateEditorDialog.show(context);
    if (plantilla == null) return;
    await ref.read(templatesProvider.notifier).save(plantilla);
    if (context.mounted) _aviso(context, 'Plantilla «${plantilla.name}» guardada');
  }

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    RundownTemplate plantilla,
  ) async {
    final editada = await TemplateEditorDialog.show(context, existing: plantilla);
    if (editada == null) return;
    await ref.read(templatesProvider.notifier).save(editada);
    if (context.mounted) _aviso(context, 'Plantilla actualizada');
  }

  Future<void> _eliminar(
    BuildContext context,
    WidgetRef ref,
    RundownTemplate plantilla,
  ) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar plantilla'),
        content: Text(
          '¿Eliminar «${plantilla.name}»? Los días que ya la usaron no cambian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    await ref.read(templatesProvider.notifier).delete(plantilla.id);
    if (context.mounted) _aviso(context, 'Plantilla eliminada');
  }

  Future<void> _guardarDesdeDia(
    BuildContext context,
    WidgetRef ref,
    EventDay day,
  ) async {
    final nombre = await _pedirNombre(
      context,
      inicial: day.name,
      titulo: 'Guardar el día como plantilla',
      ayuda: 'Se guardarán las ${day.activities.length} actividades de «${day.name}» '
          'con sus duraciones actuales.',
    );
    if (nombre == null || nombre.trim().isEmpty) return;

    final creada = await ref
        .read(templatesProvider.notifier)
        .saveFromDay(day, id: newId(), name: nombre.trim());
    if (context.mounted) {
      _aviso(context, 'Plantilla «${creada.name}» creada con ${creada.activities.length} actividades');
    }
  }

  Future<void> _aplicar(
    BuildContext context,
    WidgetRef ref,
    RundownTemplate plantilla,
  ) async {
    final destino = day;
    if (destino == null) return;

    final hora = await _pedirHoraInicio(context, destino);
    if (hora == null || !context.mounted) return;

    final actividades = materializeTemplate(
      plantilla,
      hora,
      nextId: (_) => newId(),
    );

    final messenger = ScaffoldMessenger.of(context);
    await ref.read(rundownProvider.notifier).addActivities(destino.id, actividades);
    if (context.mounted) Navigator.of(context).pop();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${plantilla.activities.length} actividades añadidas a «${destino.name}» '
          'desde las ${TimeFormatters.time(hora)}',
        ),
      ),
    );
  }

  static void _aviso(BuildContext context, String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }
}

class _SinPlantillas extends StatelessWidget {
  const _SinPlantillas({required this.onCrear});

  final VoidCallback onCrear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.copy_all_outlined, size: 56, color: scheme.outline),
          const SizedBox(height: 16),
          Text('Todavía no hay plantillas', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              'Crea una con el ritmo de tu programa habitual y reutilízala cada '
              'vez que armes un día nuevo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCrear,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear plantilla'),
          ),
        ],
      ),
    );
  }
}

class _TarjetaPlantilla extends StatelessWidget {
  const _TarjetaPlantilla({
    required this.plantilla,
    required this.puedeAplicar,
    required this.onAplicar,
    required this.onEditar,
    required this.onEliminar,
  });

  final RundownTemplate plantilla;
  final bool puedeAplicar;
  final VoidCallback onAplicar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final resumen = plantilla.activities
        .take(4)
        .map((a) => '${a.title} (${TimeFormatters.humanDuration(a.duration)})')
        .join('  ·  ');
    final resto = plantilla.activities.length - 4;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        plantilla.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${plantilla.activities.length} act. · '
                      '${TimeFormatters.humanDuration(plantilla.totalDuration)}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.primary),
                    ),
                  ],
                ),
                if (resumen.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    resto > 0 ? '$resumen  ·  +$resto más' : resumen,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: puedeAplicar ? onAplicar : null,
            child: const Text('Aplicar'),
          ),
          IconButton(
            onPressed: onEditar,
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            onPressed: onEliminar,
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: scheme.error,
          ),
        ],
      ),
    );
  }
}

/// Pide la hora desde la que arrancar la plantilla.
Future<DateTime?> _pedirHoraInicio(BuildContext context, EventDay day) async {
  // Por defecto, la hora sugerida del formulario: la actual redondeada.
  var elegida = TimeFormatters.defaultStartForDay(day.date);

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('¿Desde qué hora?'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La primera actividad empezará a esta hora y las demás se '
                'encadenan según sus duraciones.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(elegida),
                    helpText: 'Hora de comienzo',
                  );
                  if (picked == null) return;
                  setLocal(() {
                    elegida = TimeFormatters.at(
                      day.date,
                      picked.hour,
                      picked.minute,
                    );
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.schedule_rounded),
                  ),
                  child: Text(
                    TimeFormatters.time(elegida),
                    style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(elegida),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _pedirNombre(
  BuildContext context, {
  required String titulo,
  required String ayuda,
  String inicial = '',
}) {
  final controller = TextEditingController(text: inicial);
  final formKey = GlobalKey<FormState>();

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: SizedBox(
        width: 420,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ayuda, style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la plantilla',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe un nombre'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(ctx).pop(controller.text.trim());
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}
