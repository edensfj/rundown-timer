import 'dart:js_interop';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../data/rundown_transfer.dart';
import '../../models/event_day.dart';
import '../../state/rundown_provider.dart';

/// Exporta la programación como descarga del navegador.
Future<void> exportRundown(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final days = ref.read(rundownProvider).value ?? const <EventDay>[];

  if (days.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No hay programación para exportar.')),
    );
    return;
  }

  try {
    final contenido = encodeRundown(days);
    final blob = web.Blob(
      [contenido.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = 'programacion-rundown.json';
    anchor.click();
    web.URL.revokeObjectURL(url);

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

/// Trae los días de un archivo JSON elegido con el selector del navegador.
Future<void> importRundown(BuildContext context, WidgetRef ref) async {
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

  final replace = await askHowToImport(context, days.length);
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
Future<bool?> askHowToImport(BuildContext context, int count) {
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
