import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TabItem {
  const TabItem(this.label, this.icon, {this.badge = false});
  final String label;
  final IconData icon;
  final bool badge;
}

/// Tabs del Figma (62:1031): Inicio · Educate · [alerta] · Mensaje · Acompañame.
const appTabs = [
  TabItem('Inicio', Icons.home_outlined),
  TabItem('Edúcate', Icons.rocket_launch_outlined),
  TabItem('Mensaje', Icons.chat_bubble_outline_rounded, badge: true),
  TabItem('Acompañame', Icons.person_add_alt_outlined),
];

/// Tab bar blanca con muesca curva donde se asienta el botón circular central.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.index, required this.onTap, required this.center});
  final int index;
  final ValueChanged<int>? onTap;
  final Widget center;

  static const barHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    Widget tab(int i) {
      final it = appTabs[i];
      final selected = i == index;
      final c = selected ? AppColors.primary : AppColors.gray;
      return Expanded(
        child: InkResponse(
          onTap: onTap == null ? null : () => onTap!(i),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              Icon(it.icon, color: c, size: 22),
              if (it.badge)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                  ),
                ),
            ]),
            const SizedBox(height: 3),
            Text(it.label,
                style: TextStyle(fontFamily: AppFonts.ui, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, fontSize: 10.5, color: c)),
          ]),
        ),
      );
    }

    return SizedBox(
      height: barHeight + bottom + 34,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: barHeight + bottom,
          child: CustomPaint(
            painter: _NotchedBarPainter(),
            child: Padding(
              padding: EdgeInsets.only(bottom: bottom, top: 8),
              child: Row(children: [tab(0), tab(1), const SizedBox(width: 84), tab(2), tab(3)]),
            ),
          ),
        ),
        Positioned(bottom: bottom + barHeight - 42, child: center),
      ]),
    );
  }
}

class _NotchedBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const notchR = 40.0, depth = 22.0;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(cx - notchR - 14, 0)
      ..cubicTo(cx - notchR, 0, cx - notchR + 4, depth, cx, depth)
      ..cubicTo(cx + notchR - 4, depth, cx + notchR, 0, cx + notchR + 14, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(path, const Color(0x55000000), 4, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
