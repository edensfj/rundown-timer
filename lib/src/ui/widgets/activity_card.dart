import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_formatters.dart';
import '../../models/scheduled_activity.dart';
import '../../state/schedule_provider.dart';

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
  });

  final ScheduledActivity slot;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// Muestra cómo se vería esta actividad en el escenario, sin tocar lo que
  /// está al aire.
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      activityStatusProvider.select(
        (map) => map[slot.item.id] ?? ActivityStatus.upcoming,
      ),
    );

    return _CardBody(
      slot: slot,
      status: status,
      onTap: onTap,
      onDelete: onDelete,
      onPreview: onPreview,
    );
  }
}

class _CardBody extends StatefulWidget {
  const _CardBody({
    required this.slot,
    required this.status,
    required this.onTap,
    required this.onDelete,
    required this.onPreview,
  });

  final ScheduledActivity slot;
  final ActivityStatus status;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPreview;

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

    final borderColor = _isActive
        ? scheme.primary
        : _isPast
        ? scheme.outlineVariant.withValues(alpha: 0.6)
        : scheme.outlineVariant;

    final background = _isActive
        ? Color.lerp(scheme.surface, scheme.primary, 0.10)
        : _isPast
        ? scheme.surface.withValues(alpha: 0.55)
        : scheme.surface;

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
          side: BorderSide(color: borderColor, width: _isActive ? 2 : 1),
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
                  _TimeColumn(slot: widget.slot, isActive: _isActive),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isActive) ...[
                          _ActiveBadge(color: scheme.primary),
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
                            item.location != null) ...[
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filledTonal(
                            onPressed: widget.onPreview,
                            tooltip: 'Vista previa en escenario',
                            icon: const Icon(Icons.play_arrow_rounded),
                          ),
                          IconButton(
                            onPressed: widget.onDelete,
                            tooltip: 'Eliminar actividad',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                            ),
                            color: scheme.error,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
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

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({required this.slot, required this.isActive});

  final ScheduledActivity slot;
  final bool isActive;

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
              color: isActive ? scheme.primary : scheme.onSurface,
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
