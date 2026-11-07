import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import '../core/geo.dart';
import '../theme/app_theme.dart';

class MapPerson {
  const MapPerson({required this.id, required this.name, required this.position, required this.color, this.arrived = false});
  final String id;
  final String name;
  final LatLng position;
  final Color color;
  final bool arrived;
}

/// Estilo claro y limpio (oculta comercios/transporte para que resalten las personas).
const _mapStyle = '''
[
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","elementType":"labels.icon","stylers":[{"saturation":-60},{"lightness":20}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"lightness":10}]},
  {"featureType":"water","stylers":[{"color":"#d9d2f3"}]}
]
''';

/// Google Maps en 3D (inclinado, con edificios) con el punto azul de la usuaria, su círculo de
/// precisión GPS y avatares que se deslizan entre posiciones.
class LiveMap extends StatefulWidget {
  const LiveMap({
    super.key,
    required this.user,
    required this.people,
    this.userAccuracy,
    this.moveDuration = const Duration(milliseconds: 1900),
    this.fitPadding = const EdgeInsets.fromLTRB(60, 200, 60, 120),
    this.showRadius = true,
  });
  final LatLng user;
  final List<MapPerson> people;

  /// Radio de precisión del GPS en metros (se dibuja como círculo azul translúcido).
  final double? userAccuracy;
  final Duration moveDuration;

  /// Zona tapada por header/panel: el mapa encuadra dentro del área libre.
  final EdgeInsets fitPadding;
  final bool showRadius;

  @override
  State<LiveMap> createState() => LiveMapState();
}

class _Track {
  _Track(this.from, this.to, this.start);
  LatLng from, to;
  Duration start;
}

class LiveMapState extends State<LiveMap> with SingleTickerProviderStateMixin {
  static const _tilt3d = 55.0;

  gm.GoogleMapController? _ctl;
  late final Ticker _ticker = createTicker(_onTick);
  final Map<String, _Track> _tracks = {};
  final Map<String, gm.BitmapDescriptor> _icons = {};
  gm.BitmapDescriptor? _userIcon;
  Duration _now = Duration.zero, _lastFrame = Duration.zero;
  int _fittedCount = -1;
  Size _size = Size.zero;
  bool threeD = true;
  bool _userMovedCamera = false;
  bool _programmatic = false;
  LatLng? _lastFollow;
  double? _fittedSpan; // separación máxima (m) en el último encuadre

  @override
  void initState() {
    super.initState();
    _sync();
    _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (_userIcon == null) _renderUserDot(dpr).then((i) => mounted ? setState(() => _userIcon = i) : null);
    for (final p in widget.people) {
      _ensureIcon(p, dpr);
    }
  }

  @override
  void didUpdateWidget(LiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    for (final p in widget.people) {
      _ensureIcon(p, dpr);
    }
    if (oldWidget.fitPadding != widget.fitPadding) _fittedCount = -1; // el panel cambió de tamaño
    _maybeFit();
    _follow();
  }

  String _iconKey(MapPerson p) => '${p.id}|${p.name}|${p.arrived}';

