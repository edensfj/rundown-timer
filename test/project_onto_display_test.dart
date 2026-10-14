import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rundown/src/state/displays_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// Proyector a la derecha del portátil, como en un equipo de dos pantallas.
const proyector = Display(
  id: 'MONITOR\\PROJ123\\0002',
  name: r'\\.\DISPLAY2',
  size: Size(1920, 1080),
  visiblePosition: Offset(1920, 0),
  visibleSize: Size(1920, 1080),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('projectOntoDisplay mueve la ventana a la pantalla y la pone a pantalla completa',
      () async {
    final llamadas = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'),
            (call) async {
      llamadas.add(call);
      if (call.method == 'isFullScreen') return false;
      return true;
    });

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
    });

    await projectOntoDisplay(proyector);

    final metodos = llamadas.map((c) => c.method).toList();
    final bounds = llamadas.where((c) => c.method == 'setBounds').toList();

    expect(bounds, hasLength(2),
        reason: 'una llamada para la posición y otra para el tamaño');

    // 1. Posición: las coordenadas de la pantalla destino, en píxeles lógicos
    //    (es lo que espera el plugin, que ya los pasa a físicos él mismo).
    final posicion = bounds[0].arguments as Map;
    expect(posicion['x'], 1920);
    expect(posicion['y'], 0);
    expect(posicion.containsKey('width'), isFalse);

    // 2. Tamaño: el de la pantalla destino.
    final tamano = bounds[1].arguments as Map;
    expect(tamano['width'], 1920);
    expect(tamano['height'], 1080);
    expect(tamano.containsKey('x'), isFalse);

    // 3. El fullscreen va DESPUÉS de mover la ventana. No es un detalle de
    //    estilo: en Windows el plugin lo aplica al monitor que CONTIENE la
    //    ventana, así que si se activara antes saldría en la pantalla
    //    equivocada, que es justo el fallo que se estaba viendo.
    expect(
      metodos,
      containsAllInOrder(['setBounds', 'setBounds', 'isFullScreen', 'setFullScreen']),
    );
    expect(llamadas.last.arguments['isFullScreen'], isTrue);
  });

  test('si la ventana ya está a pantalla completa no se vuelve a activar', () async {
    final llamadas = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'),
            (call) async {
      llamadas.add(call);
      if (call.method == 'isFullScreen') return true;
      return true;
    });

    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
    });

    await projectOntoDisplay(proyector);

    expect(llamadas.map((c) => c.method), isNot(contains('setFullScreen')));
  });
}
