import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rundown/src/window/window_placement.dart';

/// El orden de estas llamadas no es cosmético: en Windows `window_manager`
/// aplica el fullscreen al monitor que CONTIENE la ventana, así que activarlo
/// antes de moverla dejaría el escenario en la pantalla equivocada. Es
/// exactamente el fallo que se estaba viendo con dos monitores.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Proyector a la derecha del portátil.
  const proyector = Rect.fromLTWH(1920, 0, 1920, 1080);

  List<MethodCall> conEspia({bool yaFullScreen = false}) {
    final llamadas = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'),
            (call) async {
      llamadas.add(call);
      if (call.method == 'isFullScreen') return yaFullScreen;
      return true;
    });

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
    });

    return llamadas;
  }

  test('mueve la ventana a la pantalla y DESPUÉS la pone a pantalla completa',
      () async {
    final llamadas = conEspia();

    await placeWindow(proyector, fullscreen: true);

    final bounds = llamadas.where((c) => c.method == 'setBounds').toList();
    expect(bounds, hasLength(2),
        reason: 'una llamada para la posición y otra para el tamaño');

    // Posición en píxeles lógicos: el plugin ya los pasa a físicos él mismo.
    final posicion = bounds[0].arguments as Map;
    expect(posicion['x'], 1920);
    expect(posicion['y'], 0);
    expect(posicion.containsKey('width'), isFalse);

    final tamano = bounds[1].arguments as Map;
    expect(tamano['width'], 1920);
    expect(tamano['height'], 1080);

    expect(
      llamadas.map((c) => c.method),
      containsAllInOrder(
          ['setBounds', 'setBounds', 'isFullScreen', 'setFullScreen']),
    );
    expect(llamadas.last.arguments['isFullScreen'], isTrue);
  });

  test('en una sola pantalla solo se coloca, sin pantalla completa', () async {
    final llamadas = conEspia();

    await placeWindow(const Rect.fromLTWH(160, 90, 1600, 900), fullscreen: false);

    expect(llamadas.map((c) => c.method), isNot(contains('setFullScreen')));
    expect((llamadas.first.arguments as Map)['x'], 160);
  });

  test('si ya está a pantalla completa no se vuelve a activar', () async {
    final llamadas = conEspia(yaFullScreen: true);

    await placeWindow(proyector, fullscreen: true);

    expect(llamadas.map((c) => c.method), isNot(contains('setFullScreen')),
        reason: 'volver a activarlo haría parpadear la ventana proyectada');
  });
}
