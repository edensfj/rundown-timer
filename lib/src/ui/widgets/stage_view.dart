import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_config.dart';
import '../../core/time_formatters.dart';
import '../../models/countdown_phase.dart';
import '../../models/countdown_snapshot.dart';
import '../../models/marquee.dart';
import '../../models/stage_flash.dart';
import '../../state/clock_provider.dart';
import '../../state/countdown_provider.dart';
import 'countdown_display.dart';
import 'marquee_band.dart';
import 'next_activity_banner.dart';

/// Por debajo de este alto, el escenario se pinta en modo compacto: cabecera
/// reducida y sin pie, para que el reloj conserve todo el espacio posible.
///
/// El umbral está por encima del alto de la vista previa del panel —el caso
/// pequeño habitual— y muy por debajo del de cualquier ventana real en un
/// proyector.
const double _compactHeight = 420;

/// Composición visual completa del modo escenario: fondo, destello rojo de
/// alerta, cabecera, countdown y banner de siguiente actividad.
///
/// Se extrajo a un widget propio para poder reutilizarla tal cual en la **vista
/// previa del programador**: así lo que ve el operador en su pantalla es
/// exactamente lo que se está proyectando, sin duplicar el diseño.
///
/// Gestiona internamente el parpadeo rojo, de modo que el destello se comporta
/// igual en la vista completa y en la miniatura.
class StageView extends ConsumerStatefulWidget {
  const StageView({super.key});

  @override
  ConsumerState<StageView> createState() => _StageViewState();
}

