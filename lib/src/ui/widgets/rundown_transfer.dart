import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/rundown_transfer.dart';
import '../../models/event_day.dart';
import '../../state/rundown_provider.dart';

/// Importar y exportar la programación como archivo JSON.
///
/// Exportar vuelca los días a un archivo; importar los trae de vuelta. Importar no
/// borra nada sin preguntar: se elige entre añadir a lo que ya hay o reemplazarlo.
///
/// No hay ningún botón propio: las dos acciones se ofrecen desde la pantalla de
/// configuración, que es donde vive todo lo que se ajusta.
///
/// Vuelca todos los días a un archivo JSON elegido por el operador.
Future<void> exportRundown(BuildContext context, WidgetRef ref) async {
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

/// Trae los días de un archivo JSON. Pregunta si se añaden o reemplazan.
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
