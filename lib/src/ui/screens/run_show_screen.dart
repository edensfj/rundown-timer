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
import '../../state/displays_provider.dart';
import '../../state/run_show_provider.dart';
import '../widgets/run_show_controls.dart';
import '../widgets/stage_view.dart';

/// Modo Escenario: la vista que se proyecta, con controles para el operador.
///
/// - **Texto blanco sobre pantalla negra** en todas las fases.
/// - Al agotarse el tiempo, la **pantalla completa parpadea en rojo** de aviso.
/// - El countdown es lo más importante: ocupa todo el espacio disponible.
/// - Controles que se ocultan solos y se revelan al mover el ratón.
///
/// El contenido visual vive en [StageView], compartido con la vista previa del
/// programador para que ambas muestren exactamente lo mismo.
///
/// Atajos: `Espacio` pausa, `←`/`→` cambian de actividad, `R` reinicia,
/// `A` vuelve al modo automático, `F` fullscreen, `E` finaliza el evento.
class RunShowScreen extends ConsumerStatefulWidget {
  const RunShowScreen({super.key});

  @override
  ConsumerState<RunShowScreen> createState() => _RunShowScreenState();
}

class _RunShowScreenState extends ConsumerState<RunShowScreen>
    with WindowListener {
  Timer? _idleTimer;
  bool _controlsVisible = true;
  bool _isFullscreen = false;

  /// Geometría de la ventana antes de entrar al escenario, para devolverla a su
  /// sitio al salir. En Linux `setFullScreen(false)` por sí solo no siempre
  /// restaura el tamaño previo, así que se guarda de forma explícita.
  Rect? _restoreBounds;

  @override
  void initState() {
    super.initState();

    WakelockPlus.enable();

    // El escenario es una superficie limpia: no admite notificaciones encima.
    // Los SnackBar del panel se muestran desde el ScaffoldMessenger raíz, que
    // va POR ENCIMA del Navigator, así que uno pendiente (típicamente
    // «Actividad eliminada · Deshacer») seguiría viéndose aquí dentro. Se
    // descartan al entrar, incluidos los que estén en cola.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    });

    windowManager.addListener(this);
    _enterStage();

    _scheduleIdleHide();
  }

  /// Coloca la ventana en la pantalla elegida y la pone a pantalla completa.
  ///
  /// La pantalla se elige desde el dashboard, no aquí: el operador decide antes
  /// de entrar y no tiene que buscar nada con el evento ya proyectándose.
  ///
  /// Si **no** hay pantalla elegida pero hay más de una conectada, se proyecta
  /// en la otra (ver [resolveStageDisplay]); solo se abre en ventana cuando de
  /// verdad hay una sola pantalla, porque entonces no hay a dónde proyectar.
  Future<void> _enterStage() async {
    try {
      final position = await windowManager.getPosition();
      final size = await windowManager.getSize();
      _restoreBounds = position & size;
    } catch (_) {
      _restoreBounds = null;
    }

    final target = await resolveStageDisplay(ref, panelBounds: _restoreBounds);
    if (!mounted) return;

    if (target != null) {
      await projectOntoDisplay(target);
      return;
    }

    await windowManager.setFullScreen(false);
    await windowManager.setSize(AppConfig.stageWindowSize);
    await windowManager.center();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    windowManager.removeListener(this);
    WakelockPlus.disable();

    // Salir del escenario devuelve la ventana a su tamaño y sitio originales.
    _leaveStage();

    super.dispose();
  }

  Future<void> _leaveStage() async {
    await windowManager.setFullScreen(false);

    final bounds = _restoreBounds;
    if (bounds == null) return;

    await windowManager.setSize(bounds.size);
    await windowManager.setPosition(bounds.topLeft);
  }

  // --- Fullscreen nativo de escritorio -------------------------------------

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _isFullscreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _isFullscreen = false);
  }

  void _toggleFullscreen() => windowManager.setFullScreen(!_isFullscreen);

  // --- Auto-ocultado de controles -------------------------------------------

  void _scheduleIdleHide() {
    _idleTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);

    _idleTimer = Timer(AppConfig.controlsIdleTimeout, _hideControls);
  }

  /// Los controles nunca se ocultan con el timer en pausa: haría falta un
  /// clic extra para poder reanudarlo.
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
    final hasActivities = snapshot.hasActivities;

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
          const SingleActivator(LogicalKeyboardKey.keyA): _run.followClock,
          const SingleActivator(LogicalKeyboardKey.keyE): _toggleFinished,
          const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
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
                  if (hasActivities) _overlay(snapshot),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Barra superior (volver / fullscreen) y barra inferior de controles.
  Widget _overlay(CountdownSnapshot snapshot) {
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
                      tooltip: 'Volver al itinerario',
                      onPressed: () => Navigator.of(context).maybePop(),
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
                  onRestart: _restart,
                  onSubtractTime: () => _addTime(const Duration(minutes: -1)),
                  onAddTime: () => _addTime(const Duration(minutes: 1)),
                  onToggleAutomatic: () {
                    _run.followClock();
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
