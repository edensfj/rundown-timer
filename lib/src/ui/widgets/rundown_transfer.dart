// Escritorio escribe archivos con `dart:io`; web usa el selector y la descarga
// del navegador.
export 'rundown_transfer_web.dart'
    if (dart.library.io) 'rundown_transfer_desktop.dart';
