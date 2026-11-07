import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'avatar.dart';

/// Tarjeta de sección con título centrado (Agenda / Mensaje del Dashboard).
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.children, this.onMore});
  final String title;
  final List<Widget> children;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: AppShadows.card),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, textAlign: TextAlign.center, style: AppText.h1.copyWith(color: AppColors.primary, fontSize: 22)),
        const SizedBox(height: 12),
        ...children,
        if (onMore != null) Center(child: MoreLink(onTap: onMore!)),
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
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Ver más', style: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w600, fontSize: 12)),
          SizedBox(width: 6),
          Icon(Icons.arrow_forward_rounded, size: 15),
        ]),
      );
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint});
  final String hint;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 34,
        child: TextField(
          style: AppText.caption.copyWith(color: AppColors.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.caption.copyWith(color: AppColors.primary.withValues(alpha: 0.7)),
            suffixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.gray),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            isDense: true,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
      );
}

class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.title, required this.subtitle, required this.icon, required this.colors});
  final String title, subtitle;
  final IconData icon;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          // TODO(figma): reemplazar por las fotos del evento exportadas del Figma.
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), gradient: LinearGradient(colors: colors)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: AppColors.text)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontFamily: AppFonts.ui, fontSize: 10.5, color: AppColors.text)),
            ]),
          ),
        ]),
      );
}

class ConversationTile extends StatelessWidget {
  const ConversationTile({super.key, required this.name, required this.preview, required this.time, this.unread = 0, this.color = AppColors.primary, this.onTap});
  final String name, preview, time;
  final int unread;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Avatar(name: name, size: 38, color: color, ring: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppFonts.ui, fontSize: 10.5, color: AppColors.text)),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(time, style: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 10, color: AppColors.primary)),
              const SizedBox(height: 4),
              if (unread > 0) UnreadBadge(count: unread),
            ]),
          ]),
        ),
      );
}

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 17),
        height: 17,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        child: Text('$count', style: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 10, color: Colors.white)),
      );
}

/// Datos demo de conversaciones (se reemplazan por la tabla de mensajes).
const demoConversations = [
  ('Julia Linarez', 'Hola, Nicolle, ¿Cómo has estado?', '14:25', 1, 0xFF765AD0),
  ('Andrea Salas', 'Qué bueno que te encuentres bien. Avísame si necesitas algo', '14:25', 5, 0xFF3D9970),
];
