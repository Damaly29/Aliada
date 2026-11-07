import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_parts.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundSoft,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 130),
          children: [
            SectionCard(
              title: 'Mensajes',
              children: [
                const SearchField(hint: 'Buscar conversación'),
                const SizedBox(height: 6),
                for (final c in demoConversations) ConversationTile(name: c.$1, preview: c.$2, time: c.$3, unread: c.$4, color: Color(c.$5)),
                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
