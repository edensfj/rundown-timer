import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_formatters.dart';
import '../../models/activity_notice.dart';
import '../../models/scheduled_activity.dart';
import '../../state/schedule_provider.dart';
import '../../state/stage_flash_provider.dart';

/// Tarjeta de una actividad del cronograma.
///
/// El estilo cambia por completo según su estado: pasada (atenuada), en curso
/// (resaltada) o futura (neutra).
///
/// Observa su propio estado con `select`, así que el reloj que se actualiza cada
/// segundo solo reconstruye las tarjetas cuyo estado realmente cambió.
class ActivityCard extends ConsumerWidget {
  const ActivityCard({
    super.key,
    required this.slot,
    required this.onTap,
    required this.onDelete,
    required this.onPreview,
    required this.onRun,
  });

  final ScheduledActivity slot;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Muestra cómo se vería esta actividad en el escenario, sin tocar lo que
  /// está al aire.
  final VoidCallback onPreview;

  /// Pone esta actividad en el escenario y la pone en marcha desde ya.
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      activityStatusProvider.select(
        (map) => map[slot.item.id] ?? ActivityStatus.upcoming,
      ),
    );

    // Solo la tarjeta de la actividad que está al aire recibe el color del
    // destello; las demás se quedan como estén.
    final flash = ref.watch(
      stageFlashProvider.select(
        (state) => state.concerns(slot.item.id) ? state.color : null,
      ),
    );

    return _CardBody(
      slot: slot,
      status: status,
      flash: flash,
      onTap: onTap,
      onDelete: onDelete,
      onPreview: onPreview,
      onRun: onRun,
    );
  }
}

class _CardBody extends StatefulWidget {
  const _CardBody({
    required this.slot,
    required this.status,
    required this.flash,
    required this.onTap,
    required this.onDelete,
    required this.onPreview,
    required this.onRun,
  });

  final ScheduledActivity slot;
  final ActivityStatus status;

  /// Color del aviso del escenario —verde, naranja o rojo— o `null`.
  final Color? flash;

  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPreview;
  final VoidCallback onRun;

  @override
  State<_CardBody> createState() => _CardBodyState();
}

class _CardBodyState extends State<_CardBody> {
  /// En escritorio las acciones se revelan al pasar el ratón: la lista se lee
  /// limpia y el play solo aparece cuando hace falta.
  bool _hovering = false;

  bool get _isPast => widget.status == ActivityStatus.past;
  bool get _isActive => widget.status == ActivityStatus.active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = widget.slot.item;

    // Con destello activo, el borde se pone del mismo color: es lo que identifica
    // la tarjeta de un vistazo sin soltar el brillo del texto.
    final borderColor = widget.flash != null
        ? widget.flash!
        : _isActive
        ? scheme.primary
        : _isPast
        ? scheme.outlineVariant.withValues(alpha: 0.6)
        : scheme.outlineVariant;

    var background = _isActive
        ? Color.lerp(scheme.surface, scheme.primary, 0.10)
        : _isPast
        ? scheme.surface.withValues(alpha: 0.55)
        : scheme.surface;

    // El mismo aviso que está parpadeando en el escenario, aquí teñido y quieto.
    // El tinte va **muy aclarado** contra el fondo de la tarjeta: con el color
    // puro, un rojo o un naranja intense se comían el título y la hora, que es
    // justo lo que el operador necesita leer de la lista.
    final flash = widget.flash;
    if (flash != null) {
      final pale = Color.lerp(flash, scheme.surface, 0.82) ?? flash;
      background = Color.lerp(background, pale, 1) ?? background;
    }

