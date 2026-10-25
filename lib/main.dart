// En escritorio arranca el bootstrap de siempre; en web, uno sin ventanas
// nativas ni procesos. La elección se hace en tiempo de compilación para que el
// árbol web no arrastre `dart:io` ni los plugins de escritorio.
import 'src/bootstrap/web_bootstrap.dart'
    if (dart.library.io) 'src/bootstrap/desktop_bootstrap.dart';

Future<void> main(List<String> args) => bootstrap(args);
