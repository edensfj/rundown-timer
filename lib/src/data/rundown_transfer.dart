import 'dart:convert';

import '../models/event_day.dart';

/// Extensión de los archivos de programación.
const String kRundownFileExtension = 'json';

/// Marca para reconocer un archivo exportado por la app.
const String _formatId = 'rundown-timer';

/// Versión del formato. Si algún día cambia, se puede migrar al importar.
const int _formatVersion = 1;

/// Convierte los días del evento en el texto JSON que se exporta.
///
/// El formato es legible a propósito: un objeto con la marca de la app, la
/// versión y la lista de días, tal cual se guardan. Así el archivo se puede
/// revisar o editar a mano sin herramientas.
String encodeRundown(List<EventDay> days) {
  return const JsonEncoder.withIndent('  ').convert({
    'app': _formatId,
    'version': _formatVersion,
    'days': [for (final day in days) day.toJson()],
  });
}

/// Lee la programación de un texto JSON.
///
/// Acepta tanto el envoltorio que exporta la app como una lista de días suelta,
/// para no rechazar un archivo montado a mano. Lanza [FormatException] con un
/// mensaje claro si el contenido no es una programación.
List<EventDay> decodeRundown(String source) {
  final Object? data;
  try {
    data = jsonDecode(source);
  } on FormatException {
    throw const FormatException('El archivo no es un JSON válido.');
  }

  final rawDays = switch (data) {
    Map() => data['days'],
    List() => data,
    _ => null,
  };

  if (rawDays is! List) {
    throw const FormatException('El archivo no contiene una programación.');
  }

  final days = <EventDay>[];
  for (final raw in rawDays) {
    if (raw is! Map) {
      throw const FormatException('Uno de los días del archivo no es válido.');
    }
    try {
      days.add(EventDay.fromJson(raw));
    } catch (_) {
      throw const FormatException(
        'Uno de los días del archivo está incompleto o corrupto.',
      );
    }
  }
  return days;
}
