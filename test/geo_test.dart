import 'package:alaida/core/geo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const lima = LatLng(-12.0689, -77.0790);

  group('distancias', () {
    test('el mismo punto da 0 m', () {
      expect(metersBetween(lima, lima), closeTo(0, 0.001));
    });

    test('un grado de latitud ronda los 111 km', () {
      final north = LatLng(lima.latitude + 1, lima.longitude);
      expect(metersBetween(lima, north), closeTo(110619, 300));
    });

    test('offsetFrom y metersBetween son consistentes', () {
      final p = offsetFrom(lima, 400, 90);
      expect(metersBetween(lima, p), closeTo(400, 1));
    });

    test('bearingBetween apunta al este en el ecuador', () {
      final east = LatLng(0, 1);
      expect(bearingBetween(const LatLng(0, 0), east), closeTo(90, 0.5));
    });
  });

  group('formato', () {
    test('formatMeters usa metros redondeados a 10', () {
      expect(formatMeters(347), '350 m');
      expect(formatMeters(20), '20 m');
    });

    test('formatMeters cambia a km desde 1000 m', () {
      expect(formatMeters(1500), '1.5 km');
    });

    test('etaSeconds usa la velocidad de caminata', () {
      expect(etaSeconds(walkingSpeed * 60), 60);
    });

    test('formatEta nunca baja de 1 minuto', () {
      expect(formatEta(0), '~1 min');
      expect(formatEta(90), '~2 min');
    });
  });

  group('interpolación', () {
    test('lerpLatLng devuelve los extremos en t=0 y t=1', () {
      final b = offsetFrom(lima, 100, 0);
      expect(lerpLatLng(lima, b, 0).latitude, closeTo(lima.latitude, 1e-12));
      expect(lerpLatLng(lima, b, 1).latitude, closeTo(b.latitude, 1e-12));
    });

    test('lerpLatLng a mitad de camino se queda entre ambos', () {
      final b = offsetFrom(lima, 100, 0);
      final mid = lerpLatLng(lima, b, 0.5);
      expect(mid.latitude, greaterThan(lima.latitude));
      expect(mid.latitude, lessThan(b.latitude));
    });
  });
}
