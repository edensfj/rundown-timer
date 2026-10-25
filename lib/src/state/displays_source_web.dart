import 'dart:ui';

import 'package:screen_retriever/screen_retriever.dart';

/// En web no hay varias pantallas nativas que enumerar: el escenario se
/// proyecta dentro de la misma pestaña. Se devuelve una pantalla sintética para
/// que el resto de la UI (selector, vista previa) siga funcionando sin tocar el
/// plugin de escritorio.
Future<List<Display>> getAllDisplays() async => [
  const Display(
    id: 'web',
    name: 'Ventana del navegador',
    size: Size(1600, 900),
    visiblePosition: Offset.zero,
    visibleSize: Size(1600, 900),
    scaleFactor: 1,
  ),
];
