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

  final ready = ValueNotifier<bool>(false);
  String? lastError;

  bool get configured => _url.isNotEmpty && _anonKey.isNotEmpty;
  SupabaseClient get db => Supabase.instance.client;
  String? get uid => ready.value ? db.auth.currentUser?.id : null;

  Future<void> init() async {
    if (!configured) {
      lastError = 'Sin configuración de Supabase';
      return;
    }
    try {
      await Supabase.initialize(url: _url, publishableKey: _anonKey);
      await _ensureSession();
    } catch (e) {
      lastError = '$e';
    }
  }

  Future<void> _ensureSession() async {
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
      await syncProfile();
      ready.value = true;
      lastError = null;
    } catch (e) {
      lastError = '$e';
      ready.value = false;
      // reintento en segundo plano (p. ej. sin red al abrir la app)
      Future.delayed(const Duration(seconds: 8), _ensureSession);
    }
  }

  Future<void> syncProfile() async {
    final s = AppState.instance;
    final id = db.auth.currentUser?.id;
    if (id == null) return;
    await db.from('profiles').upsert({'id': id, 'nombre': s.nombre, 'disponible': s.disponible, 'updated_at': DateTime.now().toIso8601String()});
  }
}
