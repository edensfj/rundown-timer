/// Generador de identificadores cortos y únicos sin dependencias externas.
///
/// El formato es base-36: microsegundos desde epoch + un sufijo aleatorio.
library;

import 'dart:math';

final Random _random = Random();

String newId() {
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final salt = _random.nextInt(0x1000000).toRadixString(36).padLeft(5, '0');
  return '$stamp-$salt';
}
