import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/cloud.dart';
import '../core/geo.dart';
import '../core/precise_location.dart';
import '../features/alert/alert_controller.dart';
import '../features/alert/models.dart';
import '../features/incoming/incoming_alerts.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/live_map.dart';
import '../widgets/measure_size.dart';
import '../widgets/mixed_title.dart';

enum _Stage { incoming, enCamino, llego, cerrada }

/// Vista de la aliada: alerta cercana → "Voy en camino" / "No puedo" → navegación hasta llegar.
/// Con [incoming] es una alerta REAL de otro teléfono; sin él, es la simulación demo.
class ResponderScreen extends StatefulWidget {
  const ResponderScreen({super.key, this.incoming});
  final IncomingAlert? incoming;
  @override
  State<ResponderScreen> createState() => _ResponderScreenState();
}

class _ResponderScreenState extends State<ResponderScreen> {
  IncomingAlert? get _a => widget.incoming;
  late LatLng _victim = _a?.position.value ?? offsetFrom(fallbackPosition, 450, 60);
  LatLng _myPos = IncomingAlertService.instance.lastPosition ?? fallbackPosition;
  _Stage _stage = _Stage.incoming;
  Timer? _tick;
  StreamSubscription<Position>? _gps;
  RealtimeChannel? _chat;
  String? _lastMsg;
  bool _busy = false;
  double _cardH = 280;
  final _filter = LocationFilter();

