import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/rundown_transfer.dart';
import '../../models/event_day.dart';
import '../../state/rundown_provider.dart';

/// Botón de la barra para **importar o exportar la programación** en JSON.
///
/// Un solo botón con menú: exportar vuelca los días a un archivo, importar los
/// trae de vuelta. Importar no borra nada sin preguntar: se elige entre añadir
/// a lo que ya hay o reemplazarlo.
class RundownTransferButton extends ConsumerWidget {
  const RundownTransferButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_Transfer>(
      tooltip: 'Importar o exportar la programación',
      icon: const Icon(Icons.import_export_rounded),
      onSelected: (action) => switch (action) {
        _Transfer.exportJson => _export(context, ref),
        _Transfer.importJson => _import(context, ref),
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _Transfer.exportJson,
          child: _MenuRow(
            icon: Icons.file_download_outlined,
            label: 'Exportar a JSON…',
          ),
        ),
        PopupMenuItem(
          value: _Transfer.importJson,
          child: _MenuRow(
            icon: Icons.file_upload_outlined,
            label: 'Importar desde JSON…',
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final days = ref.read(rundownProvider).value ?? const <EventDay>[];

    if (days.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No hay programación para exportar.')),
      );
      return;
    }

    final location = await getSaveLocation(
      suggestedName: 'programacion-rundown.json',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: [kRundownFileExtension]),
      ],
    );
    if (location == null) return; // El operador canceló el diálogo.

    try {
      await File(location.path).writeAsString(encodeRundown(days));
      messenger.showSnackBar(
        SnackBar(
          content: Text('Programación exportada (${days.length} día(s)).'),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo exportar: $error')),
      );
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: [kRundownFileExtension]),
      ],
    );
    if (file == null) return; // El operador canceló el diálogo.

    final List<EventDay> days;
    try {
      days = decodeRundown(await file.readAsString());
    } on FormatException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Archivo no válido: ${error.message}')),
      );
      return;
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo leer el archivo: $error')),
      );
      return;
    }

    if (days.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('El archivo no trae ningún día.')),
      );
      return;
    }
    if (!context.mounted) return;

    final replace = await _askHowToImport(context, days.length);
    if (replace == null) return; // Cancelado.

    await ref.read(rundownProvider.notifier).importDays(days, replace: replace);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${replace ? 'Programación reemplazada' : 'Programación añadida'} '
          '(${days.length} día(s)).',
        ),
      ),
    );
  }

  /// Pregunta si reemplazar o añadir. Devuelve `true` para reemplazar, `false`
  /// para añadir y `null` si se cancela.
  Future<bool?> _askHowToImport(BuildContext context, int count) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar programación'),
        content: Text(
          'El archivo trae $count día(s). ¿Quieres añadirlos a lo que ya '
          'tienes o reemplazar la programación actual?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Añadir'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reemplazar'),
          ),
        ],
      ),
    );
  }
}

enum _Transfer { exportJson, importJson }

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
    );
  }
}
