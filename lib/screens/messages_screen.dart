import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_parts.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
          children: [
            Text('Mensajes', style: AppText.h1),
            const SizedBox(height: 4),
            Text('Tus conversaciones con aliadas y tu red de apoyo.', style: AppText.caption.copyWith(fontSize: 13)),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Recientes',
              children: [
                const SearchField(hint: 'Buscar conversación'),
                const SizedBox(height: 6),
                for (final c in demoConversations) ConversationTile(name: c.$1, preview: c.$2, time: c.$3, unread: c.$4, color: Color(c.$5)),
                const SizedBox(height: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