  bool get _real => _a != null;
  String get _name => _a == null ? 'María' : firstName(_a!.nombre);
  double get _dist => metersBetween(_myPos, _victim);

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    final a = _a;
    if (a != null) {
      a.position.addListener(_onVictimMoved);
      a.status.addListener(_onStatus);
      _startGps();
    }
  }

  void _onVictimMoved() => setState(() => _victim = _a!.position.value);

  void _onStatus() {
    if (_a!.status.value != 'active' && mounted) {
      _tick?.cancel();
      setState(() => _stage = _Stage.cerrada);
    }
  }

  Future<void> _startGps() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, timeLimit: Duration(seconds: 8)),
      );
      if (mounted && _filter.add(p)) setState(() => _myPos = _filter.position!);
      _gps = Geolocator.getPositionStream(locationSettings: preciseSettings()).listen((p) {
        if (!mounted || !_filter.add(p)) return;
        setState(() => _myPos = _filter.position!);
      }, onError: (_) {});
    } catch (_) {}
  }

  Future<void> _accept() async {
    HapticFeedback.mediumImpact();
    if (_real) {
      setState(() => _busy = true);
      final ok = await IncomingAlertService.instance.accept(_a!, _myPos);
      if (!mounted) return;
      setState(() => _busy = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo aceptar. Revisa tu conexión.')));
        return;
      }
      setState(() => _stage = _Stage.enCamino);
      _listenChat();
      _tick = Timer.periodic(const Duration(seconds: 4), (_) {
        IncomingAlertService.instance.pushLocation(_a!, _myPos);
        if (_dist <= 30 && _stage == _Stage.enCamino) {
          HapticFeedback.heavyImpact();
          setState(() => _stage = _Stage.llego);
        }
      });
      return;
    }
    // Simulación demo
    setState(() => _stage = _Stage.enCamino);
    _tick = Timer.periodic(const Duration(seconds: 2), (_) {
      setState(() {
        if (_dist <= 50) {
          _myPos = offsetFrom(_victim, 10, bearingBetween(_victim, _myPos));
          _stage = _Stage.llego;
          _tick?.cancel();
          HapticFeedback.heavyImpact();
        } else {
          _myPos = offsetFrom(_myPos, 24, bearingBetween(_myPos, _victim));
        }
      });
    });
  }

  void _listenChat() {
    final a = _a!;
    _chat = Cloud.instance.db
        .channel('alert:${a.id}:resp')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'alert_messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'alert_id', value: a.id),
          callback: (p) {
            final m = p.newRecord;
            if (m['sender_id'] == Cloud.instance.uid || !mounted) return;
            setState(() => _lastMsg = '${m['nombre']}: ${m['body']}');
          },
        )
        .onPostgresChanges(
          // RLS: solo recibo MI fila; el servidor copia aquí el estado de la alerta al cerrarse.
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'alert_responders',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'alert_id', value: a.id),
          callback: (p) {
            final st = p.newRecord['alert_status'] as String?;
            if (st != null && st != 'active') a.status.value = st;
          },
        )
        .subscribe();
  }

  Future<void> _decline() async {
    if (_real) await IncomingAlertService.instance.decline(_a!);
    if (mounted) Navigator.pop(context);
  }

  void _quick(String text) {
    if (!_real) return;
    IncomingAlertService.instance.sendMessage(_a!, text);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enviado: $text'), duration: const Duration(seconds: 1)));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _gps?.cancel();
    final ch = _chat;
    if (ch != null) Cloud.instance.db.removeChannel(ch);
    _a?.position.removeListener(_onVictimMoved);
    _a?.status.removeListener(_onStatus);
    IncomingAlertService.instance.stopAlarm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companion = _a?.level == AlertLevel.companion;
    final title = switch (_stage) {
      _Stage.incoming => companion ? '$_name pide compañía' : '$_name necesita ayuda',
      _Stage.enCamino => 'Vas en camino',
      _Stage.llego => 'Llegaste',
      _Stage.cerrada => '$_name cerró su alerta',
    };
    final body = switch (_stage) {
      _Stage.llego => 'Quédate con $_name hasta que marque que está en un lugar seguro.',
      _Stage.cerrada => _a?.status.value == 'safe' ? '$_name marcó que está a salvo 💜 Gracias por responder.' : 'La alerta fue cancelada.',
      _ => 'A ${formatMeters(_dist)} de ti · llegas en ${formatEta(etaSeconds(_dist))} caminando',
    };
    final vAcc = _a?.accuracy.value;
    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        Positioned.fill(
          child: LiveMap(
            user: _myPos,
            userAccuracy: _filter.accuracy,
            showRadius: false,
            people: [MapPerson(id: 'v', name: _name, position: _victim, color: AppColors.alertRed, arrived: _stage == _Stage.llego)],
            fitPadding: EdgeInsets.fromLTRB(40, 110, 40, _cardH + 36 + MediaQuery.paddingOf(context).bottom),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IconButton.filled(
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(backgroundColor: Colors.white),
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
          child: MeasureSize(
            onChange: (sz) => setState(() => _cardH = sz.height),
            child: AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: (companion ? AppColors.alertYellow : AppColors.alertRed).withValues(alpha: 0.18), shape: BoxShape.circle),
                  child: Icon(companion ? Icons.people_alt_outlined : Icons.sos_rounded, color: companion ? const Color(0xFFB39600) : AppColors.alertRed),
                ),
                const SizedBox(width: 10),
                Expanded(child: MixedTitle(bold: title, size: 17)),
              ]),
              const SizedBox(height: 10),
              Text(body, style: AppText.body),
              if (vAcc != null && _stage != _Stage.cerrada) ...[
                const SizedBox(height: 4),
                Text('Ubicación de $_name con precisión de ±${vAcc.round()} m', style: AppText.caption),
              ],
              if (_lastMsg != null) ...[
                const SizedBox(height: 8),
                Text(_lastMsg!, style: AppText.bodyStrong.copyWith(color: AppColors.primary)),
              ],
              const SizedBox(height: 16),
              if (_stage == _Stage.incoming) ...[
                AppButton(label: 'Voy en camino', icon: Icons.directions_walk_rounded, onPressed: _busy ? null : _accept),
                const SizedBox(height: 8),
                AppButton(label: 'No puedo', variant: AppButtonVariant.ghost, onPressed: _decline),
                const SizedBox(height: 8),
                const Text('No enfrentes físicamente a un agresor. Tu rol es acompañar y ayudar a llegar a un lugar seguro.', style: AppText.caption),
              ] else if (_stage == _Stage.enCamino || _stage == _Stage.llego) ...[
                if (_real)
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final q in ['Voy en camino 💜', 'Ya casi llego', 'Estoy aquí, ¿dónde estás?'])
                      ActionChip(label: Text(q), onPressed: () => _quick(q)),
                  ]),
                if (_stage == _Stage.enCamino) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(color: AppColors.primary, backgroundColor: AppColors.primarySoft),
                ] else ...[
                  const SizedBox(height: 10),
                  AppButton(label: 'Volver al inicio', variant: AppButtonVariant.lime, onPressed: () => Navigator.pop(context)),
                ],
              ] else
                AppButton(label: 'Volver al inicio', variant: AppButtonVariant.lime, onPressed: () => Navigator.pop(context)),
            ]),
            ),
          ),
        ),
      ]),
    );
  }
}
