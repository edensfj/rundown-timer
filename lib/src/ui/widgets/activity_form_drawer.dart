import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_config.dart';
import '../../core/ids.dart';
import '../../core/duration_input.dart';
import '../../core/time_formatters.dart';
import '../../models/activity_item.dart';
import '../../models/activity_notice.dart';
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

  /// Duración escrita a mano («30m», «1h30», «30s»). Vacío = se deduce.
  late final TextEditingController _durationController;

  // --- Aviso en pantalla ------------------------------------------------------

  /// Texto del aviso. Vacío = la actividad no avisa de nada.
  late final TextEditingController _noticeController;

  /// Cuánto cruza el aviso, cuando se limita por tiempo.
  late final TextEditingController _noticeDurationController;

  /// Cuántas veces cruza, cuando se limita por repeticiones.
  late final TextEditingController _noticeRepeatsController;

  NoticeTrigger _noticeTrigger = NoticeTrigger.onStart;
  NoticeLimit _noticeLimit = NoticeLimit.duration;
  bool _noticeShowTimer = true;

  late DateTime _startTime;

  /// Hora de fin explícita. `null` = se deduce de la siguiente actividad.
  DateTime? _endTime;

  /// Mensaje de validación cuando el fin no es posterior al inicio.
  String? _endError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final day = widget.day;
    // La lista del panel siempre trae las horas del programa —el desfase es solo
    // del escenario—, así que lo que llega aquí se puede editar y guardar tal
    // cual.
    final existing = widget.existing;

    _startTime =
        existing?.startTime ?? TimeFormatters.defaultStartForDay(day.date);
    _endTime = existing?.endTime;

    // Una actividad con fin fijado a mano se lee de vuelta como duración: es lo
    // mismo dicho de otra forma, y es lo que el operador escribió.
    final explicitEnd = _endTime;
    _durationController = TextEditingController(
      text: explicitEnd != null && explicitEnd.isAfter(_startTime)
          ? formatDurationInput(explicitEnd.difference(_startTime))
          : '',
    );

    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _responsibleController = TextEditingController(
      text: existing?.responsible ?? '',
    );
    _locationController = TextEditingController(text: existing?.location ?? '');

    final notice = existing?.notice;
    _noticeController = TextEditingController(text: notice?.text ?? '');
    _noticeTrigger = notice?.trigger ?? NoticeTrigger.onStart;
    _noticeLimit = notice?.limit ?? NoticeLimit.duration;
    _noticeShowTimer = notice?.showTimer ?? true;
    _noticeDurationController = TextEditingController(
      text: formatDurationInput(notice?.duration ?? const Duration(minutes: 1)),
    );
    _noticeRepeatsController = TextEditingController(
      text: '${notice?.repeats ?? 2}',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _responsibleController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    _noticeController.dispose();
    _noticeDurationController.dispose();
    _noticeRepeatsController.dispose();
    super.dispose();
  }

  /// Aviso del campo de duración: solo cuando hay algo escrito que no se
  /// entiende. Vacío significa «deduzca la duración», que siempre vale.
  String? get _durationError {
    final text = _durationController.text.trim();
    if (text.isEmpty) return null;
    return parseDuration(text) == null ? 'No entiendo esa duración' : null;
  }

  /// Error de la duración del aviso, si toca limitarlo por tiempo.
  String? get _noticeDurationError {
    if (_noticeLimit != NoticeLimit.duration) return null;
    if (_noticeController.text.trim().isEmpty) return null;
    return parseDuration(_noticeDurationController.text) == null
        ? 'No entiendo esa duración'
        : null;
  }

  /// Error del número de pasadas, si toca limitar el aviso por repeticiones.
  String? get _noticeRepeatsError {
    if (_noticeLimit != NoticeLimit.repeats) return null;
    if (_noticeController.text.trim().isEmpty) return null;
    final veces = int.tryParse(_noticeRepeatsController.text.trim());
    return veces == null || veces < 1 ? 'Pon cuántas veces cruza' : null;
  }

  /// El aviso que hay escrito, o `null` si no hay nada que mandar.
  ActivityNotice? _noticeOrNull() {
    final text = _noticeController.text.trim();
    if (text.isEmpty) return null;

    return ActivityNotice(
      text: text,
      trigger: _noticeTrigger,
      limit: _noticeLimit,
      duration:
          parseDuration(_noticeDurationController.text) ??
          const Duration(minutes: 1),
      repeats: int.tryParse(_noticeRepeatsController.text.trim()) ?? 2,
      showTimer: _noticeShowTimer,
    );
  }

  /// Rehace la hora de fin con lo que haya escrito en el campo de duración.
  ///
  /// Vacío = se deduce de la siguiente actividad, que es lo de siempre.
  void _rebuildEnd() {
    final text = _durationController.text.trim();
    _endError = null;
    if (text.isEmpty) {
      _endTime = null;
      return;
    }

    final duration = parseDuration(text);
    _endTime = duration == null ? null : _startTime.add(duration);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_durationError != null) return;
    if (_noticeDurationError != null || _noticeRepeatsError != null) {
      // Hay que repintar para que salga el error en el campo del aviso.
      setState(() {});
      return;
    }

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
          notice: _noticeOrNull(),
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

    final value = TimeFormatters.at(
      widget.day.date,
      picked.hour,
      picked.minute,
    );

    setState(() {
      if (!isEnd) {
        // Mover el inicio no deshace la duración: si dura 30 minutos, sigue
        // durando 30 aunque se cambie la hora de arranque.
        _startTime = value;
        _rebuildEnd();
        return;
      }

      _endTime = value;
      if (value.isAfter(_startTime)) {
        _endError = null;
        // El reloj es la otra manera de escribir la duración: se refleja en el
        // campo para que las dos vistas digan lo mismo.
        _durationController.text = formatDurationInput(
          value.difference(_startTime),
        );
      } else {
        _endError = 'La hora de fin debe ser posterior al inicio';
      }
    });
  }

  void _shiftBy(Duration delta) {
    setState(() {
      _startTime = _startTime.add(delta);
      // Si hay duración escrita, el fin se rehace con ella; si no, el fin
      // deducido se desplaza con el inicio para no invalidarlo.
      if (_durationController.text.trim().isEmpty) {
        _endTime = _endTime?.add(delta);
        _endError = null;
      } else {
        _rebuildEnd();
      }
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
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.day.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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
                  _startTime = TimeFormatters.defaultStartForDay(
                    widget.day.date,
                  );
                  _rebuildEnd();
                }),
              ),
            ],
          ),

          const SizedBox(height: 22),
          _buildDurationSection(theme, scheme),

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

          const SizedBox(height: 26),
          _buildNoticeSection(theme, scheme),
        ],
      ),
    );
  }

  /// Sección del aviso: un texto que sale a la pantalla solo, al empezar la
  /// actividad o al terminarla.
  ///
  /// Va **plegada**: mientras no se escriba nada, la actividad se comporta como
  /// siempre y el formulario no se llena de campos que no se usan. En cuanto hay
  /// texto, aparecen las opciones.
  Widget _buildNoticeSection(ThemeData theme, ColorScheme scheme) {
    final hayTexto = _noticeController.text.trim().isNotEmpty;
    final porTiempo = _noticeLimit == NoticeLimit.duration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.campaign_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text('Aviso en pantalla', style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Un texto que cruza solo, con el estilo de la marquesina. Déjalo '
          'vacío si la actividad no avisa de nada.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noticeController,
          onChanged: (_) => setState(() {}),
          maxLines: 2,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Texto del aviso',
            hintText: 'Pueden salir del salón',
            prefixIcon: Icon(Icons.message_outlined),
          ),
        ),
        if (hayTexto) ...[
          const SizedBox(height: 16),
          Text('¿Cuándo sale?', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<NoticeTrigger>(
              segments: [
                for (final trigger in NoticeTrigger.values)
                  ButtonSegment(value: trigger, label: Text(trigger.label)),
              ],
              selected: {_noticeTrigger},
              onSelectionChanged: (seleccion) =>
                  setState(() => _noticeTrigger = seleccion.first),
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('¿Cuánto se queda?', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<NoticeLimit>(
              segments: [
                for (final limit in NoticeLimit.values)
                  ButtonSegment(value: limit, label: Text(limit.label)),
              ],
              selected: {_noticeLimit},
              onSelectionChanged: (seleccion) =>
                  setState(() => _noticeLimit = seleccion.first),
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (porTiempo)
            TextField(
              controller: _noticeDurationController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Duración del aviso',
                hintText: '1m · 30s',
                prefixIcon: const Icon(Icons.timelapse_rounded),
                errorText: _noticeDurationError,
              ),
            )
          else
            TextField(
              controller: _noticeRepeatsController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Veces que cruza',
                hintText: '2',
                prefixIcon: const Icon(Icons.repeat_rounded),
                errorText: _noticeRepeatsError,
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _noticeShowTimer,
            onChanged: (v) => setState(() => _noticeShowTimer = v),
            title: const Text('Mostrar el reloj'),
            subtitle: Text(
              _noticeShowTimer
                  ? 'El texto cruza mientras se ve la cuenta atrás.'
                  : 'El aviso ocupa la pantalla entera.',
            ),
          ),
        ],
      ],
    );
  }

  /// Sección de duración: se escribe cuánto dura y la hora de fin sale de ahí.
  ///
  /// Se escribe como se habla («30m», «1h30», «1:30», «0.5m», «30s») o se deja
  /// vacío, que es lo de siempre: la duración se deduce de cuándo empieza la
  /// siguiente actividad.
  Widget _buildDurationSection(ThemeData theme, ColorScheme scheme) {
    final explicit = _endTime != null;
    final end = _endTime ?? _inferredEnd();
    final deduced = _inferredEnd().difference(_startTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Duración', style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        TextField(
          controller: _durationController,
          onChanged: (_) => setState(_rebuildEnd),
          decoration: InputDecoration(
            hintText: '30m · 1h30 · 1:30 · 30s',
            prefixIcon: const Icon(Icons.timelapse_rounded),
            errorText: _durationError ?? _endError,
            helperText:
                'Déjalo vacío para que la saques de la siguiente '
                'actividad.',
            suffixIcon: explicit
                ? IconButton(
                    onPressed: () => setState(() {
                      _durationController.clear();
                      _rebuildEnd();
                    }),
                    tooltip: 'Volver a la duración deducida',
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                explicit ? Icons.event_available_outlined : Icons.auto_awesome,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Termina a las ${TimeFormatters.time(end)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      explicit
                          ? 'Duración fijada: ${_durationLabel(end.difference(_startTime))}.'
                          : 'Deducida de la siguiente: ${_durationLabel(deduced)}.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _pickTime(isEnd: true),
                child: const Text('Fijar hora'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Una duración escrita como se lee en voz alta: «1 h 30 min», «45 s».
  static String _durationLabel(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final hours = duration.inHours;
    final resto = minutes % 60;

    final parts = <String>[
      if (hours > 0) '$hours h',
      if (resto > 0) '$resto min',
      if (seconds > 0) '$seconds s',
    ];
    return parts.isEmpty ? '0 s' : parts.join(' ');
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
