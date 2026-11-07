import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Perfil local del MVP (persistido en el dispositivo). Se reemplaza por `profiles` de Supabase.
class AppState extends ChangeNotifier {
  AppState._();
  static final instance = AppState._();

  late SharedPreferences _prefs;
  late String deviceId;
  late String deviceSecret;
  bool lumaiConsent = false;
  String nombre = 'Nicolle';
  bool nombreConfigurado = false;
  bool rolAliada = true;
  bool disponible = true;
  bool aliadasSimuladas = true;
  String contactoNombre = 'Mamá';
  String contactoTel = '999888777';

  /// PIN de demo. En producción solo existe el hash en el servidor (pgcrypto).
  final String demoPin = '1234';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    deviceId = _prefs.getString('deviceId') ?? _newId();
    await _prefs.setString('deviceId', deviceId);
    deviceSecret = _prefs.getString('deviceSecret') ?? _newSecret();
    await _prefs.setString('deviceSecret', deviceSecret);
    lumaiConsent = _prefs.getBool('lumaiConsent') ?? false;
    nombreConfigurado = _prefs.getString('nombre') != null;
    nombre = _prefs.getString('nombre') ?? nombre;
    disponible = _prefs.getBool('disponible') ?? disponible;
    aliadasSimuladas = _prefs.getBool('aliadasSimuladas') ?? aliadasSimuladas;
  }

  static String _newId() {
    final r = math.Random.secure();
    return List.generate(10, (_) => 'abcdefghjkmnpqrstuvwxyz23456789'[r.nextInt(31)]).join();
  }

  static String _newSecret() {
    final r = math.Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789-_';
    return List.generate(40, (_) => chars[r.nextInt(chars.length)]).join();
  }

  void setLumaiConsent(bool v) {
    lumaiConsent = v;
    _prefs.setBool('lumaiConsent', v);
    notifyListeners();
  }

  void setNombre(String v) {
    if (v.trim().isEmpty) return;
    nombre = v.trim();
    nombreConfigurado = true;
    _prefs.setString('nombre', nombre);
    notifyListeners();
  }

  void setDisponible(bool v) {
    disponible = v;
    _prefs.setBool('disponible', v);
    notifyListeners();
  }

  void setAliadasSimuladas(bool v) {
    aliadasSimuladas = v;
    _prefs.setBool('aliadasSimuladas', v);
    notifyListeners();
  }
}
