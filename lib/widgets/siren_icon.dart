import 'package:flutter/material.dart';

/// Ícono de sirena del botón central (Figma 62:1031), dibujado para no depender de assets.
class SirenIcon extends StatelessWidget {
  const SirenIcon({super.key, this.size = 26, this.color = Colors.white});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _SirenPainter(color));
}

class _SirenPainter extends CustomPainter {
  _SirenPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final u = s.width / 24;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // cúpula
    final dome = Path()
      ..moveTo(7 * u, 18 * u)
      ..lineTo(7 * u, 13 * u)
      ..arcToPoint(Offset(17 * u, 13 * u), radius: Radius.circular(5 * u))
      ..lineTo(17 * u, 18 * u);
    canvas.drawPath(dome, p);
    // base
    canvas.drawRRect(RRect.fromLTRBR(5 * u, 18 * u, 19 * u, 21 * u, Radius.circular(1 * u)), p);
    // destello
    canvas.drawLine(Offset(12 * u, 15.5 * u), Offset(12 * u, 13 * u), p);
    // rayos
    canvas.drawLine(Offset(12 * u, 2.5 * u), Offset(12 * u, 4.5 * u), p);
    canvas.drawLine(Offset(4.5 * u, 5.5 * u), Offset(5.9 * u, 6.9 * u), p);
    canvas.drawLine(Offset(19.5 * u, 5.5 * u), Offset(18.1 * u, 6.9 * u), p);
  }

  @override
  bool shouldRepaint(_SirenPainter old) => old.color != color;
}
