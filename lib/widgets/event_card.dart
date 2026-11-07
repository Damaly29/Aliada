import 'package:flutter/material.dart';

import '../features/events/event_models.dart';
import '../theme/app_theme.dart';
import 'event_ui.dart';

/// Tarjeta reutilizable de evento para el carrusel y para el listado vertical.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onShare,
    this.width,
    this.height,
    this.distanceLabel,
    this.compact = false,
  });

  final Event event;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onShare;
  final double? width;
  final double? height;
  final String? distanceLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final imageHeight = compact ? 142.0 : 162.0;
    final status = event.hasEnded
        ? 'Finalizado'
        : event.isSoldOut
        ? 'Cupos agotados'
        : null;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: height == null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Text(
            event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyStrong.copyWith(fontSize: 13, height: 1.2),
          ),
          const SizedBox(height: 5),
          Text(
            '${formatEventDay(event.startAt)} · ${formatEventRange(event)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(
              color: AppColors.primaryDark,
              fontSize: 10.5,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 5),
          _CardLine(
            icon: Icons.place_outlined,
            text: event.venue,
            trailing: distanceLabel,
          ),
          if (height != null && height! > 0)
            const Spacer()
          else
            const SizedBox(height: 8),
          Row(
            children: [
              EventPill(
                label: event.modalityLabel,
                background: const Color(0xFFF0F0F2),
                foreground: AppColors.text,
              ),
              const SizedBox(width: 6),
              EventPill(
                label: event.priceLabel,
                background: const Color(0xFFF0F0F2),
                foreground: AppColors.text,
              ),
              const Spacer(),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(eventCardRadius),
        boxShadow: eventCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(eventCardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: height == null ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: imageHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EventImage(imageUrl: event.imageUrl, height: imageHeight),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.30),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.18),
                          ],
                          stops: const [0, 0.55, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _DateBadge(date: event.startAt),
                    ),
                    Positioned(
                      top: 9,
                      right: 9,
                      child: Row(
                        children: [
                          EventCircleButton(
                            icon: event.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            foreground: event.isFavorite
                                ? AppColors.primary
                                : AppColors.text,
                            background: Colors.white.withValues(alpha: 0.95),
                            size: 34,
                            tooltip: event.isFavorite
                                ? 'Quitar de favoritos'
                                : 'Guardar en favoritos',
                            onPressed: onToggleFavorite,
                          ),
                          const SizedBox(width: 6),
                          EventCircleButton(
                            icon: Icons.ios_share_rounded,
                            background: Colors.white.withValues(alpha: 0.95),
                            size: 34,
                            tooltip: 'Compartir evento',
                            onPressed: onShare,
                          ),
                        ],
                      ),
                    ),
                    if (status != null)
                      Positioned(
                        left: 12,
                        bottom: 10,
                        child: EventPill(
                          label: status,
                          background: event.hasEnded
                              ? const Color(0xFF6B7280)
                              : const Color(0xFFC2410C),
                          foreground: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              if (height != null && height! > 0)
                Expanded(child: content)
              else
                content,
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta compacta para los eventos en la lista vertical de cercanos.
class EventListRowCard extends StatelessWidget {
  const EventListRowCard({
    super.key,
    required this.event,
    required this.onTap,
    this.distanceLabel,
  });

  final Event event;
  final VoidCallback onTap;
  final String? distanceLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: eventCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: EventImage(
                    imageUrl: event.imageUrl,
                    width: 76,
                    height: 76,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong.copyWith(
                          fontSize: 11.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${formatEventDay(event.startAt)} · ${formatEventRange(event)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(fontSize: 9.5),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 12,
                            color: AppColors.gray,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              distanceLabel == null
                                  ? event.venue
                                  : '${event.venue} · $distanceLabel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption.copyWith(fontSize: 9.5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          EventPill(
                            label: event.priceLabel,
                            background: const Color(0xFFF0F0F2),
                            foreground: AppColors.text,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${date.day}',
            style: const TextStyle(
              fontFamily: AppFonts.title,
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AppColors.primary,
              height: 1,
            ),
          ),
          Text(
            formatEventMonthShort(date),
            style: const TextStyle(
              fontFamily: AppFonts.ui,
              fontWeight: FontWeight.w600,
              fontSize: 9.5,
              color: AppColors.gray,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardLine extends StatelessWidget {
  const _CardLine({required this.icon, required this.text, this.trailing});

  final IconData icon;
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.gray),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(
              color: AppColors.text.withValues(alpha: 0.78),
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Text(
            trailing!,
            style: AppText.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