  void _ensureIcon(MapPerson p, double dpr) {
    final k = _iconKey(p);
    if (_icons.containsKey(k)) return;
    _icons[k] = gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueViolet);
    _renderPerson(p, dpr).then((i) {
      if (!mounted) return;
      setState(() => _icons[k] = i);
    });
  }

  void _sync() {
    for (final p in widget.people) {
      final t = _tracks[p.id];
      if (t == null) {
        _tracks[p.id] = _Track(p.position, p.position, _now);
      } else if (t.to != p.position) {
        t.from = _current(t);
        t.to = p.position;
        t.start = _now;
      }
    }
  }

  LatLng _current(_Track t) {
    final ms = widget.moveDuration.inMilliseconds;
    final k = ms == 0 ? 1.0 : ((_now - t.start).inMilliseconds / ms).clamp(0.0, 1.0);
    return lerpLatLng(t.from, t.to, Curves.easeInOut.transform(k));
  }

  void _onTick(Duration elapsed) {
    _now = elapsed;
    // Los marcadores nativos se actualizan a ~30 fps: fluido sin saturar el canal con el mapa.
    if ((_now - _lastFrame).inMilliseconds < 33) return;
    final moving = _tracks.values.any((t) => (_now - t.start) < widget.moveDuration + const Duration(milliseconds: 50) && t.from != t.to);
    if (moving) {
      _lastFrame = _now;
      setState(() {});
    }
  }

  /// Vuelve a encuadrar a la usuaria y a las aliadas (botón "recentrar").
  void recenter() {
    _userMovedCamera = false;
    _fittedCount = -1;
    _maybeFit();
  }

  /// Alterna vista 3D (inclinada, edificios) y 2D (cenital).
  void toggle3D() {
    setState(() => threeD = !threeD);
    recenter();
  }

  /// Sin aliadas en el mapa, la cámara sigue a la usuaria mientras camina (si no movió el mapa a mano).
  void _follow() {
    if (widget.people.isNotEmpty || _userMovedCamera || _ctl == null) return;
    final last = _lastFollow;
    if (last != null && metersBetween(last, widget.user) < 4) return;
    _lastFollow = widget.user;
    _animate(gm.CameraPosition(target: _g(widget.user), zoom: 17.8, tilt: threeD ? _tilt3d : 0));
  }

  double _span() {
    var m = 0.0;
    for (final p in widget.people) {
      m = math.max(m, metersBetween(widget.user, p.position));
    }
    return m;
  }

  void _maybeFit() {
    final c = _ctl;
    if (c == null || _size == Size.zero) return;
    final span = _span();
    final last = _fittedSpan;
    // Re-encuadrar si entra/sale alguien, o si la aliada se acercó/alejó bastante (y la usuaria no movió el mapa).
    final spanChanged = last != null && !_userMovedCamera && (span < last * 0.6 || span > last * 1.4);
    if (widget.people.length == _fittedCount && !spanChanged) return;
    _fittedCount = widget.people.length;
    _fittedSpan = span;
    final pts = [widget.user, ...widget.people.map((p) => p.position)];
    if (pts.length == 1) {
      _animate(gm.CameraPosition(target: _g(widget.user), zoom: 17.8, tilt: threeD ? _tilt3d : 0));
      return;
    }
    var s = pts.first.latitude, n = s, w = pts.first.longitude, e = w;
    for (final p in pts) {
      if (p.latitude < s) s = p.latitude;
      if (p.latitude > n) n = p.latitude;
      if (p.longitude < w) w = p.longitude;
      if (p.longitude > e) e = p.longitude;
    }
    final pad = widget.fitPadding;
    final visW = math.max(80.0, _size.width - pad.left - pad.right);
    final visH = math.max(80.0, _size.height - pad.top - pad.bottom);
    double mercY(double lat) => math.log(math.tan(math.pi / 4 + lat * math.pi / 360));
    final lngSpan = math.max((e - w).abs(), 0.0004) * 1.25;
    final latFrac = math.max((mercY(n) - mercY(s)).abs(), 0.0000069) * 1.25 / (2 * math.pi);
    final zLng = math.log(visW * 360 / (lngSpan * 256)) / math.ln2;
    final zLat = math.log(visH / (latFrac * 256)) / math.ln2;
    // La inclinación 3D "aleja" la parte superior: restamos un poco de zoom para que todo quepa.
    final zoom = (math.min(zLng, zLat) - (threeD ? 0.55 : 0.15)).clamp(12.0, 18.5);
    _animate(gm.CameraPosition(target: gm.LatLng((s + n) / 2, (w + e) / 2), zoom: zoom, tilt: threeD ? _tilt3d : 0));
  }

  void _animate(gm.CameraPosition pos) {
    _programmatic = true;
    _ctl?.animateCamera(gm.CameraUpdate.newCameraPosition(pos));
    Future.delayed(const Duration(milliseconds: 1200), () => _programmatic = false);
  }

  static gm.LatLng _g(LatLng p) => gm.LatLng(p.latitude, p.longitude);

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = <gm.Marker>{
      gm.Marker(
        markerId: const gm.MarkerId('me'),
        position: _g(widget.user),
        icon: _userIcon ?? gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndexInt: 1,
      ),
      for (final p in widget.people)
        gm.Marker(
          markerId: gm.MarkerId(p.id),
          position: _g(_tracks[p.id] == null ? p.position : _current(_tracks[p.id]!)),
          icon: _icons[_iconKey(p)] ?? gm.BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.4),
          zIndexInt: 2,
          infoWindow: gm.InfoWindow(title: p.name),
        ),
    };
    final acc = widget.userAccuracy;
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      if (size != _size) {
        _size = size;
        WidgetsBinding.instance.addPostFrameCallback((_) => recenter());
      }
      return gm.GoogleMap(
        initialCameraPosition: gm.CameraPosition(target: _g(widget.user), zoom: 17.5, tilt: _tilt3d),
        style: _mapStyle,
        padding: widget.fitPadding,
        markers: markers,
        buildingsEnabled: true,
        circles: {
          if (widget.showRadius)
            gm.Circle(
              circleId: const gm.CircleId('radius'),
              center: _g(widget.user),
              radius: 1000,
              fillColor: AppColors.primary.withValues(alpha: 0.04),
              strokeColor: AppColors.primary.withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          if (acc != null && acc > 3)
            gm.Circle(
              circleId: const gm.CircleId('accuracy'),
              center: _g(widget.user),
              radius: acc,
              fillColor: AppColors.userDot.withValues(alpha: 0.14),
              strokeColor: AppColors.userDot.withValues(alpha: 0.5),
              strokeWidth: 1,
              zIndex: 1,
            ),
        },
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        onCameraMoveStarted: () {
          if (!_programmatic) _userMovedCamera = true;
        },
        onMapCreated: (c) {
          _ctl = c;
          recenter();
        },
      );
    });
  }
}

