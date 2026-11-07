import 'package:flutter/material.dart';

import '../features/events/event_models.dart';
import '../features/events/events_repository.dart';
import '../theme/app_theme.dart';
import 'avatar.dart';

/// Hoja inferior con la lista de asistentes (solo primer nombre por privacidad).
class EventAttendeesSheet extends StatefulWidget {
  const EventAttendeesSheet({
    super.key,
    required this.eventId,
    required this.count,
  });

  final String eventId;
  final int count;

  @override
  State<EventAttendeesSheet> createState() => _EventAttendeesSheetState();
}

class _EventAttendeesSheetState extends State<EventAttendeesSheet> {
  late Future<List<EventAttendee>> _future;

  @override
  void initState() {
    super.initState();
    _future = EventsRepository.instance.fetchAttendees(widget.eventId);
  }

  void _retry() {
    setState(() {
      _future = EventsRepository.instance.fetchAttendees(widget.eventId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(color: AppColors.grayLight, borderRadius: BorderRadius.circular(99)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Asistentes', style: AppText.h2.copyWith(fontSize: 20)),
                        Text(
                          widget.count == 1 ? '1 persona inscrita' : '${widget.count} personas inscritas',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.gray),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: FutureBuilder<List<EventAttendee>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.4),
                    );
                  }
                  if (snapshot.hasError) {
                    return _AttendeesMessage(
                      icon: Icons.wifi_off_rounded,
                      title: 'No pudimos cargar la lista',
                      message: 'Revisa tu conexión e inténtalo de nuevo.',
                      actionLabel: 'Reintentar',
                      onAction: _retry,
                    );
                  }

                  final attendees = snapshot.data ?? const <EventAttendee>[];
                  if (attendees.isEmpty) {
                    return const _AttendeesMessage(
                      icon: Icons.people_outline_rounded,
                      title: 'Aún no hay personas inscritas',
                      message: '¡Anímate a ser la primera en asistir!',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    itemCount: attendees.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final attendee = attendees[index];
                      return Row(
                        children: [
                          Avatar(name: attendee.name, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(attendee.name, style: AppText.bodyStrong),
                                Text('Inscripción confirmada', style: AppText.caption),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.gray),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Solo mostramos el primer nombre de cada persona por privacidad.',
                      style: AppText.caption.copyWith(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendeesMessage extends StatelessWidget {
  const _AttendeesMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: AppText.h3),
            const SizedBox(height: 4),
            Text(message, textAlign: TextAlign.center, style: AppText.caption),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
