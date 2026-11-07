import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart' show ChangeNotifier, IconData, Icons;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/app_state.dart';
import '../../core/geo.dart';
import '../../core/precise_location.dart';
import '../../widgets/toast_stack.dart';
import 'alert_backend.dart';
import 'cloud_backend.dart';
import '../../core/cloud.dart';
import 'models.dart';

/// Ubicación por defecto si no hay GPS/permiso (Lima).
const fallbackPosition = LatLng(-12.0689, -77.0790);

/// Estado de una alerta activa. Una sola fuente de eventos (backend) → estado + toasts.
class AlertController extends ChangeNotifier {
  AlertController({this.level = AlertLevel.emergency, AlertBackend? backend}) : _injected = backend;

  final AlertLevel level;
  final AlertBackend? _injected;
  late final AlertBackend _backend = _injected ??
      CombinedAlertBackend([
        if (Cloud.instance.configured) CloudAlertBackend(level: level, accuracy: () => accuracy),
        if (AppState.instance.aliadasSimuladas) DemoAlertBackend() else LocalOnlyAlertBackend(),
      ]);
  int unread = 0;
  bool _retryShown = false;
  final _siren = AudioPlayer();
  StreamSubscription<Position>? _gps;
  Timer? _clock;

  AlertStatus status = AlertStatus.active;
  LatLng userPosition = fallbackPosition;
  List<Responder> responders = const [];
  final List<ChatMessage> messages = [];
  final List<ToastMessage> toasts = [];
  final DateTime startedAt = DateTime.now();
  bool sirenOn = false;
  bool recording = false;
  bool hasGps = false;
  final _filter = LocationFilter();

  /// Radio de precisión del GPS en metros (null = sin GPS).
  double? get accuracy => hasGps ? _filter.accuracy : null;

  // Estado para las reglas de toasts (histéresis por umbral).
  int _lastEnCamino = 0;
  final Map<String, int> _lastThreshold = {};
  final Set<String> _arrived = {};
  static const _thresholds = [500, 200, 100];

  String get nombre => AppState.instance.nombre;
  Duration get elapsed => DateTime.now().difference(startedAt);

  List<Responder> get approaching =>
      responders.where((r) => r.status == ResponderStatus.enCamino || r.status == ResponderStatus.llego).toList()
        ..sort((a, b) => distanceTo(a).compareTo(distanceTo(b)));

  Responder? get nearest => approaching.firstOrNull;

  double distanceTo(Responder r) => metersBetween(r.position, userPosition);

  ChatMessage? get lastMessage => messages.lastOrNull;

  Future<void> start() async {
    _addToast(
      level == AlertLevel.emergency
          ? 'Alerta enviada. Buscando aliadas cerca de ti…'
          : 'Pedimos compañía a tus aliadas, en silencio y sin sirena.',
      icon: Icons.search_rounded,
    );
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    await _initLocation();
    _backend
      ..onResponders = _onResponders
      ..onMessage = (m) {
        messages.add(m);
        if (!m.isMine) unread++;
        notifyListeners();
      }
      ..onSystem = _onSystem
      ..start(userPosition: () => userPosition);
  }

  Future<void> _initLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) _setUser(last);
      final now = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, timeLimit: Duration(seconds: 8)),
      );
      _setUser(now);
      _gps = Geolocator.getPositionStream(locationSettings: preciseSettings()).listen(_setUser, onError: (_) {});
    } catch (_) {
      // Sin GPS la alerta sigue funcionando con la última ubicación conocida.
    }
  }

  void _setUser(Position p) {
    if (!_filter.add(p)) return; // lectura imprecisa descartada
    hasGps = true;
    userPosition = _filter.position!;
    _backend.pushUserLocation(userPosition);
    notifyListeners();
  }

  void _onSystem(String e) {
    switch (e) {
      case 'net_sent':
        _addToast('Alerta enviada a las aliadas disponibles cerca de ti', icon: Icons.radar);
      case 'net_retry':
        if (!_retryShown) {
          _retryShown = true;
          _addToast('Sin conexión: seguimos intentando enviar tu alerta. Usa 105 o Línea 100 si lo necesitas.', icon: Icons.wifi_off_rounded);
        }
      case 'dispatch':
        _addToast('Avisamos a 3 aliadas en un radio de 1 km', icon: Icons.radar);
      case 'sms':
        final s = AppState.instance;
        _addToast('${s.contactoNombre} recibió un SMS con tu ubicación', icon: Icons.sms_outlined);
    }
  }

  void _onResponders(List<Responder> list) {
    responders = list;
    final enCamino = approaching.length;
    if (enCamino > _lastEnCamino) {
      _addToast(enCamino == 1
          ? 'Hola, $nombre. Ya hay 1 persona acercándose 💜'
          : 'Hola, $nombre. Ya hay $enCamino personas acercándose 💜');
    }
    _lastEnCamino = enCamino;

    for (final r in list) {
      if (r.status == ResponderStatus.llego && _arrived.add(r.id)) {
        _addToast('${firstName(r.nombre)} llegó a tu ubicación', icon: Icons.check_circle_rounded);
        continue;
      }
      if (r.status != ResponderStatus.enCamino) continue;
      final d = distanceTo(r);
      final crossed = _thresholds.where((t) => d <= t).fold<int?>(null, (a, t) => t);
      final prev = _lastThreshold[r.id];
      if (crossed != null && (prev == null || crossed < prev)) {
        _lastThreshold[r.id] = crossed;
        _addToast('${firstName(r.nombre)} está a ${formatMeters(d)} · llega en ${formatEta(etaSeconds(d))}', icon: Icons.directions_walk_rounded);
      }
    }
    notifyListeners();
  }

  void _addToast(String text, {IconData icon = Icons.favorite_rounded}) {
    final t = ToastMessage(text, icon: icon);
    toasts.add(t);
    notifyListeners();
    Timer(const Duration(seconds: 5), () {
      toasts.remove(t);
      if (!_disposed) notifyListeners();
    });
  }

  void markRead() {
    unread = 0;
    notifyListeners();
  }

  void sendMessage(String body) {
    if (body.trim().isEmpty) return;
    messages.add(ChatMessage(senderId: 'me', senderName: nombre, body: body.trim()));
    _backend.sendMessage(body);
    notifyListeners();
  }

  Future<void> toggleSiren() async {
    sirenOn = !sirenOn;
    notifyListeners();
    if (sirenOn) {
      await _siren.setReleaseMode(ReleaseMode.loop);
      await _siren.setVolume(1);
      await _siren.play(AssetSource('sounds/siren.wav'));
    } else {
      await _siren.stop();
    }
  }

  void toggleRecording() {
    // MVP: indicador visual. La grabación real (audio cifrado) llega en la siguiente fase.
    recording = !recording;
    notifyListeners();
  }

  void close(AlertStatus s) {
    status = s;
    _backend.close(s);
    _siren.stop();
    sirenOn = false;
    _gps?.cancel();
    _clock?.cancel();
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _backend.dispose();
    _gps?.cancel();
    _clock?.cancel();
    _siren.dispose();
    super.dispose();
  }
}
