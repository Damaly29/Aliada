import 'package:flutter/material.dart';
import '../features/alert/alert_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';

/// Chat de alerta (Figma 83:1942).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.controller});
  final AlertController controller;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  static const _quick = ['Estoy bien por ahora', 'Tengo miedo', 'Estoy en la puerta', '¿Dónde estás?'];

  void _send([String? v]) {
    widget.controller.sendMessage(v ?? _text.text);
    _text.clear();
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: ListenableBuilder(
          listenable: c,
          builder: (_, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Chat de alerta', style: AppText.h3),
            Text('${c.approaching.length} aliadas en la conversación', style: AppText.caption),
          ]),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: ListenableBuilder(
            listenable: c,
            builder: (_, _) {
              final msgs = c.messages.reversed.toList();
              if (msgs.isEmpty) {
                return const Center(child: Text('Aún no hay mensajes', style: AppText.caption));
              }
              return ListView.builder(
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final m = msgs[i];
                  final color = c.responders.where((r) => r.id == m.senderId).map((r) => Color(r.color)).firstOrNull ?? AppColors.primary;
                  final bubble = Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: m.isMine ? AppColors.primary : AppColors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(m.isMine ? 18 : 4),
                        bottomRight: Radius.circular(m.isMine ? 4 : 18),
                      ),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (!m.isMine) Text(m.senderName, style: AppText.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
                      Text(m.body, style: AppText.body.copyWith(color: m.isMine ? Colors.white : AppColors.text)),
                    ]),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisAlignment: m.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!m.isMine) ...[Avatar(name: m.senderName, size: 30, color: color), const SizedBox(width: 8)],
                        bubble,
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _quick.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ActionChip(
              label: Text(_quick[i]),
              onPressed: () => _send(_quick[i]),
              backgroundColor: AppColors.white,
              elevation: 0,
              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              labelStyle: const TextStyle(fontFamily: AppFonts.ui, fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.14)),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje…',
                    filled: true,
                    fillColor: AppColors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              IconButton.filled(
                onPressed: _send,
                style: IconButton.styleFrom(backgroundColor: AppColors.primary, elevation: 2, shadowColor: const Color(0x665B3FC8)),
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
