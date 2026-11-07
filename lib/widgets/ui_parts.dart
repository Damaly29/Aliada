import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'avatar.dart';

/// Superficie de sección con encabezado editorial (Agenda / Mensaje del Dashboard).
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.children, this.onMore});
  final String title;
  final List<Widget> children;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: AppColors.limeGradient,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: AppText.h2.copyWith(fontSize: 18))),
          if (onMore != null) MoreLink(onTap: onMore!),
        ]),
        const SizedBox(height: 14),
        ...children,
      ]),
    );
  }
}

class MoreLink extends StatelessWidget {
  const MoreLink({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: AppColors.primaryMist,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Ver más', style: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 11.5)),
          SizedBox(width: 4),
          Icon(Icons.arrow_forward_rounded, size: 14),
        ]),
      );
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint});
  final String hint;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: TextField(
          style: AppText.body.copyWith(fontSize: 13.5),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.gray),
            prefixIconConstraints: const BoxConstraints(minWidth: 42),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            isDense: true,
          ),
        ),
      );
}

class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.title, required this.subtitle, required this.icon, required this.colors, this.onTap});
  final String title, subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: AppColors.backgroundSoft,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
                    const SizedBox(height: 3),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(fontSize: 11.5)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.gray, size: 20),
              ]),
            ),
          ),
        ),
      );
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({super.key, required this.name, required this.preview, required this.time, this.unread = 0, this.color = AppColors.primary, this.onTap});
  final String name, preview, time;
  final int unread;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
            child: Row(children: [
              Avatar(name: name, size: 44, color: color, ring: AppColors.primaryMist),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
                  const SizedBox(height: 3),
                  Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(fontSize: 11.5)),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(time, style: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 10, color: AppColors.primary)),
                const SizedBox(height: 6),
                if (unread > 0) UnreadBadge(count: unread) else const SizedBox(height: 20),
              ]),
            ]),
          ),
        ),
      );
}

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 20),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text('$count', style: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 10, color: Colors.white)),
      );
}

/// Datos demo de conversaciones (se reemplazan por la tabla de mensajes).
const demoConversations = [
  ('Julia Linarez', 'Hola, Nicolle, ¿Cómo has estado?', '14:25', 1, 0xFF765AD0),
  ('Andrea Salas', 'Qué bueno que te encuentres bien. Avísame si necesitas algo', '14:25', 5, 0xFF3D9970),
];
