import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_config.dart';
import '../../core/ids.dart';
import '../../core/time_formatters.dart';
import '../../models/activity_item.dart';
import '../../models/event_day.dart';

/// Resultado del formulario lateral.
sealed class ActivityFormResult {
  const ActivityFormResult();
}

/// El usuario guardó la actividad.
class ActivitySaved extends ActivityFormResult {
  const ActivitySaved(this.item);
  final ActivityItem item;
}

/// El usuario eliminó la actividad.
class ActivityDeleted extends ActivityFormResult {
  const ActivityDeleted(this.id);
  final String id;
}

/// Abre el formulario de actividad como **drawer lateral** deslizante.
///
/// Se prefiere a una pantalla completa porque el itinerario sigue visible detrás:
/// el operador edita sin perder de vista el contexto del evento.
///
/// Devuelve `null` si el usuario cierra el formulario sin hacer nada.
Future<ActivityFormResult?> showActivityFormDrawer(
  BuildContext context, {
  required EventDay day,
  ActivityItem? existing,
}) {
  return showGeneralDialog<ActivityFormResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar formulario',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => ActivityFormDrawer(day: day, existing: existing),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Panel lateral con el formulario de creación / edición.
class ActivityFormDrawer extends StatefulWidget {
  const ActivityFormDrawer({super.key, required this.day, this.existing});

  final EventDay day;
  final ActivityItem? existing;

  @override
  State<ActivityFormDrawer> createState() => _ActivityFormDrawerState();
}

class _ActivityFormDrawerState extends State<ActivityFormDrawer> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _responsibleController;
  late final TextEditingController _locationController;

  late DateTime _startTime;

  /// Hora de fin explícita. `null` = se deduce de la siguiente actividad.
  DateTime? _endTime;

  /// Mensaje de validación cuando el fin no es posterior al inicio.
  String? _endError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    _startTime = existing?.startTime ??
        TimeFormatters.defaultStartForDay(widget.day.date);
    _endTime = existing?.endTime;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _responsibleController =
        TextEditingController(text: existing?.responsible ?? '');
    _locationController = TextEditingController(text: existing?.location ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _responsibleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final end = _endTime;
    if (end != null && !end.isAfter(_startTime)) {
      setState(() => _endError = 'La hora de fin debe ser posterior al inicio');
      return;
    }

    Navigator.of(context).pop(
      ActivitySaved(
        ActivityItem(
          id: widget.existing?.id ?? newId(),
          title: _titleController.text.trim(),
          startTime: _startTime,
          endTime: end,
          description: _optional(_descriptionController.text),
          responsible: _optional(_responsibleController.text),
          location: _optional(_locationController.text),
        ),
      ),
    );
  }

  void _delete() {
    Navigator.of(context).pop(ActivityDeleted(widget.existing!.id));
  }

  static String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Hora de fin que se deduciría si no se fija una explícita: el inicio de la
  /// siguiente actividad o, si es la última, la duración por defecto.
  DateTime _inferredEnd() {
    final others = widget.day.sortedActivities
        .where((a) => a.id != widget.existing?.id)
        .toList();

    for (final activity in others) {
      if (activity.startTime.isAfter(_startTime)) return activity.startTime;
    }
    return _startTime.add(AppConfig.defaultLastActivityDuration);
  }

  Future<void> _pickTime({required bool isEnd}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        isEnd ? (_endTime ?? _inferredEnd()) : _startTime,
      ),
      helpText: isEnd ? 'Hora de fin' : 'Hora de inicio',
    );
    if (picked == null || !mounted) return;

    setState(() {
      final value =
          TimeFormatters.at(widget.day.date, picked.hour, picked.minute);
      if (isEnd) {
        _endTime = value;
        _endError = null;
      } else {
        _startTime = value;
      }
    });
  }

  void _shiftBy(Duration delta) {
    setState(() {
      _startTime = _startTime.add(delta);
      // Si hay fin explícito se desplaza con el inicio para no invalidarlo.
      _endTime = _endTime?.add(delta);
      _endError = null;
    });
  }

  void _toggleExplicitEnd(bool enabled) {
    setState(() {
      _endTime = enabled ? _inferredEnd() : null;
      _endError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final screenWidth = MediaQuery.sizeOf(context).width;
    // En pantallas estrechas el drawer ocupa todo el ancho; en escritorio, una
    // columna fija que no tapa el itinerario.
    final panelWidth = screenWidth < 760 ? screenWidth : 520.0;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Material(
        color: scheme.surface,
        elevation: 16,
        shadowColor: Colors.black54,
        child: SizedBox(
          width: panelWidth,
          child: Column(
            children: [
              _buildHeader(theme, scheme),
              Divider(height: 1, color: scheme.outlineVariant),
              Expanded(child: _buildForm(theme, scheme)),
              _buildFooter(theme, scheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 12, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Editar actividad' : 'Nueva actividad',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.day.name,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme, ColorScheme scheme) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        children: [
          // --- Hora de inicio -------------------------------------------------
          Text('Hora de inicio', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _pickTime(isEnd: false),
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.schedule_rounded),
              ),
              child: Text(
                TimeFormatters.time(_startTime),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _QuickChip(
                label: '+5 min',
                onTap: () => _shiftBy(const Duration(minutes: 5)),
              ),
              _QuickChip(
                label: '+15 min',
                onTap: () => _shiftBy(const Duration(minutes: 15)),
              ),
              _QuickChip(
                label: '+30 min',
                onTap: () => _shiftBy(const Duration(minutes: 30)),
              ),
              _QuickChip(
                label: '-5 min',
                onTap: () => _shiftBy(const Duration(minutes: -5)),
              ),
              _QuickChip(
                label: 'Ahora',
                onTap: () => setState(() {
                  _startTime =
                      TimeFormatters.defaultStartForDay(widget.day.date);
                  _endError = null;
                }),
              ),
            ],
          ),

          const SizedBox(height: 22),
          _buildEndTimeSection(theme, scheme),

          const SizedBox(height: 24),
          TextFormField(
            controller: _titleController,
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Título *',
              hintText: 'Bienvenida y registro',
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'El título es obligatorio'
                : null,
          ),

          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 16),
          TextFormField(
            controller: _responsibleController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Responsable',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),

          const SizedBox(height: 16),
          TextFormField(
            controller: _locationController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Lugar',
              prefixIcon: Icon(Icons.place_outlined),
            ),
          ),
        ],
      ),
    );
  }

  /// Sección de hora de fin: por defecto deducida, con opción de fijarla a mano.
  Widget _buildEndTimeSection(ThemeData theme, ColorScheme scheme) {
    final explicit = _endTime != null;
    final inferred = _inferredEnd();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Hora de fin', style: theme.textTheme.titleSmall),
            ),
            Text(
              explicit ? 'Fijada a mano' : 'Deducida',
              style: theme.textTheme.labelSmall?.copyWith(
                color: explicit ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            Switch(
              value: explicit,
              onChanged: _toggleExplicitEnd,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (explicit)
          InkWell(
            onTap: () => _pickTime(isEnd: true),
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.schedule_rounded),
                errorText: _endError,
              ),
              child: Text(
                TimeFormatters.time(_endTime!),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Termina a las ${TimeFormatters.time(inferred)} · se deduce '
                    'de la siguiente actividad',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          explicit
              ? 'El fin fijado a mano manda sobre la deducción automática.'
              : 'Activa el interruptor solo si esta actividad tiene un cierre '
                  'propio, como una fiesta de cierre o un refrigerio corto.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildFooter(ThemeData theme, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (_isEditing) ...[
            IconButton.outlined(
              onPressed: _delete,
              tooltip: 'Eliminar actividad',
              icon: const Icon(Icons.delete_outline_rounded),
              color: scheme.error,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(_isEditing ? 'Guardar cambios' : 'Agregar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: TextStyle(color: scheme.primary),
    );
  }
}
