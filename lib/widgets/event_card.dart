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
    final imageHeight = compact ? 142.0 : 168.0;
    final status = event.hasEnded
        ? 'Finalizado'
        : event.isSoldOut
            ? 'Cupos agotados'
            : null;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: height == null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: EventPill(label: event.category),
                ),
              ),
              const SizedBox(width: 8),
              EventPill(
                label: event.priceLabel,
                background: event.isFree ? const Color(0xFFE6F6DE) : AppColors.primarySoft,
                foreground: event.isFree ? const Color(0xFF3C7A32) : AppColors.primaryDark,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.h3.copyWith(fontSize: 16.5, height: 1.28),
          ),
          const SizedBox(height: 8),
          _CardLine(
            icon: Icons.calendar_today_rounded,
            text: '${formatEventDay(event.startAt)} · ${formatEventRange(event)}',
          ),
          const SizedBox(height: 5),
          _CardLine(
            icon: event.modality == EventModality.virtual ? Icons.videocam_outlined : Icons.place_outlined,
            text: event.venue,
            trailing: distanceLabel,
          ),
          if (height != null && height! > 0) const Spacer() else const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.people_alt_outlined, size: 15, color: AppColors.gray),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${event.attendees} ${event.attendees == 1 ? 'inscrita' : 'inscritas'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.primary),
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
                    Positioned(top: 10, left: 10, child: _DateBadge(date: event.startAt)),
                    Positioned(
                      top: 9,
                      right: 9,
                      child: Row(
                        children: [
                          EventCircleButton(
                            icon: event.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            foreground: event.isFavorite ? AppColors.primary : AppColors.text,
                            background: Colors.white.withValues(alpha: 0.95),
                            size: 34,
                            tooltip: event.isFavorite ? 'Quitar de favoritos' : 'Guardar en favoritos',
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
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          EventPill(
                            label: event.modalityLabel,
                            icon: event.modality == EventModality.virtual ? Icons.videocam_outlined : Icons.groups_2_outlined,
                            background: Colors.white.withValues(alpha: 0.93),
                            foreground: AppColors.primaryDark,
                          ),
                          if (status != null)
                            EventPill(
                              label: status,
                              background: event.hasEnded ? const Color(0xFF6B7280) : const Color(0xFFC2410C),
                              foreground: Colors.white,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (height != null && height! > 0) Expanded(child: content) else content,
            ],
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
        boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 10, offset: Offset(0, 3))],
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
            style: AppText.caption.copyWith(color: AppColors.text.withValues(alpha: 0.78)),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Text(
            trailing!,
            style: AppText.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}
