import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/app_config.dart';
import '../../models/countdown_phase.dart';
import '../../models/countdown_snapshot.dart';
import '../../state/countdown_provider.dart';
import '../../state/run_show_provider.dart';
import '../../window/stage_window_controller.dart';
import '../widgets/run_show_controls.dart';
import '../widgets/stage_view.dart';

/// El escenario proyectado **dentro de la ventana del panel**.
///
/// Es el modo de una sola ventana, el único posible en Linux: allí el embedder
/// no aguanta una segunda vista de Flutter (ver [stageSecondWindowProvider]).
/// En Windows y macOS no se usa: el reloj va en su propia ventana y esta pantalla
/// no llega a construirse.
///
/// Lo que se ve es solo el reloj. Los controles se ocultan solos a los pocos
/// segundos y reaparecen al mover el ratón, para no ensuciar la proyección.
///
/// Atajos: `Espacio` pausa, `←`/`→` cambian de actividad, `R` reinicia,
/// `A` vuelve al modo automático, `F` pantalla completa, `E` finaliza el evento
/// y `Esc` sale del escenario.
class EmbeddedStageScreen extends ConsumerStatefulWidget {
  const EmbeddedStageScreen({super.key});

  @override
  ConsumerState<EmbeddedStageScreen> createState() =>
      _EmbeddedStageScreenState();
}

class _EmbeddedStageScreenState extends ConsumerState<EmbeddedStageScreen>
    with WindowListener {
  Timer? _idleTimer;
  bool _controlsVisible = true;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();

    WakelockPlus.enable();

    // El escenario es una superficie limpia: no admite notificaciones encima.
    // Los SnackBar del panel salen del ScaffoldMessenger raíz, que va POR ENCIMA
    // de todo esto, así que uno pendiente (típicamente «Actividad eliminada ·
    // Deshacer») seguiría viéndose aquí dentro. Se descartan al entrar, incluidos
    // los que estén en cola.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    });

    windowManager.addListener(this);
    _scheduleIdleHide();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    windowManager.removeListener(this);
    WakelockPlus.disable();
    super.dispose();
  }

  /// Sale del escenario y devuelve el panel.
  ///
  /// La geometría de la ventana la restaura el propio controlador, que es quien
  /// la había guardado al entrar.
  void _exit() => ref.read(stageWindowProvider.notifier).close();

  // --- Pantalla completa ----------------------------------------------------

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _isFullscreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _isFullscreen = false);
  }

  void _toggleFullscreen() => windowManager.setFullScreen(!_isFullscreen);

  // --- Auto-ocultado de los controles ---------------------------------------

  void _scheduleIdleHide() {
    _idleTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);

    _idleTimer = Timer(AppConfig.controlsIdleTimeout, _hideControls);
  }

  /// Con el reloj en pausa los controles no se esconden: haría falta un clic
  /// extra para poder reanudarlo.
  void _hideControls() {
    if (!mounted) return;

    if (ref.read(countdownProvider).isPaused) {
      _idleTimer = Timer(const Duration(seconds: 1), _hideControls);
      return;
    }
    setState(() => _controlsVisible = false);
  }

  void _keepControlsVisible() {
    _idleTimer?.cancel();
    if (!_controlsVisible && mounted) setState(() => _controlsVisible = true);
  }

  // --- Acciones -------------------------------------------------------------

  RunShowNotifier get _run => ref.read(runShowProvider.notifier);

  void _togglePause() {
    _run.togglePause();
    _keepControlsVisible();
  }

  void _toggleStopped() {
    _run.toggleStop();
    _keepControlsVisible();
  }

  void _next() {
    _run.goToNext();
    _keepControlsVisible();
  }

  void _previous() {
    _run.goToPrevious();
    _keepControlsVisible();
  }

  void _restart() {
    _run.restart();
    _keepControlsVisible();
  }

  void _addTime(Duration delta) {
    _run.addTime(delta);
    _keepControlsVisible();
  }

  void _toggleFinished() {
    if (ref.read(countdownProvider).isFinished) {
      _run.resumeEvent();
    } else {
      _run.finishEvent();
    }
    _keepControlsVisible();
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(countdownProvider);

    return Scaffold(
      backgroundColor: StageColors.black,
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.space): _togglePause,
          const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _previous,
          const SingleActivator(LogicalKeyboardKey.pageDown): _next,
          const SingleActivator(LogicalKeyboardKey.pageUp): _previous,
          const SingleActivator(LogicalKeyboardKey.keyR): _restart,
          const SingleActivator(LogicalKeyboardKey.keyS): _toggleStopped,
          const SingleActivator(LogicalKeyboardKey.keyA): _run.syncWithClock,
          const SingleActivator(LogicalKeyboardKey.keyE): _toggleFinished,
          const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
          const SingleActivator(LogicalKeyboardKey.escape): _exit,
        },
        child: Focus(
          autofocus: true,
          child: Listener(
            onPointerDown: (_) => _scheduleIdleHide(),
            child: MouseRegion(
              onHover: (_) => _scheduleIdleHide(),
              onEnter: (_) => _scheduleIdleHide(),
              child: Stack(
                children: [
                  const Positioned.fill(child: StageView()),
                  if (snapshot.hasActivities) _chrome(snapshot),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Botón de salida arriba y controles abajo, todo ocultable.
  Widget _chrome(CountdownSnapshot snapshot) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_controlsVisible,
        child: AnimatedOpacity(
          opacity: _controlsVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ChromeButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Volver al itinerario (Esc)',
                      onPressed: _exit,
                    ),
                    Row(
                      children: [
                        _ChromeButton(
                          icon: _isFullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          tooltip: 'Pantalla completa (F)',
                          onPressed: _toggleFullscreen,
                        ),
                        const SizedBox(width: 8),
                        _ChromeButton(
                          icon: Icons.stop_rounded,
                          tooltip: 'Finalizar evento (E)',
                          onPressed: _toggleFinished,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: RunShowControls(
                  snapshot: snapshot,
                  onPrevious: _previous,
                  onNext: _next,
                  onTogglePause: _togglePause,
                  onToggleStopped: _toggleStopped,
                  onRestart: _restart,
                  onSubtractTime: () => _addTime(const Duration(minutes: -1)),
                  onAddTime: () => _addTime(const Duration(minutes: 1)),
                  onToggleAutomatic: () {
                    _run.syncWithClock();
                    _keepControlsVisible();
                  },
                  onToggleFinished: _toggleFinished,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChromeButton extends StatelessWidget {
  const _ChromeButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 21, color: StageColors.white),
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
          ),
        ),
      ),
    );
  }
}
