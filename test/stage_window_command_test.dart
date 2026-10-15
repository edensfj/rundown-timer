import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rundown/src/models/countdown_snapshot.dart';
import 'package:rundown/src/window/stage_window.dart';

/// La orden «vuelve a ser una ventana normal» viaja por el mismo canal que el
/// reloj, así que lo primero que hay que garantizar es que **no se confundan**:
/// si el escenario se tomase una orden por una instantánea, se quedaría
/// congelado, y al revés, la ventana dejaría de moverse nunca.
void main() {
  const ventanaNormal = StageWindowCommand.windowed(
    Rect.fromLTWH(100, 200, 1600, 900),
  );

  group('StageWindowCommand', () {
    test('viaja y vuelve igual', () {
      final leida = StageWindowCommand.tryDecode(ventanaNormal.encode());

      expect(leida, isNotNull);
      expect(leida!.frame, const Rect.fromLTWH(100, 200, 1600, 900));
      expect(leida.fullscreen, isFalse);
    });

    test('también se le manda a pantalla completa', () {
      const orden = StageWindowCommand(
        frame: Rect.fromLTWH(1920, 0, 1920, 1080),
        fullscreen: true,
      );

      final leida = StageWindowCommand.tryDecode(orden.encode());

      expect(leida!.fullscreen, isTrue);
      expect(leida.frame.left, 1920);
    });

    test('una instantánea del reloj NO es una orden de ventana', () {
      final linea = jsonEncode(CountdownSnapshot.empty().toJson());

      expect(StageWindowCommand.tryDecode(linea), isNull,
          reason: 'si se tomara por una orden, el reloj se quedaría congelado');
    });

    test('la orden de cerrar tampoco', () {
      expect(StageWindowCommand.tryDecode(stageCloseCommand), isNull);
    });

    test('una línea rota no revienta el escenario', () {
      expect(StageWindowCommand.tryDecode('{no es json'), isNull);
      expect(StageWindowCommand.tryDecode(''), isNull);
      expect(StageWindowCommand.tryDecode('[]'), isNull);
    });

    test('una orden sin geometría se ignora en vez de colocar en (0,0)', () {
      expect(
        StageWindowCommand.fromJson({stageWindowCommandKey: stageWindowCommand}),
        isNull,
      );
    });

    test('llega deserializada por el canal del plugin, no como texto', () {
      final leida = StageWindowCommand.fromJson(ventanaNormal.toJson());

      expect(leida!.frame.width, 1600);
      expect(leida.fullscreen, isFalse);
    });
  });
}