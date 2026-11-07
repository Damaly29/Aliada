import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_state.dart';
import '../../core/cloud.dart';
import 'alert_backend.dart';
import 'models.dart';

const _palette = [0xFF765AD0, 0xFFE07A5F, 0xFF3D9970, 0xFF2F80ED, 0xFFD6336C, 0xFFF59F00];
int colorForId(String id) => _palette[id.codeUnits.fold<int>(0, (a, c) => a + c) % _palette.length];

ResponderStatus responderStatusFrom(String? s) => switch (s) {
      'llego' => ResponderStatus.llego,
      'rechazo' => ResponderStatus.rechazo,
      'notified' => ResponderStatus.notified,
      _ => ResponderStatus.enCamino,
    };

/// Alerta real en Supabase: crea `alerts`, envía la ubicación cada 4 s y escucha en UN solo canal
/// (`alert:{id}`) a las aliadas que acuden y los mensajes. Si no hay red, reintenta sin bloquear la alarma.
class CloudAlertBackend extends AlertBackend {
  CloudAlertBackend({required this.level, this.accuracy});
  final AlertLevel level;

  /// Precisión actual del GPS de la usuaria (metros), para que la aliada sepa qué tan exacto es el punto.
  final double? Function()? accuracy;

  final Map<String, Responder> _responders = {};
  RealtimeChannel? _channel;
  Timer? _loc, _retry;
  String? alertId;
  late LatLng Function() _user;
  bool _closed = false;

  SupabaseClient get _db => Cloud.instance.db;

  @override
  void start({required LatLng Function() userPosition}) {
    _user = userPosition;
    _create();
  }

  Future<void> _create() async {
    if (_closed) return;
    if (!Cloud.instance.ready.value) {
      _retry = Timer(const Duration(seconds: 3), _create);
      return;
    }
    try {
      final row = await _db
          .from('alerts')
          .insert({
            'nombre': AppState.instance.nombre,
            'level': level == AlertLevel.emergency ? 'emergency' : 'companion',
            'lat': _user().latitude,
            'lng': _user().longitude,
          })
          .select('id')
          .single();
      alertId = row['id'] as String;
      onSystem?.call('net_sent');
      _subscribe();
      _loc = Timer.periodic(const Duration(seconds: 4), (_) => _pushLocation());
    } catch (_) {
      onSystem?.call('net_retry');
      _retry = Timer(const Duration(seconds: 5), _create);
    }
  }

  void _subscribe() {
    final id = alertId!;
    _channel = _db
        .channel('alert:$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alert_responders',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'alert_id', value: id),
          callback: (p) => _onResponder(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'alert_messages',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'alert_id', value: id),
          callback: (p) {
            final m = p.newRecord;
            if (m['sender_id'] == Cloud.instance.uid) return; // los míos ya están en pantalla
            onMessage?.call(ChatMessage(senderId: m['sender_id'] as String, senderName: m['nombre'] as String? ?? 'Aliada', body: m['body'] as String? ?? ''));
          },
        )
        .subscribe();
  }

  void _onResponder(Map<String, dynamic> r) {
    final rid = r['responder_id'] as String?;
    if (rid == null) return;
    final status = responderStatusFrom(r['status'] as String?);
    if (status == ResponderStatus.rechazo) {
      _responders.remove(rid);
    } else {
      final lat = (r['lat'] as num?)?.toDouble(), lng = (r['lng'] as num?)?.toDouble();
      final pos = lat != null && lng != null ? LatLng(lat, lng) : _user();
      final existing = _responders[rid];
      if (existing == null) {
        _responders[rid] = Responder(id: rid, nombre: r['nombre'] as String? ?? 'Aliada', position: pos, color: colorForId(rid), status: status);
      } else {
        existing
          ..position = pos
          ..status = status;
      }
    }
    onResponders?.call(List.unmodifiable(_responders.values));
  }

  Future<void> _pushLocation() async {
    final id = alertId;
    if (id == null || _closed) return;
    try {
      await _db.rpc('push_alert_location', params: {'p_alert': id, 'p_lat': _user().latitude, 'p_lng': _user().longitude, 'p_acc': accuracy?.call()});
    } catch (_) {}
  }

  @override
  void pushUserLocation(LatLng p) {}

  @override
  void sendMessage(String body) {
    final id = alertId;
    if (id == null) return;
    _db.from('alert_messages').insert({'alert_id': id, 'nombre': AppState.instance.nombre, 'body': body}).then((_) {}, onError: (_) {});
  }

  @override
  void close(AlertStatus status) {
    final id = alertId;
    if (id != null) {
      _db.from('alerts').update({'status': status.name, 'closed_at': DateTime.now().toIso8601String()}).eq('id', id).then((_) {}, onError: (_) {});
    }
    dispose();
  }

  @override
  void dispose() {
    _closed = true;
    _loc?.cancel();
    _retry?.cancel();
    final ch = _channel;
    if (ch != null) _db.removeChannel(ch);
    _channel = null;
  }
}

/// Une varias fuentes (aliadas reales + simuladas) en una sola lista para la UI.
class CombinedAlertBackend extends AlertBackend {
  CombinedAlertBackend(this.backends);
  final List<AlertBackend> backends;
  final Map<int, List<Responder>> _lists = {};

  @override
  void start({required LatLng Function() userPosition}) {
    for (var i = 0; i < backends.length; i++) {
      final b = backends[i];
      b.onResponders = (l) {
        _lists[i] = l;
        onResponders?.call([for (final v in _lists.values) ...v]);
      };
      b.onMessage = (m) => onMessage?.call(m);
      b.onSystem = (s) => onSystem?.call(s);
      b.start(userPosition: userPosition);
    }
  }

  @override
  void pushUserLocation(LatLng p) {
    for (final b in backends) {
      b.pushUserLocation(p);
    }
  }

  @override
  void sendMessage(String body) {
    for (final b in backends) {
      b.sendMessage(body);
    }
  }

  @override
  void close(AlertStatus status) {
    for (final b in backends) {
      b.close(status);
    }
  }

  @override
  void dispose() {
    for (final b in backends) {
      b.dispose();
    }
  }
}
