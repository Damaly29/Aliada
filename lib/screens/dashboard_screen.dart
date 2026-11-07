import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/ui_parts.dart';
import 'lumai_screen.dart';
import 'profile_screen.dart';

/// Dashboard (Figma 56:1729).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenMessages});
  final VoidCallback onOpenMessages;

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    return Container(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
            children: [
              _HeroHeader(nombre: s.nombre),
              const SizedBox(height: 16),
              _LumaiTeaser(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LumaiScreen())),
              ),
              const SizedBox(height: 18),
              SectionCard(
                title: 'Agenda',
                onMore: () {},
                children: [
                  Row(children: [
                    const Expanded(child: SearchField(hint: 'Buscar evento, taller, grupo de…')),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 46,
                      child: TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.calendar_month_outlined, size: 17),
                        label: const Text('Hoy'),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          iconAlignment: IconAlignment.end,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                          textStyle: const TextStyle(fontFamily: AppFonts.ui, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  const EventTile(
                    title: 'Taller contra el acoso',
                    subtitle: 'Julia Aguirre · 7:00 pm · 12/06/2025',
                    icon: Icons.co_present_outlined,
                    colors: [Color(0xFF6E5A8F), Color(0xFF9C8AB8)],
                  ),
                  const EventTile(
                    title: 'Grupo de apoyo',
                    subtitle: 'UPC · 8:00 pm · 12/06/2025',
                    icon: Icons.diversity_3_outlined,
                    colors: [Color(0xFF6FA8DC), Color(0xFFA9CBEC)],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Mensajes',
                onMore: onOpenMessages,
                children: [
                  const SearchField(hint: 'Buscar conversación'),
                  const SizedBox(height: 6),
                  for (final c in demoConversations)
                    ConversationTile(name: c.$1, preview: c.$2, time: c.$3, unread: c.$4, color: Color(c.$5), onTap: onOpenMessages),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabecera de marca: gradiente, saludo y acceso al perfil.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.nombre});
  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.floating,
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(right: -36, top: -58, child: _glow(150, 0.09)),
        Positioned(right: 34, bottom: -66, child: _glow(110, 0.06)),
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: Avatar(name: nombre, size: 46, color: const Color(0xFF4A3A2A), ring: Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(
                style: const TextStyle(fontFamily: AppFonts.title, fontSize: 19, letterSpacing: -0.3, color: Colors.white),
                children: [
                  const TextSpan(text: 'Hola, ', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: nombre, style: TextStyle(fontWeight: FontWeight.w400, color: Colors.white.withValues(alpha: 0.92))),
                ],
              )),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.shield_moon_outlined, size: 13, color: Colors.white.withValues(alpha: 0.75)),
                const SizedBox(width: 5),
                Text(
                  'Tu red de apoyo está cerca',
                  style: TextStyle(fontFamily: AppFonts.ui, fontSize: 11.5, color: Colors.white.withValues(alpha: 0.78)),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white.withValues(alpha: 0.16),
            shape: const CircleBorder(side: BorderSide(color: Color(0x33FFFFFF))),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {},
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.notifications_none_rounded, color: Colors.white, size: 21),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _glow(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacity)),
      );
}

/// Acceso rápido a LumAI con la mascota.
class _LumaiTeaser extends StatelessWidget {
  const _LumaiTeaser({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            gradient: AppColors.mistGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: Row(children: [
            Image.asset(lumaiAvatar, height: 62),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('LumAI', style: AppText.h3.copyWith(color: AppColors.primary, fontSize: 15)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                    child: const Text('24/7', style: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 8.5, letterSpacing: 0.4, color: AppColors.primary)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(
                  '¿Necesitas orientación? Habla conmigo, es confidencial y sin juicios.',
                  style: AppText.caption.copyWith(fontSize: 11.5, height: 1.35),
                ),
              ]),
            ),
            const SizedBox(width: 6),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: AppShadows.soft),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 17),
            ),
          ]),
        ),
      ),
    );
  }
}
