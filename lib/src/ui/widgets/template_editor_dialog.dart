import 'package:flutter/material.dart';

import '../../core/duration_input.dart';
import '../../core/ids.dart';
import '../../core/time_formatters.dart';
import '../../models/rundown_template.dart';

/// Editor de una plantilla: nombre y lista de actividades con sus duraciones.
///
/// Se trabaja siempre sobre una copia en memoria y solo se devuelve al guardar,
/// así que cancelar no deja nada a medias.
///
/// Devuelve la plantilla resultante, o `null` si se cancela.
class TemplateEditorDialog extends StatefulWidget {
  const TemplateEditorDialog({super.key, this.existing});

  /// Plantilla a editar. Si es `null`, se crea una nueva.
  final RundownTemplate? existing;

  static Future<RundownTemplate?> show(
    BuildContext context, {
    RundownTemplate? existing,
  }) {
    return showDialog<RundownTemplate>(
      context: context,
      builder: (_) => TemplateEditorDialog(existing: existing),
    );
  }

  @override
  State<TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<TemplateEditorDialog> {
  late final TextEditingController _nombre;
  late List<_Row> _filas;

  bool get _editando => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existente = widget.existing;
    _nombre = TextEditingController(text: existente?.name ?? '');

    // Una plantilla nueva arranca VACÍA: nada de programas de ejemplo que luego
    // haya que borrar. El usuario escribe solo lo suyo.
    final iniciales = existente?.activities ?? const <TemplateActivity>[];
    _filas = [for (final a in iniciales) _Row.fromTemplate(a)];
  }

  @override
  void dispose() {
    _nombre.dispose();
    for (final fila in _filas) {
      fila.dispose();
    }
    super.dispose();
  }

  /// Duración total actual, para ir mostrando el resultado mientras se edita.
  Duration get _total => _filas.fold(
        Duration.zero,
        (sum, fila) => sum + (fila.duracionValor ?? Duration.zero),
      );

  bool get _valido =>
      _nombre.text.trim().isNotEmpty &&
      _filas.isNotEmpty &&
      _filas.every((f) => f.valido);

  void _agregarFila() {
    setState(() => _filas.add(_Row.vacia()));
  }

  void _eliminarFila(int index) {
    setState(() {
      _filas.removeAt(index).dispose();
    });
  }

  void _mover(int index, int delta) {
    final destino = index + delta;
    if (destino < 0 || destino >= _filas.length) return;
    setState(() {
      final fila = _filas.removeAt(index);
      _filas.insert(destino, fila);
    });
  }

  void _guardar() {
    if (!_valido) return;

    Navigator.of(context).pop(
      RundownTemplate(
        id: widget.existing?.id ?? newId(),
        name: _nombre.text.trim(),
        activities: [for (final fila in _filas) fila.aTemplateActivity()],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.copy_all_outlined),
          const SizedBox(width: 10),
          Text(_editando ? 'Editar plantilla' : 'Nueva plantilla'),
        ],
      ),
      content: SizedBox(
        width: 620,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombre,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre de la plantilla',
                hintText: 'Culto dominical, Retiro, Ensayo…',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Actividades y duraciones',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  'Total: ${TimeFormatters.humanDuration(_total)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _filas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.playlist_add_rounded,
                              size: 40,
                              color: scheme.outline,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Sin actividades todavía',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filas.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _FilaEditor(
                          key: ObjectKey(_filas[i]),
                          fila: _filas[i],
                          numero: i + 1,
                          puedeSubir: i > 0,
                          puedeBajar: i < _filas.length - 1,
                          onChanged: () => setState(() {}),
                          onSubir: () => _mover(i, -1),
                          onBajar: () => _mover(i, 1),
                          onEliminar: () => _eliminarFila(i),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _agregarFila,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Agregar actividad'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _valido ? _guardar : null,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Estado mutable de una fila del editor.
class _Row {
  _Row({String titulo = '', String duracion = '', this.description, this.responsible, this.location})
      : titulo = TextEditingController(text: titulo),
        duracion = TextEditingController(text: duracion);

  factory _Row.fromTemplate(TemplateActivity a) => _Row(
        titulo: a.title,
        duracion: formatDurationInput(a.duration),
        description: a.description,
        responsible: a.responsible,
        location: a.location,
      );

  factory _Row.vacia() =>
      _Row(duracion: formatDurationInput(kTemplateDefaultDuration));

  final TextEditingController titulo;

  /// Texto tal cual lo escribió el usuario: admite minutos y horas.
  final TextEditingController duracion;

  final String? description;
  final String? responsible;
  final String? location;

  /// `null` si lo escrito no se entiende o no es positivo.
  Duration? get duracionValor => parseDuration(duracion.text);

  bool get valido => titulo.text.trim().isNotEmpty && duracionValor != null;

  TemplateActivity aTemplateActivity() => TemplateActivity(
        title: titulo.text.trim(),
        duration: duracionValor ?? kTemplateDefaultDuration,
        description: description,
        responsible: responsible,
        location: location,
      );

  void dispose() {
    titulo.dispose();
    duracion.dispose();
  }
}

class _FilaEditor extends StatelessWidget {
  const _FilaEditor({
    super.key,
    required this.fila,
    required this.numero,
    required this.puedeSubir,
    required this.puedeBajar,
    required this.onChanged,
    required this.onSubir,
    required this.onBajar,
    required this.onEliminar,
  });

  final _Row fila;
  final int numero;
  final bool puedeSubir;
  final bool puedeBajar;
  final VoidCallback onChanged;
  final VoidCallback onSubir;
  final VoidCallback onBajar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final duracion = fila.duracionValor;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, right: 8),
            child: Text(
              '$numero',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: fila.titulo,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Nombre',
                hintText: 'Alabanza',
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 104,
            child: TextField(
              controller: fila.duracion,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Duración',
                hintText: '45 · 1:30 · 2h',
                errorText: duracion == null ? '' : null,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 10),
          // Resultado normalizado: confirma que se entendió lo escrito.
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SizedBox(
              width: 78,
              child: Text(
                duracion == null ? 'no válido' : TimeFormatters.humanDuration(duracion),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: duracion == null ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Column(
            children: [
              _MiniBoton(
                icon: Icons.keyboard_arrow_up_rounded,
                tooltip: 'Subir',
                onPressed: puedeSubir ? onSubir : null,
              ),
              _MiniBoton(
                icon: Icons.keyboard_arrow_down_rounded,
                tooltip: 'Bajar',
                onPressed: puedeBajar ? onBajar : null,
              ),
            ],
          ),
          _MiniBoton(
            icon: Icons.close_rounded,
            tooltip: 'Quitar',
            onPressed: onEliminar,
          ),
        ],
      ),
    );
  }
}

class _MiniBoton extends StatelessWidget {
  const _MiniBoton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      ),
    );
  }
}
