// La proyección del escenario cambia por completo entre escritorio y web:
// ventana nativa/segundo proceso en escritorio; pestaña única con el escenario
// embebido en web.
export 'stage_window_controller_web.dart'
    if (dart.library.io) 'stage_window_controller_desktop.dart';