    // La actividad al aire siempre enseña sus acciones: el operador la tiene
    // localizada sin tener que buscarla con el ratón.
    final showActions = _hovering || _isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Card(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: borderColor,
            width: _isActive || widget.flash != null ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            // Las actividades pasadas se atenúan sin desaparecer.
            opacity: _isPast ? 0.55 : 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _TimeColumn(
                    slot: widget.slot,
                    isActive: _isActive,
                    accent: flash,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isActive) ...[
                          _ActiveBadge(color: flash ?? scheme.primary),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          item.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (item.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (item.responsible != null ||
                            item.location != null ||
                            item.notice != null) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 14,
                            runSpacing: 4,
                            children: [
                              if (item.responsible != null)
                                _MetaLine(
                                  icon: Icons.person_outline_rounded,
                                  text: item.responsible!,
                                ),
                              if (item.location != null)
                                _MetaLine(
                                  icon: Icons.place_outlined,
                                  text: item.location!,
                                ),
                              if (item.notice != null)
                                _MetaLine(
                                  icon: Icons.campaign_outlined,
                                  text: _noticeLabel(item.notice!),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: showActions ? 1 : 0,
                    // Ocultas no estorban: el toque en la tarjeta sigue
                    // abriendo el editor en vez de caer en un botón invisible.
                    child: IgnorePointer(
                      ignoring: !showActions,
                      child: _ActionGroup(
                        onRun: widget.onRun,
                        onPreview: widget.onPreview,
                        onDelete: widget.onDelete,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Las tres acciones de la tarjeta, agrupadas.
///
/// Un grupo y no tres botones sueltos: se leen como una sola pieza —«esto es lo
/// que se puede hacer con esta actividad»—, ocupan menos sitio en la tarjeta y
/// no parece que se hayan colado tres controles encima. El de ejecutar va
/// destacado porque es la acción principal; el de eliminar, en rojo, para que
/// nadie lo pulse por error.
class _ActionGroup extends StatelessWidget {
  const _ActionGroup({
    required this.onRun,
    required this.onPreview,
    required this.onDelete,
  });

  final VoidCallback onRun;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GroupButton(
            icon: Icons.play_arrow_rounded,
            tooltip: 'Ejecutar ahora en el escenario',
            color: scheme.primary,
            background: scheme.primary.withValues(alpha: 0.14),
            onPressed: onRun,
          ),
          _GroupDivider(color: scheme.outlineVariant),
          _GroupButton(
            icon: Icons.visibility_outlined,
            tooltip: 'Vista previa en escenario',
            color: scheme.onSurfaceVariant,
            onPressed: onPreview,
          ),
          _GroupDivider(color: scheme.outlineVariant),
          _GroupButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Eliminar actividad',
            color: scheme.error,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Separador de un milímetro entre botones del grupo: la línea es lo que hace
/// que se lean como una pieza y no como tres sueltos.
class _GroupDivider extends StatelessWidget {
  const _GroupDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 22, color: color.withValues(alpha: 0.7));
  }
}

/// Un botón del grupo: icono y nada más. El relleno de fondo es opcional, para
/// destacar el que manda.
class _GroupButton extends StatelessWidget {
  const _GroupButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
    this.background,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final Color? background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background ?? Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: color.withValues(alpha: 0.12),
          child: SizedBox(
            width: 42,
            height: 40,
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({required this.slot, required this.isActive, this.accent});

  final ScheduledActivity slot;
  final bool isActive;

  /// Color del aviso del escenario, si lo hay: la hora se pone del mismo color
  /// que el borde para que la tarjeta se lea entera como un bloque.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: 82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            TimeFormatters.time(slot.startTime),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isActive ? (accent ?? scheme.primary) : scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            TimeFormatters.humanDuration(slot.plannedDuration),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Cómo se resume el aviso en la tarjeta: cuándo sale y cuánto se queda.
String _noticeLabel(ActivityNotice notice) {
  final cuando = notice.trigger == NoticeTrigger.onStart
      ? 'al empezar'
      : 'al terminar';
  final cuanto = notice.limit == NoticeLimit.repeats
      ? '${notice.repeats} ${notice.repeats == 1 ? 'vez' : 'veces'}'
      : TimeFormatters.humanDuration(notice.duration);
  return 'Aviso $cuando · $cuanto';
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'EN CURSO',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontSize: 10,
        ),
      ),
    );
  }
}