// ---------- Íconos dibujados en canvas (avatar + nombre, punto azul) ----------

Future<gm.BitmapDescriptor> _toDescriptor(ui.Picture pic, int w, int h, double dpr) async {
  final img = await pic.toImage(w, h);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return gm.BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: dpr);
}

Future<gm.BitmapDescriptor> _renderPerson(MapPerson p, double dpr) async {
  const avatar = 46.0, labelH = 18.0, width = 90.0;
  final w = (width * dpr).round(), h = ((avatar + labelH + 8) * dpr).round();
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..scale(dpr);
  final center = const Offset(width / 2, avatar / 2 + 2);
  c.drawCircle(center + const Offset(1, 2), avatar / 2, Paint()..color = const Color(0x33000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  c.drawCircle(center, avatar / 2, Paint()..color = p.arrived ? AppColors.lime : Colors.white);
  c.drawCircle(center, avatar / 2 - 3, Paint()..color = p.color);
  final initials = p.name.trim().isEmpty ? '?' : p.name.trim()[0].toUpperCase();
  final tp = TextPainter(
    text: TextSpan(text: initials, style: const TextStyle(fontFamily: AppFonts.title, fontWeight: FontWeight.w700, fontSize: 18, color: Colors.white)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  final lp = TextPainter(
    text: TextSpan(text: p.name, style: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.text)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: width - 12);
  final lr = RRect.fromRectAndRadius(
    Rect.fromCenter(center: Offset(width / 2, avatar + 4 + labelH / 2), width: lp.width + 12, height: labelH),
    const Radius.circular(9),
  );
  c.drawRRect(lr.shift(const Offset(0, 1)), Paint()..color = const Color(0x22000000));
  c.drawRRect(lr, Paint()..color = Colors.white);
  lp.paint(c, Offset(width / 2 - lp.width / 2, avatar + 4 + (labelH - lp.height) / 2));
  return _toDescriptor(rec.endRecording(), w, h, dpr);
}

Future<gm.BitmapDescriptor> _renderUserDot(double dpr) async {
  const size = 40.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..scale(dpr);
  const o = Offset(size / 2, size / 2);
  c.drawCircle(o, 18, Paint()..color = AppColors.userDot.withValues(alpha: 0.2));
  c.drawCircle(o, 10, Paint()..color = Colors.white);
  c.drawCircle(o, 7, Paint()..color = AppColors.userDot);
  return _toDescriptor(rec.endRecording(), (size * dpr).round(), (size * dpr).round(), dpr);
}
