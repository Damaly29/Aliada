import 'dart:async';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../../core/geo.dart';
import 'models.dart';

/// Contrato con el backend. `DemoAlertBackend` simula todo en el dispositivo;
/// `SupabaseAlertBackend` (siguiente fase) usará RPCs + canal Realtime `alert:{id}`.
abstract class AlertBackend {
  void start({required LatLng Function() userPosition});
  void pushUserLocation(LatLng p);
  void sendMessage(String body);
  void close(AlertStatus status);
  void dispose();

  void Function(List<Responder> responders)? onResponders;
  void Function(ChatMessage message)? onMessage;
  void Function(String event)? onSystem;
}

/// Simulador (equivalente a scripts/simulate-responders): 3 aliadas a 300–800 m que aceptan
/// con 2–5 s de diferencia y caminan hacia la usuaria actualizando posición cada 2 s hasta "llegó".
class DemoAlertBackend extends AlertBackend {
  final _rnd = math.Random();
  final List<Responder> _responders = [];
  final List<Timer> _timers = [];
  Timer? _walk;
  late LatLng Function() _user;

  static const tick = Duration(seconds: 2);

  /// Metros por tick. Acelerado para la demo (~12 m/s); la ETA mostrada usa 1.3 m/s reales.
  static const stepMeters = 24.0;
  static const arriveRadius = 30.0;

  static const _people = [
    ('julia', 'Julia Linarez', 0xFF765AD0),
    ('camila', 'Camila Rojas', 0xFFE07A5F),
    ('andrea', 'Andrea Salas', 0xFF3D9970),
  ];

  static const _greetings = [
    'Estoy en camino, ¿Dónde estás exactamente?',
    'Soy Camila, estoy cerca. ¿Puedes ver algún local abierto?',
    'Andrea aquí, voy hacia ti. No cuelgues si alguien te llama.',
  ];

  @override
  void start({required LatLng Function() userPosition}) {
    _user = userPosition;
    _later(const Duration(milliseconds: 900), () => onSystem?.call('dispatch'));
    _later(const Duration(milliseconds: 1500), () => onSystem?.call('sms'));

    var delay = 2500;
    for (var i = 0; i < _people.length; i++) {
      final (id, nombre, color) = _people[i];
      final start = offsetFrom(_user(), 300 + _rnd.nextDouble() * 500, _rnd.nextDouble() * 360);
      final r = Responder(id: id, nombre: nombre, position: start, color: color);
      _responders.add(r);
      _later(Duration(milliseconds: delay), () {
        r.status = ResponderStatus.enCamino;
        _emit();
        _later(const Duration(milliseconds: 1200), () => onMessage?.call(ChatMessage(senderId: id, senderName: nombre, body: _greetings[i])));
      });
      delay += 2000 + _rnd.nextInt(3000);
    }
    _emit();
    _walk = Timer.periodic(tick, (_) => _step());
  }

  void _step() {
    var changed = false;
    final u = _user();
    for (final r in _responders.where((r) => r.status == ResponderStatus.enCamino)) {
      final d = metersBetween(r.position, u);
      if (d <= arriveRadius + stepMeters) {
        r.position = offsetFrom(u, 12, bearingBetween(u, r.position));
        r.status = ResponderStatus.llego;
      } else {
        // pequeño zigzag para que parezca una caminata por calles
        final jitter = (_rnd.nextDouble() - 0.5) * 30;
        r.position = offsetFrom(r.position, stepMeters, bearingBetween(r.position, u) + jitter);
      }
      changed = true;
    }
    if (changed) _emit();
  }

  void _emit() => onResponders?.call(List.unmodifiable(_responders));

  void _later(Duration d, void Function() f) => _timers.add(Timer(d, f));

  @override
  void pushUserLocation(LatLng p) {}

  @override
  void sendMessage(String body) {
    final first = _responders.where((r) => r.status != ResponderStatus.notified).firstOrNull;
    if (first == null) return;
    _later(const Duration(seconds: 2), () {
      final reply = first.status == ResponderStatus.llego ? 'Estoy aquí contigo 💜' : 'Entendido, ya casi llego.';
      onMessage?.call(ChatMessage(senderId: first.id, senderName: first.nombre, body: reply));
    });
  }

  @override
  void close(AlertStatus status) => dispose();

  @override
  void dispose() {
    _walk?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }
}

/// Sin aliadas simuladas: la alerta sigue funcionando localmente (sirena, 105, Línea 100, contacto).
class LocalOnlyAlertBackend extends AlertBackend {
  @override
  void start({required LatLng Function() userPosition}) {}
  @override
  void pushUserLocation(LatLng p) {}
  @override
  void sendMessage(String body) {}
  @override
  void close(AlertStatus status) {}
  @override
  void dispose() {}
}
