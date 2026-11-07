import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TabItem {
  const TabItem(this.label, this.icon, {this.activeIcon, this.badge = false});
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final bool badge;
}

/// Tabs del Figma (62:1031): Inicio · Educate · [alerta] · Mensaje · Acompañame.
const appTabs = [
  TabItem('Inicio', Icons.home_outlined, activeIcon: Icons.home_rounded),
  TabItem('Educate', Icons.people_alt_outlined, activeIcon: Icons.people_alt_rounded),
  TabItem('Mensaje', Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, badge: true),
  TabItem('Acompañame', Icons.person_add_alt_outlined, activeIcon: Icons.person_add_alt_1_rounded),
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
          radius: 34,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 42,
              height: 27,
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    selected ? (it.activeIcon ?? it.icon) : it.icon,
                    key: ValueKey(selected),
                    color: c,
                    size: 21,
                  ),
                ),
                if (it.badge)
                  Positioned(
                    right: 9,
                    top: 3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 2),
            Text(
              it.label,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 10.5,
                color: c,
              ),
            ),
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
    canvas.drawShadow(path, const Color(0x335B3FC8), 6, false);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFFBF9FF)],
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
