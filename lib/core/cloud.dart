import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_state.dart';

/// Conexión a Supabase. Si no hay configuración o red, la app sigue funcionando en modo local:
/// la alarma NUNCA depende del backend.
class Cloud {
  Cloud._();
  static final instance = Cloud._();

  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Cliente Supabase inicializado. Es suficiente para leer el catálogo público
  /// de eventos, aunque la autenticación todavía no haya terminado.
  final clientReady = ValueNotifier<bool>(false);

  /// Sesión autenticada + perfil listos. Necesario para favoritos e inscripciones.
  final ready = ValueNotifier<bool>(false);

  String? lastError;

  bool _initialized = false;
  bool _sessionInFlight = false;
  Timer? _retryTimer;
  int _retrySeconds = 8;

  bool get configured => _url.isNotEmpty && _anonKey.isNotEmpty;
  SupabaseClient get db => Supabase.instance.client;
  String? get uid => ready.value ? db.auth.currentUser?.id : null;

  /// Inicializa el cliente una sola vez y mantiene la sesión con reintentos.
  /// Es idempotente: se puede volver a llamar desde «Reintentar».
  Future<void> init() async {
    if (!configured) {
      lastError = 'Sin configuración de Supabase';
      return;
    }
    await _initClient();
    if (clientReady.value) await _ensureSession();
  }

  Future<void> _initClient() async {
    if (clientReady.value || _initialized) return;
    _initialized = true;
    try {
      await Supabase.initialize(url: _url, publishableKey: _anonKey);
      clientReady.value = true;
      lastError = null;
      _retrySeconds = 8;
    } catch (e) {
      _initialized = false;
      lastError = '$e';
      _scheduleRetry(_initClient);
    }
  }

  Future<void> _ensureSession() async {
    // Evita dos inicios de sesión simultáneos si varios reintentos coinciden.
    if (_sessionInFlight || !clientReady.value || ready.value) return;
    _sessionInFlight = true;
    try {
      if (db.auth.currentSession == null) {
        try {
          await db.auth.signInAnonymously();
        } on AuthException {
          // Sesiones anónimas desactivadas en el proyecto → cuenta propia del dispositivo.
          final s = AppState.instance;
          final email = await db.rpc('register_device', params: {'p_device': s.deviceId, 'p_secret': s.deviceSecret}) as String;
          await db.auth.signInWithPassword(email: email, password: s.deviceSecret);
        }
      }
      if (db.auth.currentSession != null) {
        ready.value = true;
        lastError = null;
        _retrySeconds = 8;
        // El perfil es complementario: un fallo aquí no bloquea favoritos/inscripciones.
        try {
          await syncProfile();
        } catch (_) {}
      } else {
        throw const AuthException('No se pudo iniciar la sesión del dispositivo.');
      }
    } catch (e) {
      lastError = '$e';
      ready.value = false;
      // reintento en segundo plano (p. ej. sin red al abrir la app)
      _scheduleRetry(_ensureSession);
    } finally {
      _sessionInFlight = false;
    }
  }

  void _scheduleRetry(Future<void> Function() action) {
    _retryTimer?.cancel();
    final seconds = _retrySeconds;
    // Retroceso exponencial (8 s → 60 s) para no saturar la red si el backend no responde.
    _retrySeconds = (_retrySeconds * 2).clamp(8, 60).toInt();
    _retryTimer = Timer(Duration(seconds: seconds), () {
      unawaited(action());
    });
  }

  Future<void> syncProfile() async {
    final s = AppState.instance;
    final id = db.auth.currentUser?.id;
    if (id == null) return;
    await db.from('profiles').upsert({'id': id, 'nombre': s.nombre, 'disponible': s.disponible, 'updated_at': DateTime.now().toIso8601String()});
  }
}
