import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/events/event_models.dart';
import '../features/events/event_share.dart';
import '../features/events/events_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/event_card.dart';
import '../widgets/event_date_picker.dart';
import '../widgets/event_ui.dart';
import 'event_detail_screen.dart';

/// Pantalla principal del módulo Edúcate → Eventos.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late final EventsController _controller;
  final _search = TextEditingController();
  bool _latestExpanded = true;
  bool _nearbyExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = EventsController();
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Future<void> _openDateFilter() async {
    final selection = await showEventDatePicker(context, initialDate: _controller.day);
    if (!mounted || selection == null) return;
    _controller.setDay(selection.date);
  }

  Future<void> _openDetail(Event event) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventDetailScreen(event: event),
      ),
    );
    if (!mounted) return;
    await _controller.refresh();
  }

  Future<void> _toggleFavorite(Event event) async {
    final ok = await _controller.toggleFavorite(event);
    if (!ok && mounted) {
      _snack('No pudimos actualizar tus favoritos. Revisa tu conexión.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  void _clearFilters() {
    _search.clear();
    _controller.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundSoft,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final latest = _controller.latest;
            final nearby = _controller.nearby;
            final initialLoading = _controller.loading && _controller.events.isEmpty;
            final hasErrorWithoutData = _controller.error != null && _controller.events.isEmpty;

            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: Colors.white,
              onRefresh: _controller.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 130),
                children: [
                  _buildHeader(context),
                  _buildSearch(context),
                  if (_controller.day != null) _buildDateChip(),
                  if (_controller.error != null && _controller.events.isNotEmpty)
                    _buildInlineError(),
                  if (_controller.loading && _controller.events.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(99)),
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          color: AppColors.primary,
                          backgroundColor: AppColors.primarySoft,
                        ),
                      ),
                    ),
                  if (initialLoading)
                    const _LoadingBlock()
                  else if (hasErrorWithoutData)
                    EventEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'No pudimos cargar los eventos',
                      message: _controller.error!,
                      actionLabel: 'Reintentar',
                      onAction: _controller.retry,
                    )
                  else if (_controller.events.isEmpty)
                    EventEmptyState(
                      icon: Icons.event_busy_rounded,
                      title: 'No hay eventos disponibles',
                      message: 'Cuando se publiquen nuevos eventos aparecerán aquí automáticamente.',
                      actionLabel: 'Actualizar',
                      onAction: _controller.retry,
                    )
                  else if (latest.isEmpty)
                    EventEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No encontramos eventos',
                      message: 'Prueba con otro nombre, lugar o fecha.',
                      actionLabel: 'Limpiar filtros',
                      onAction: _clearFilters,
                    )
                  else ...[
                    _buildLatest(context, latest),
                    _buildNearby(context, nearby),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          EventCircleButton(
            icon: Icons.arrow_back_rounded,
            onPressed: _goBack,
            tooltip: 'Regresar',
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edúcate',
                  style: AppText.h1.copyWith(fontSize: 28, color: AppColors.primaryDark),
                ),
                Text('Eventos para ti', style: AppText.caption.copyWith(fontSize: 12)),
              ],
            ),
          ),
          const EventPill(label: 'Eventos', icon: Icons.event_available_rounded),
        ],
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: eventCardShadow,
              ),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: _controller.setSearch,
                style: AppText.body.copyWith(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o lugar',
                  hintStyle: AppText.body.copyWith(color: AppColors.gray, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 21),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            _controller.setSearch('');
                          },
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.gray),
                          tooltip: 'Limpiar búsqueda',
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _CalendarButton(active: _controller.day != null, onTap: _openDateFilter),
        ],
      ),
    );
  }

  Widget _buildDateChip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          label: Text(formatEventDateChip(_controller.day!)),
          avatar: const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.primaryDark),
          onDeleted: () => _controller.setDay(null),
          deleteIcon: const Icon(Icons.close_rounded, size: 16, color: AppColors.primaryDark),
          backgroundColor: AppColors.primarySoft,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
          labelStyle: const TextStyle(
            fontFamily: AppFonts.ui,
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: AppColors.primaryDark,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildInlineError() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No pudimos actualizar. Mostramos la última información disponible.',
              style: AppText.caption.copyWith(color: AppColors.primaryDark),
            ),
          ),
          TextButton(
            onPressed: _controller.retry,
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

  Widget _buildLatest(BuildContext context, List<Event> latest) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = math.min(screenWidth * 0.84, 330.0);
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.35).toDouble();
    final cardHeight = 366.0 * textScale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EventSectionHeader(
          title: 'Últimos eventos',
          subtitle: 'Recién publicados',
          actionLabel: _latestExpanded ? 'Ver menos' : 'Ver todo',
          actionIcon: _latestExpanded ? Icons.expand_less_rounded : Icons.arrow_forward_rounded,
          onAction: () => setState(() => _latestExpanded = !_latestExpanded),
        ),
        if (_latestExpanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final event in latest)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _card(event),
                  ),
              ],
            ),
          )
        else
          SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: latest.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _card(
                latest[index],
                width: cardWidth,
                height: cardHeight,
                compact: true,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNearby(BuildContext context, List<Event> nearby) {
    final visible = _nearbyExpanded ? nearby : nearby.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EventSectionHeader(
          title: 'Eventos cerca de ti',
          subtitle: _controller.hasPosition ? 'A menos de 25 km' : 'Ordenados por fecha',
          actionLabel: _nearbyExpanded ? 'Ver menos' : 'Ver todo',
          actionIcon: _nearbyExpanded ? Icons.expand_less_rounded : Icons.arrow_forward_rounded,
          onAction: nearby.isEmpty ? null : () => setState(() => _nearbyExpanded = !_nearbyExpanded),
        ),
        if (!_controller.hasPosition && _controller.locationNotice != null)
          _LocationNotice(
            message: _controller.locationNotice!,
            actionLabel: _controller.locationServiceDisabled || _controller.locationPermanentlyDenied ? 'Ajustes' : 'Activar',
            onEnable: _controller.enableLocation,
          ),
        if (nearby.isEmpty)
          const _SectionEmpty(
            icon: Icons.location_on_outlined,
            message: 'No hay eventos presenciales cerca de tu ubicación en este momento.',
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final event in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _card(
                      event,
                      distanceLabel: _distanceLabel(event),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String? _distanceLabel(Event event) {
    final distance = _controller.distanceFor(event);
    return distance == null ? null : formatEventDistance(distance);
  }

  Widget _card(
    Event event, {
    double? width,
    double? height,
    String? distanceLabel,
    bool compact = false,
  }) {
    return EventCard(
      event: event,
      width: width,
      height: height,
      distanceLabel: distanceLabel,
      compact: compact,
      onTap: () => _openDetail(event),
      onToggleFavorite: () => _toggleFavorite(event),
      onShare: () => showEventShareSheet(context, event),
    );
  }
}

class _CalendarButton extends StatelessWidget {
  const _CalendarButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Filtrar por fecha',
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: eventCardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Icon(
              Icons.calendar_month_rounded,
              color: active ? Colors.white : AppColors.primary,
              size: 23,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationNotice extends StatelessWidget {
  const _LocationNotice({required this.message, required this.actionLabel, required this.onEnable});

  final String message;
  final String actionLabel;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppText.caption.copyWith(color: AppColors.primaryDark, height: 1.35),
            ),
          ),
          TextButton(
            onPressed: onEnable,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: eventCardShadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: AppText.caption.copyWith(height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.4),
          SizedBox(height: 14),
          Text('Cargando eventos…', style: AppText.caption),
        ],
      ),
    );
  }
}