class _StageViewState extends ConsumerState<StageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _alertController;

  /// 0.0 = fondo negro, 1.0 = fondo del color del destello.
  late final Animation<double> _alertPulse;

  /// Recuerda la actividad anterior para cantar el cambio en verde.
  final StageFlashTracker _flash = StageFlashTracker();

  @override
  void initState() {
    super.initState();
    _alertController = AnimationController(
      vsync: this,
      duration: AppConfig.blinkPeriod,
    );
    _alertPulse = _alertController.drive(Tween<double>(begin: 0.0, end: 1.0));
  }

  @override
  void dispose() {
    _alertController.dispose();
    super.dispose();
  }

  /// Sincroniza el parpadeo con el destello. Es idempotente, así que puede
  /// ejecutarse en cada `build` sin efectos duplicados.
  void _syncFlash(Color? flash) {
    if (flash != null && !_alertController.isAnimating) {
      _alertController.value = 1.0;
      _alertController.repeat(reverse: true);
    } else if (flash == null && _alertController.isAnimating) {
      _alertController.stop();
      _alertController.value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(countdownProvider);
    final marquee = snapshot.marquee;
    final hasTimer = snapshot.showClock || snapshot.hasActivities;

    // En modo reloj sin marquesina no hay cuenta que echar: solo la hora, a lo
    // grande, sin cabecera ni parpadeos. Va antes del estado vacío porque el
    // reloj no necesita actividades.
    if (snapshot.showClock && marquee == null) {
      return _StageClock(use24Hour: snapshot.clockUse24Hour);
    }

    // Una actividad detenida a mano **no se anuncia**. El escenario es lo que ve la
    // sala, y a nadie le sirve leer «DETENIDO» en el proyector: se apaga y el
    // operador ya ve el aviso en el panel. Si hay una marquesina al aire, esa sí
    // se sigue viendo.
    if (snapshot.isStopped && marquee == null) {
      return const _StandbyScreen();
    }

    // Sin actividades y sin mensaje no hay nada que proyectar. En espera no se avisa
    // de nada: la pantalla está encendida y a propósito vacía, y un «no hay nada
    // que presentar» en medio de una sala sería un mensaje falso.
    if (!hasTimer && marquee == null) {
      return snapshot.phase == CountdownPhase.idle
          ? const _StandbyScreen()
          : const _NoActivities();
    }

    final flash = _flash.update(snapshot, DateTime.now());
    _syncFlash(flash);

    return Stack(
      children: [
        // Fondo negro + destello a pantalla completa: rojo al excederse, naranja
        // en los últimos segundos y verde al cambiar de actividad.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _alertPulse,
            builder: (context, _) => ColoredBox(
              color: Color.lerp(
                StageColors.black,
                flash ?? StageColors.black,
                _alertPulse.value,
              )!,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: marquee == null
                // Márgenes laterales mínimos: el countdown es lo primero y debe
                // llegar prácticamente a los bordes.
                ? const EdgeInsets.fromLTRB(16, 28, 16, 100)
                // Con marquesina la banda se pega abajo; el reloj se queda
                // arriba, más pequeño.
                : const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Cuando el hueco es pequeño —la vista previa del panel, o una
                // ventana bajita— la cabecera completa no cabe. Antes se comía
                // todo el alto, el reloj se quedaba con cero y los dos huecos
                // de 16 px desbordaban: eso es la banda amarilla que dibuja
                // Flutter al desbordar. En sitio justo se recorta la cabecera y
                // se retira el pie.
                final apretado = constraints.maxHeight < _compactHeight;

                // Entre «hay texto» y «solo reloj» no hay un salto: el texto se
                // desvanece recogiéndose y el reloj entra creciendo. Sin esto el
                // cambio se nota como un fogonazo en mitad del evento.
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: _apilarTransicion,
                  transitionBuilder: (hijo, animacion) => FadeTransition(
                    opacity: animacion,
                    child: ScaleTransition(
                      // 0,94 ↔ 1: el que entra crece y el que sale se recoge con
                      // la misma curva, sin tocar el contenido de ninguno.
                      scale: Tween<double>(
                        begin: 0.94,
                        end: 1,
                      ).animate(animacion),
                      child: hijo,
                    ),
                  ),
                  child: marquee == null
                      ? _StageContent(
                          key: const ValueKey('reloj'),
                          snapshot: snapshot,
                          compact: apretado,
                        )
                      : _WithMarquee(
                          key: ValueKey('marquesina-${marquee.runId}'),
                          snapshot: snapshot,
                          overlay: marquee,
                          compact: apretado,
                        ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Los dos estados —con texto y sin texto— se apilan ocupando todo el hueco
/// durante la transición, para que el reloj entrante caiga justo donde se va a
/// quedar cuando la animación termine.
Widget _apilarTransicion(Widget? actual, List<Widget> anteriores) {
  return Stack(
    fit: StackFit.expand,
    alignment: Alignment.center,
    children: [...anteriores, ?actual],
  );
}

/// La zona del reloj: cabecera + cuenta atrás, o solo la hora actual.
///
/// Se extrajo para poder dibujarla tanto a pantalla completa como encima de la
/// marquesina, donde ocupa menos alto y por eso el reloj se ve más pequeño.
class _StageContent extends StatelessWidget {
  const _StageContent({
    super.key,
    required this.snapshot,
    required this.compact,
  });

  final CountdownSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (snapshot.showClock) {
      return _StageClockBody(use24Hour: snapshot.clockUse24Hour);
    }

    // Sin actividades pero con mensaje: sobre la banda solo queda el negro. Con la
    // actividad detenida, igual: la banda se ve y el reloj no.
    if (!snapshot.hasActivities || snapshot.isStopped) {
      return const SizedBox.shrink();
    }

    // `stretch`: sin esto el `Column` se encoge al ancho de su contenido y, como
    // el padre solo lo alinea a la izquierda, todo el reloj queda descentrado
    // cuando los dígitos no llegan a los bordes (vista previa, ventana bajita).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageHeader(snapshot: snapshot, compact: compact),
        const SizedBox(height: 16),
        Expanded(child: CountdownDisplay(snapshot: snapshot)),
        if (!compact) ...[
          const SizedBox(height: 16),
          NextActivityBanner(snapshot: snapshot),
        ],
      ],
    );
  }
}

/// El reloj encogido arriba y la marquesina cruzando abajo.
///
/// Es el estado que dura mientras hay un mensaje al aire. En cuanto el pase
/// termina (el panel quita el mensaje de la instantánea) se vuelve al
/// [StageView] de siempre y el reloj recupera su tamaño.
class _WithMarquee extends StatelessWidget {
  const _WithMarquee({
    super.key,
    required this.snapshot,
    required this.overlay,
    required this.compact,
  });

  final CountdownSnapshot snapshot;
  final MarqueeOverlay overlay;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final settings = overlay.settings;
        final showTimer = settings.showTimer;
        final bandHeight =
            constraints.maxHeight * marqueeBandFractionFor(settings);
        // El alto de letra se mide sobre la banda, no sobre la pantalla entera:
        // así el texto llena el espacio que se le da, como el reloj.
        final fontSize = bandHeight * settings.fontScale;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Solo texto: la banda se lleva la pantalla entera y no hay reloj. Con la
            // actividad detenida, el reloj tampoco sale: la sala ve la banda y
            // nada más.
            if (showTimer && !snapshot.isStopped) ...[
              Expanded(
                child: _StageContent(
                  snapshot: snapshot,
                  // Protagonista: el reloj se encoge y la cabecera se queda en
                  // lo esencial, que deja sitio al texto. Si no, el reloj se
                  // queda tal cual y el texto pasa por debajo.
                  compact: settings.prominent ? true : compact,
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0x24FFFFFF)),
            ],
            SizedBox(
              height: bandHeight,
              child: MarqueeBand(overlay: overlay, fontSize: fontSize),
            ),
          ],
        );
      },
    );
  }
}

