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
      color: AppColors.backgroundSoft,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 130),
            children: [
              // Header "Hola, Nicolle"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: AppShadows.card),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    child: Avatar(name: s.nombre, size: 36, color: const Color(0xFF6B4F3A), ring: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(TextSpan(
                      style: const TextStyle(fontFamily: AppFonts.title, fontSize: 17, color: AppColors.primary),
                      children: [
                        const TextSpan(text: 'Hola, ', style: TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: s.nombre),
                      ],
                    )),
                  ),
                  const Icon(Icons.notifications_none_rounded, color: AppColors.primary, size: 22),
                ]),
              ),
              const SizedBox(height: 12),
              // Acceso rápido a LumAI
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                elevation: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LumaiScreen())),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: AppShadows.card, color: Colors.white),
                    child: Row(children: [
                      Image.asset(lumaiAvatar, height: 54),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('¿Necesitas orientación?', style: TextStyle(fontFamily: AppFonts.title, fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
                          Text('Habla con LumAI, confidencial y sin juicios', style: TextStyle(fontFamily: AppFonts.ui, fontSize: 11.5, color: AppColors.text)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Agenda',
                onMore: () {},
                children: [
                  Row(children: [
                    const Expanded(child: SearchField(hint: 'Buscar evento, taller, grupo de…')),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 34,
                      child: TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.calendar_month_outlined, size: 16),
                        label: const Text('Hoy'),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          iconAlignment: IconAlignment.end,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          textStyle: const TextStyle(fontFamily: AppFonts.ui, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  const EventTile(
                    title: 'Taller contra el acoso',
                    subtitle: 'Julia Aguirre - 7:00 pm 12/06/2025',
                    icon: Icons.co_present_outlined,
                    colors: [Color(0xFF5B5566), Color(0xFF8C8697)],
                  ),
                  const EventTile(
                    title: 'Grupo de apoyo',
                    subtitle: 'UPC - 8:00 pm 12/06/2025',
                    icon: Icons.diversity_3_outlined,
                    colors: [Color(0xFF6FA8DC), Color(0xFFB4D3EE)],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Mensaje',
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
