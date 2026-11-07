import 'package:flutter/material.dart';

import '../features/events/event_models.dart';
import '../features/events/event_share.dart';
import '../features/events/events_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/event_attendees_sheet.dart';
import '../widgets/event_checkout_sheet.dart';
import '../widgets/event_ui.dart';

/// Detalle de un evento + inscripción / compra preparada.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.event});

  final Event event;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Event _event;
  bool _refreshing = true;
  bool _registering = false;
  bool _favoriteBusy = false;
  bool _descExpanded = false;
  bool _notFound = false;
  String? _refreshError;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _refresh(silent: true);
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _refreshing = true;
        _refreshError = null;
      });
    }
    try {
      final updated = await EventsRepository.instance.fetchEvent(_event.id);
      if (!mounted) return;
      if (updated == null) {
        setState(() {
          _notFound = true;
          _refreshing = false;
        });
        return;
      }
      setState(() {
        _event = updated;
        _refreshing = false;
        _refreshError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _refreshError = 'No pudimos actualizar la información del evento.';
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy) return;
    final wanted = !_event.isFavorite;
    setState(() {
      _favoriteBusy = true;
      _event = _event.copyWith(isFavorite: wanted);
    });

    try {
      await EventsRepository.instance.setFavorite(_event.id, wanted);
    } catch (_) {
      if (!mounted) return;
      setState(() => _event = _event.copyWith(isFavorite: !wanted));
      _snack('No pudimos actualizar tus favoritos.');
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  void _openAttendees() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          EventAttendeesSheet(eventId: _event.id, count: _event.attendees),
    );
  }

  Future<void> _register() async {
    final cta = _event.cta;
    if (cta == EventCta.paid || cta == EventCta.pendingPayment) {
      await showEventCheckoutSheet(context, _event);
      if (mounted) await _refresh(silent: true);
      return;
    }
    if (cta != EventCta.free) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar inscripción'),
        content: Text('¿Quieres inscribirte en "${_event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Inscribirme'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _registering = true);
    RegistrationResult result;
    try {
      result = await EventsRepository.instance.registerFree(_event.id);
    } catch (_) {
      if (mounted) {
        setState(() => _registering = false);
        _snack(
          'No pudimos completar tu inscripción. Revisa tu conexión e inténtalo de nuevo.',
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _registering = false);

    if (result.outcome == RegistrationOutcome.confirmed) {
      setState(() {
        _event = _event.copyWith(
          registration: RegistrationState.confirmed,
          attendees: _event.attendees + 1,
        );
      });
      await _refresh(silent: true);
    } else if (result.outcome == RegistrationOutcome.alreadyRegistered ||
        result.outcome == RegistrationOutcome.soldOut ||
        result.outcome == RegistrationOutcome.ended ||
        result.outcome == RegistrationOutcome.unavailable) {
      await _refresh(silent: true);
    }
    if (!mounted) return;

    if (result.outcome == RegistrationOutcome.requiresPayment) {
      await _refresh(silent: true);
      if (!mounted || _notFound) return;
      await showEventCheckoutSheet(context, _event);
      return;
    }

    final message = switch (result.outcome) {
      RegistrationOutcome.confirmed =>
        '¡Listo! Ya estás inscrita en ${_event.title}.',
      RegistrationOutcome.alreadyRegistered =>
        'Ya estás inscrita en este evento.',
      RegistrationOutcome.soldOut => 'Lo sentimos, los cupos se agotaron.',
      RegistrationOutcome.ended => 'El evento ya finalizó.',
      RegistrationOutcome.requiresPayment => 'Este evento requiere pago.',
      RegistrationOutcome.unavailable => 'El evento ya no está disponible.',
      RegistrationOutcome.notAuthenticated => 'Inicia sesión para inscribirte.',
      RegistrationOutcome.error =>
        result.message ??
            'No pudimos completar tu inscripción. Inténtalo de nuevo.',
    };
    _snack(message);
  }

  void _snack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_notFound) {
      return Scaffold(
        backgroundColor: AppColors.backgroundSoft,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundSoft,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text('Evento', style: AppText.h3),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.event_busy_rounded,
                  size: 52,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Este evento ya no está disponible',
                  textAlign: TextAlign.center,
                  style: AppText.h2,
                ),
                const SizedBox(height: 6),
                Text(
                  'Puede que haya sido cancelado o que ya no esté publicado.',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: Colors.white,
            onRefresh: () => _refresh(silent: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                _buildHero(),
                if (_refreshError != null) _buildRefreshBanner(),
                _buildContent(context),
                SizedBox(height: 150 + bottomInset),
              ],
            ),
          ),
          _buildTopBar(context),
          if (_refreshing)
            Positioned(
              top: MediaQuery.paddingOf(context).top,
              left: 0,
              right: 0,
              child: const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primary,
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildHero() {
    const radius = BorderRadius.vertical(bottom: Radius.circular(28));
    return Stack(
      children: [
        EventImage(
          imageUrl: _event.imageUrl,
          height: 300,
          borderRadius: radius,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.34),
                    Colors.transparent,
                    Colors.transparent,
                  ],
                  stops: const [0, 0.36, 1],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 16,
      right: 16,
      child: Row(
        children: [
          EventCircleButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Regresar',
          ),
          const Spacer(),
          EventCircleButton(
            icon: _event.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            foreground: _event.isFavorite ? AppColors.primary : AppColors.text,
            onPressed: _toggleFavorite,
            tooltip: _event.isFavorite
                ? 'Quitar de favoritos'
                : 'Guardar en favoritos',
          ),
          const SizedBox(width: 10),
          EventCircleButton(
            icon: Icons.ios_share_rounded,
            onPressed: () => showEventShareSheet(context, _event),
            tooltip: 'Compartir evento',
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _refreshError!,
              style: AppText.caption.copyWith(color: AppColors.primaryDark),
            ),
          ),
          TextButton(
            onPressed: _refresh,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final priceColor = _event.isFree
        ? const Color(0xFF3C7A32)
        : AppColors.primaryDark;
    final descriptionOverflows = _descriptionOverflows(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              EventPill(label: _event.category, icon: Icons.sell_outlined),
              EventPill(
                label: _event.modalityLabel,
                icon: _event.modality == EventModality.virtual
                    ? Icons.videocam_outlined
                    : Icons.groups_2_outlined,
                background: Colors.white,
                foreground: AppColors.primaryDark,
                borderColor: AppColors.border,
              ),
              if (_event.hasEnded)
                const EventPill(
                  label: 'Finalizado',
                  background: Color(0xFF6B7280),
                  foreground: Colors.white,
                )
              else if (_event.isSoldOut)
                const EventPill(
                  label: 'Cupos agotados',
                  background: Color(0xFFC2410C),
                  foreground: Colors.white,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _event.title,
            style: AppText.h1.copyWith(fontSize: 26, height: 1.2),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Avatar(name: _event.organizer, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Organiza ${_event.organizer}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: eventCardShadow,
            ),
            child: Column(
              children: [
                EventInfoRow(
                  icon: Icons.calendar_today_rounded,
                  title: 'Fecha',
                  value: formatEventDateLong(_event.startAt),
                ),
                const Divider(height: 22, color: AppColors.border),
                EventInfoRow(
                  icon: Icons.schedule_rounded,
                  title: 'Horario',
                  value: formatEventRange(_event),
                ),
                const Divider(height: 22, color: AppColors.border),
                EventInfoRow(
                  icon: Icons.place_outlined,
                  title: 'Lugar',
                  value: _event.venue,
                  subtitle: _event.address,
                ),
                const Divider(height: 22, color: AppColors.border),
                EventInfoRow(
                  icon: _event.modality == EventModality.virtual
                      ? Icons.videocam_outlined
                      : Icons.groups_2_outlined,
                  title: 'Modalidad',
                  value: _event.modalityLabel,
                  subtitle: _event.modality == EventModality.virtual
                      ? 'Recibirás el enlace al inscribirte'
                      : 'Evento presencial',
                ),
                const Divider(height: 22, color: AppColors.border),
                EventInfoRow(
                  icon: Icons.confirmation_number_outlined,
                  title: 'Entrada',
                  value: _event.priceLabel,
                  valueColor: priceColor,
                ),
                const Divider(height: 22, color: AppColors.border),
                EventInfoRow(
                  icon: Icons.groups_2_outlined,
                  title: 'Cupos disponibles',
                  value: _event.isSoldOut
                      ? 'Sin cupos disponibles'
                      : '${_event.spotsLeft} de ${_event.capacity}',
                  subtitle:
                      '${_event.attendees} ${_event.attendees == 1 ? 'persona inscrita' : 'personas inscritas'}',
                  valueColor: _event.isSoldOut ? const Color(0xFFC2410C) : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: eventCardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.people_alt_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_event.attendeesLabel, style: AppText.bodyStrong),
                      Text(
                        _event.isSoldOut
                            ? 'Cupos agotados'
                            : '${_event.spotsLeft} ${_event.spotsLeft == 1 ? 'cupo disponible' : 'cupos disponibles'}',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: _openAttendees, child: const Text('Ver')),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Sobre el evento', style: AppText.h2.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: Text(
              _event.description.isEmpty
                  ? 'Sin descripción disponible.'
                  : _event.description,
              maxLines: _descExpanded ? null : 4,
              overflow: _descExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: AppText.body.copyWith(
                height: 1.55,
                color: AppColors.text.withValues(alpha: 0.85),
              ),
            ),
          ),
          if (descriptionOverflows || _descExpanded)
            TextButton(
              onPressed: () => setState(() => _descExpanded = !_descExpanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.primary,
              ),
              child: Text(_descExpanded ? 'Ver menos' : 'Ver más'),
            ),
          const SizedBox(height: 18),
          Text('Organiza', style: AppText.h2.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: eventCardShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OrganizerAvatar(event: _event),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_event.organizer, style: AppText.bodyStrong),
                      if (_event.organizerBio != null)
                        Text(
                          _event.organizerBio!,
                          style: AppText.caption.copyWith(height: 1.4),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _descriptionOverflows(BuildContext context) {
    final text = _event.description.isEmpty
        ? 'Sin descripción disponible.'
        : _event.description;
    final style = AppText.body.copyWith(
      height: 1.55,
      color: AppColors.text.withValues(alpha: 0.85),
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 4,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: MediaQuery.sizeOf(context).width - 40);
    final exceeds = painter.didExceedMaxLines;
    painter.dispose();
    return exceeds;
  }

  Widget _buildBottomBar(BuildContext context) {
    final cta = _event.cta;
    final canAct =
        cta == EventCta.free ||
        cta == EventCta.paid ||
        cta == EventCta.pendingPayment;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_event.isFree)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text('Total', style: AppText.caption.copyWith(fontSize: 12)),
                  const Spacer(),
                  Text(
                    _event.priceLabel,
                    style: AppText.h3.copyWith(
                      color: AppColors.primary,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: canAct && !_registering ? _register : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _registering
                    ? AppColors.primary
                    : AppColors.grayLight,
                disabledForegroundColor: _registering
                    ? Colors.white
                    : AppColors.gray,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: AppText.button.copyWith(fontSize: 15),
              ),
              child: _registering
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_ctaIcon(cta), size: 19),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _event.ctaLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (cta == EventCta.paid || cta == EventCta.pendingPayment)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Tu inscripción se confirma al completar el pago con Yape o Plin.',
                style: AppText.caption.copyWith(fontSize: 10.5),
              ),
            ),
        ],
      ),
    );
  }

  IconData _ctaIcon(EventCta cta) => switch (cta) {
    EventCta.free => Icons.how_to_reg_rounded,
    EventCta.paid => Icons.shopping_bag_outlined,
    EventCta.pendingPayment => Icons.credit_card_rounded,
    EventCta.soldOut => Icons.event_busy_rounded,
    EventCta.registered => Icons.check_circle_rounded,
    EventCta.ended => Icons.flag_rounded,
    EventCta.unavailable => Icons.block_rounded,
  };
}

class _OrganizerAvatar extends StatelessWidget {
  const _OrganizerAvatar({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final url = event.organizerAvatarUrl;
    if (url == null || url.trim().isEmpty) {
      return Avatar(name: event.organizer, size: 48);
    }
    return ClipOval(
      child: Image.network(
        url,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        cacheWidth: 120,
        errorBuilder: (_, _, _) => Avatar(name: event.organizer, size: 48),
      ),
    );
  }
}
