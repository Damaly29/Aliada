import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'geo.dart';

/// Ajustes de máxima precisión (GPS de navegación, sin pausas automáticas, cada ~2 s).
LocationSettings preciseSettings({int distanceFilter = 2}) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: distanceFilter,
      intervalDuration: const Duration(seconds: 2),
    );
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: distanceFilter,
      activityType: ActivityType.fitness,
      pauseLocationUpdatesAutomatically: false,
    );
  }
  return LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: distanceFilter);
}

/// Filtro de lecturas: descarta saltos imprecisos y suaviza según la precisión reportada.
class LocationFilter {
  LatLng? position;
  double? accuracy; // metros (radio de confianza ~68 %)
  DateTime? _at;

  /// Devuelve true si la lectura se aceptó.
  bool add(Position p) {
    final now = DateTime.now();
    final raw = LatLng(p.latitude, p.longitude);
    final acc = p.accuracy <= 0 ? 50.0 : p.accuracy;
    final prev = position;
    if (prev == null || _at == null) {
      _set(raw, acc, now);
      return true;
    }
    final age = now.difference(_at!).inSeconds;
    // Lectura mucho peor que la actual y reciente → la ignoramos (típico al perder el GPS un instante).
    if (acc > 60 && acc > (accuracy ?? 0) * 2.5 && age < 20) return false;
    // Salto físicamente imposible caminando (> 12 m/s) con mala precisión → ignorar.
    final d = metersBetween(prev, raw);
    if (age > 0 && d / age > 12 && acc > 25) return false;
    // Suavizado ponderado por precisión (tipo Kalman simplificado).
    final w = (accuracy ?? acc) / ((accuracy ?? acc) + acc);
    final k = age > 10 ? 1.0 : w.clamp(0.35, 1.0);
    _set(lerpLatLng(prev, raw, k), (accuracy ?? acc) * (1 - k) + acc * k, now);
    return true;
  }

  void _set(LatLng p, double acc, DateTime t) {
    position = p;
    accuracy = acc;
    _at = t;
  }
}
