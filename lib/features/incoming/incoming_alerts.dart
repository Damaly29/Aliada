import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibration/vibration.dart';
import '../../core/app_state.dart';
import '../../core/cloud.dart';
import '../../core/geo.dart';
import '../../core/notifications.dart';
import '../alert/models.dart';

/// Alerta de otra estudiante, recibida por esta aliada.
class IncomingAlert {
  IncomingAlert({required this.id, required this.nombre, required this.level, required LatLng position})
      : position = ValueNotifier(position);
  final String id;
  final String nombre;
  final AlertLevel level;
  final ValueNotifier<LatLng> position;
  final status = ValueNotifier<String>('active');

  /// Precisión del GPS de la usuaria en metros (null si no la reportó).
  final accuracy = ValueNotifier<double?>(null);
}

/// Escucha alertas cercanas (RLS: solo activas a ≤ 2 km de mi presencia) y hace sonar/vibrar el teléfono.
/// También mantiene la presencia de la aliada (cada ~10 s) mientras está "Disponible".
class IncomingAlertService with WidgetsBindingObserver {
  IncomingAlertService._();
  static final instance = IncomingAlertService._();

  final navigatorKey = GlobalKey<NavigatorState>();
  Widget Function(IncomingAlert alert)? screenBuilder;

  final Map<String, IncomingAlert> _alerts = {};
  final Set<String> _handled = {};
  final _alarm = AudioPlayer();
  RealtimeChannel? _channel;
  Timer? _presence, _alarmTimeout;
  LatLng? lastPosition;
  bool _ringing = false;

  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _lifecycle = state;

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    Cloud.instance.ready.addListener(_onCloud);
    AppState.instance.addListener(_onAppState);
    _onCloud();
  }

  void _onCloud() {
    if (!Cloud.instance.ready.value) return;
    _subscribe();
    _onAppState();
  }

  bool _wasAvailable = false;
  void _onAppState() {
    if (!Cloud.instance.ready.value) return;
    final on = AppState.instance.disponible;
    if (on == _wasAvailable && _presence != null) return;
    _wasAvailable = on;
    Cloud.instance.syncProfile().catchError((_) {});
    _presence?.cancel();
    if (on) {
      _pushPresence();
      _presence = Timer.periodic(const Duration(seconds: 10), (_) => _pushPresence());
    } else {
      _presence = null;
      Cloud.instance.db.rpc('clear_presence').then((_) {}, onError: (_) {});
    }
  }

  Future<void> _pushPresence() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      lastPosition = LatLng(p.latitude, p.longitude);
      await Cloud.instance.db.rpc('upsert_presence', params: {'p_lat': p.latitude, 'p_lng': p.longitude});
      // Primera presencia: revisar alertas activas que ya existían.
      if (_alerts.isEmpty) _fetchActive();
    } catch (_) {}
  }

  Future<void> _fetchActive() async {
    try {
      final rows = await Cloud.instance.db.from('alerts').select().eq('status', 'active').neq('user_id', Cloud.instance.uid ?? '');
      for (final r in rows) {
        _onAlert(r);
      }
    } catch (_) {}
  }

  void _subscribe() {
    if (_channel != null) return;
    _channel = Cloud.instance.db
        .channel('nearby-alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alerts',
          callback: (p) => _onAlert(p.newRecord),
        )
        .subscribe();
  }

  void _onAlert(Map<String, dynamic> r) {
    final id = r['id'] as String?;
    if (id == null || r['user_id'] == Cloud.instance.uid) return;
    final lat = (r['lat'] as num?)?.toDouble(), lng = (r['lng'] as num?)?.toDouble();
    final status = r['status'] as String? ?? 'active';
    final existing = _alerts[id];
    if (existing != null) {
      if (lat != null && lng != null) existing.position.value = LatLng(lat, lng);
      existing.accuracy.value = (r['accuracy_m'] as num?)?.toDouble();
      existing.status.value = status;
      if (status != 'active' && _ringing) stopAlarm();
      return;
    }
    if (status != 'active' || lat == null || lng == null || !AppState.instance.disponible) return;
    final a = IncomingAlert(
      id: id,
      nombre: r['nombre'] as String? ?? 'Una estudiante',
      level: r['level'] == 'companion' ? AlertLevel.companion : AlertLevel.emergency,
      position: LatLng(lat, lng),
    );
    a.accuracy.value = (r['accuracy_m'] as num?)?.toDouble();
    _alerts[id] = a;
    if (_handled.add(id)) _ring(a);
  }

  Future<void> _ring(IncomingAlert a) async {
    _ringing = true;
    final dist = lastPosition == null ? null : metersBetween(lastPosition!, a.position.value);
    final where = dist == null ? 'cerca de ti' : 'a ${formatMeters(dist)}';
    final emergency = a.level == AlertLevel.emergency;
    // Con la app abierta mostramos la pantalla directamente; en segundo plano, notificación.
    if (_lifecycle != AppLifecycleState.resumed) {
      AlarmNotifications.showSos(
        title: emergency ? '🚨 Alguien cerca necesita ayuda' : '🟡 Alguien cerca pide compañía',
        body: '${a.nombre} · $where',
      );
    }
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: const [0, 900, 400, 900, 400, 900], repeat: 0);
      }
    } catch (_) {}
    if (emergency) {
      try {
        await _alarm.setReleaseMode(ReleaseMode.loop);
        await _alarm.setVolume(1);
        await _alarm.play(AssetSource('sounds/siren.wav'));
      } catch (_) {}
    }
    _alarmTimeout?.cancel();
    _alarmTimeout = Timer(const Duration(seconds: 45), stopAlarm);
    final nav = navigatorKey.currentState;
    final b = screenBuilder;
    if (nav != null && b != null) nav.push(MaterialPageRoute(builder: (_) => b(a)));
  }

  void stopAlarm() {
    _ringing = false;
    _alarmTimeout?.cancel();
    _alarm.stop();
    Vibration.cancel();
    AlarmNotifications.cancel();
  }

  // ───── Acciones de la aliada ─────

  Future<bool> accept(IncomingAlert a, LatLng me) async {
    stopAlarm();
    try {
      await Cloud.instance.db.from('alert_responders').upsert({
        'alert_id': a.id,
        'nombre': AppState.instance.nombre,
        'status': 'en_camino',
        'lat': me.latitude,
        'lng': me.longitude,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> decline(IncomingAlert a) async {
    stopAlarm();
    try {
      await Cloud.instance.db.from('alert_responders').upsert({'alert_id': a.id, 'nombre': AppState.instance.nombre, 'status': 'rechazo'});
    } catch (_) {}
  }

  Future<void> pushLocation(IncomingAlert a, LatLng me) async {
    try {
      await Cloud.instance.db.rpc('push_responder_location', params: {'p_alert': a.id, 'p_lat': me.latitude, 'p_lng': me.longitude});
    } catch (_) {}
  }

  Future<void> sendMessage(IncomingAlert a, String body) async {
    try {
      await Cloud.instance.db.from('alert_messages').insert({'alert_id': a.id, 'nombre': AppState.instance.nombre, 'body': body});
    } catch (_) {}
  }
}
