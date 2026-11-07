import 'package:latlong2/latlong.dart';

const _distance = Distance();

/// Velocidad caminando usada para la ETA (m/s).
const walkingSpeed = 1.3;

double metersBetween(LatLng a, LatLng b) => _distance.distance(a, b);

double bearingBetween(LatLng a, LatLng b) => _distance.bearing(a, b);

LatLng offsetFrom(LatLng p, double meters, double bearingDeg) => _distance.offset(p, meters, bearingDeg);

/// ETA en segundos, en línea recta a paso de caminata.
int etaSeconds(double meters) => (meters / walkingSpeed).round();

String formatMeters(double m) => m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${(m / 10).round() * 10} m';

String formatEta(int seconds) {
  final min = (seconds / 60).ceil();
  return min <= 1 ? '~1 min' : '~$min min';
}

LatLng lerpLatLng(LatLng a, LatLng b, double t) =>
    LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