/// La hora actual, a lo grande, para el modo reloj del escenario.
///
/// Sin cabecera, sin parpadeos y sin subtítulos: solo dígitos blancos sobre
/// negro, con la misma tipografía condensada de la cuenta atrás. Late al ritmo
/// de [clockProvider], que en la ventana del escenario corre con su propio
/// temporizador —el modo viaja en la instantánea, los segundos no—.
class _StageClock extends ConsumerWidget {
  const _StageClock({required this.use24Hour});

  /// Formato 12 h o 24 h, según lo elegido en el panel.
  final bool use24Hour;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ColoredBox(
      color: StageColors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(child: _StageClockBody(use24Hour: use24Hour)),
        ),
      ),
    );
  }
}

/// Los dígitos de la hora, sin fondo ni márgenes.
///
/// Se separaron para poder reutilizarlos encima de la marquesina, donde el
/// reloj ocupa menos alto y se ve más pequeño.
class _StageClockBody extends ConsumerWidget {
  const _StageClockBody({required this.use24Hour});

  final bool use24Hour;

  /// Igual que en [CountdownDisplay]: base enorme y `scaleDown` hasta encajar.
  static const double _baseFontSize = 1000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider);
    final text = use24Hour
        ? TimeFormatters.stageClock(now)
        : TimeFormatters.stageClock12(now);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        style: const TextStyle(
          fontFamily: AppConfig.countdownFontFamily,
          fontSize: _baseFontSize,
          height: 1.0,
          fontWeight: FontWeight.w700,
          color: StageColors.white,
          // Los segundos cambian cada tick: sin cifras tabulares el ancho
          // bailaría y el reloj respiraría.
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Cabecera compacta: informa, pero sin robarle sitio al countdown.
///
/// Con [compact] se queda en lo esencial (etiqueta y título) para que quepa en
/// huecos pequeños, como la vista previa del panel.
class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.snapshot, this.compact = false});

  final CountdownSnapshot snapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slot = snapshot.current!;
    final item = slot.item;
    const muted = Color(0x8CFFFFFF);

    return Column(
      children: [
        Text(
          snapshot.isQuickTimer
              ? 'CONTADOR RÁPIDO'
              : snapshot.phase == CountdownPhase.preShow
              ? 'PRÓXIMA ACTIVIDAD'
              : 'ACTIVIDAD ${snapshot.index + 1} DE ${snapshot.total}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: const Color(0x66FFFFFF),
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: StageColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        // En sitio justo esta línea se cae: es informativa para el operador,
        // y el reloj tiene prioridad absoluta sobre ella.
        if (!compact)
          Wrap(
            spacing: 20,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${TimeFormatters.time(slot.startTime)}  ·  '
                '${TimeFormatters.time(slot.endTime)}  ·  '
                '${TimeFormatters.humanDuration(slot.plannedDuration)}',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
              if (item.responsible != null)
                _InlineMeta(
                  icon: Icons.person_outline_rounded,
                  text: item.responsible!,
                ),
              if (item.location != null)
                _InlineMeta(icon: Icons.place_outlined, text: item.location!),
            ],
          ),
      ],
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    const muted = Color(0x8CFFFFFF);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: muted, fontSize: 15)),
      ],
    );
  }
}

/// La pantalla en espera: negro con el icono de la app como marca de agua.
///
/// Negro a secas, un televisor parece apagado —y en directo, apagar el proyector
/// sin querer es un susto que no hace falta—. Con el icono puesto al fondo, a
/// muy poca opacidad, se ve que la pantalla está encendida y esperando.
///
/// El icono va **monocromo**, no el de color: sobre el negro el índigo no
/// contrasta, y el monocromo conserva el parecido porque mantiene la relación de
/// brillo del original (cuadrado tenue, esfera clara, manecillas recortadas). Ver
/// assets/icon/rundown-mark.svg.
///
/// Late despacio, entre el 8 % y el 16 % de opacidad, por dos razones: se ve
/// clarísimo de que está viva sin robarle protagonismo al resto, y una pantalla
/// que pasa horas en negro puro acaba quemando el panel.
class _StandbyScreen extends StatefulWidget {
  const _StandbyScreen();

  @override
  State<_StandbyScreen> createState() => _StandbyScreenState();
}

class _StandbyScreenState extends State<_StandbyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: StageColors.black,
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final lado = (constraints.maxHeight * 0.24).clamp(28.0, 360.0);
              return Opacity(
                opacity: 0.08 + _pulse.value * 0.08,
                child: Image.asset(
                  'assets/icon/rundown-mark.png',
                  width: lado,
                  height: lado,
                  filterQuality: FilterQuality.medium,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NoActivities extends StatelessWidget {
  const _NoActivities();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: StageColors.black,
      child: Center(
        child: Text(
          'Este día no tiene actividades',
          style: TextStyle(
            color: Color(0x99FFFFFF),
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
