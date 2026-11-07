import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../features/events/event_models.dart';
import '../features/events/events_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_parts.dart';
import 'event_detail_screen.dart';
import 'lumai_screen.dart';
import 'profile_screen.dart';

/// Dashboard (Figma 56:1729).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.onOpenMessages,
    required this.onOpenEvents,
    required this.refreshToken,
  });

  final VoidCallback onOpenMessages;
  final VoidCallback onOpenEvents;
  final int refreshToken;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  late Future<List<Event>> _agendaFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _agendaFuture = _loadAgenda();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAgenda();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) _refreshAgenda();
  }

  Future<List<Event>> _loadAgenda() async {
    final events = await EventsRepository.instance.fetchAgendaEvents();
    final upcoming = events
        .where((event) =>
            !event.hasEnded &&
            (event.registration == RegistrationState.confirmed ||
                event.registration == RegistrationState.pendingPayment))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return upcoming.take(6).toList();
  }

  void _refreshAgenda() {
    setState(() => _agendaFuture = _loadAgenda());
  }

  Future<void> _openEvent(Event event) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EventDetailScreen(event: event)),
    );
    if (mounted) _refreshAgenda();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    return Container(
      color: AppColors.backgroundSoft,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 130),
            children: [
              // Header "Hola, Nicolle"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: AppShadows.card),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    child: Avatar(name: s.nombre, size: 36, color: const Color(0xFF6B4F3A), ring: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(TextSpan(
                      style: const TextStyle(fontFamily: AppFonts.title, fontSize: 17, color: AppColors.primary),
                      children: [
                        const TextSpan(text: 'Hola, ', style: TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: s.nombre),
                      ],
                    )),
                  ),
                  const Icon(Icons.notifications_none_rounded, color: AppColors.primary, size: 22),
                ]),
              ),
              const SizedBox(height: 12),
              // Acceso rápido a LumAI
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                elevation: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LumaiScreen())),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: AppShadows.card, color: Colors.white),
                    child: Row(children: [
                      Image.asset(lumaiAvatar, height: 54),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('¿Necesitas orientación?', style: TextStyle(fontFamily: AppFonts.title, fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
                          Text('Habla con LumAI, confidencial y sin juicios', style: TextStyle(fontFamily: AppFonts.ui, fontSize: 11.5, color: AppColors.text)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Agenda',
                onMore: widget.onOpenEvents,
                children: [
                  FutureBuilder<List<Event>>(
                    future: _agendaFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      if (snapshot.hasError) {
                        return Text(
                          'No pudimos cargar la agenda. Vuelve a Inicio para reintentar.',
                          textAlign: TextAlign.center,
                          style: AppText.caption,
                        );
                      }
                      final events = snapshot.data ?? const <Event>[];
                      if (events.isEmpty) {
                        return Text(
                          'Aquí aparecerán tus próximas inscripciones.',
                          textAlign: TextAlign.center,
                          style: AppText.caption,
                        );
                      }
                      return Column(
                        children: [
                          for (final event in events)
                            _AgendaEventTile(event: event, onTap: () => _openEvent(event)),
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Mensaje',
                onMore: widget.onOpenMessages,
                children: [
                  const SearchField(hint: 'Buscar conversación'),
                  const SizedBox(height: 6),
                  for (final c in demoConversations)
                    ConversationTile(name: c.$1, preview: c.$2, time: c.$3, unread: c.$4, color: Color(c.$5), onTap: widget.onOpenMessages),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgendaEventTile extends StatelessWidget {
  const _AgendaEventTile({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (status, color) = switch (event.registration) {
      RegistrationState.confirmed => ('Inscrita', const Color(0xFF3C7A32)),
      RegistrationState.pendingPayment => ('Pago pendiente', const Color(0xFF9A6700)),
      _ => ('No inscrita', AppColors.gray),
    };
    final modalityIcon = event.modality == EventModality.virtual
        ? Icons.videocam_outlined
        : Icons.event_available_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6B4EFF), Color(0xFFB6A9FF)],
                    ),
                  ),
                  child: Icon(modalityIcon, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatEventDateChip(event.startAt)} · ${formatEventTime(event.startAt)} · ${event.venue} · ${event.priceLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 10,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontFamily: AppFonts.ui,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
