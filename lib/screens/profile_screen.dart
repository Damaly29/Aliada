import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/cloud.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context) async {
    final s = AppState.instance;
    final ctl = TextEditingController(text: s.nombre);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tu nombre'),
        content: TextField(controller: ctl, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('Guardar')),
        ],
      ),
    );
    if (v != null) {
      s.setNombre(v);
      Cloud.instance.syncProfile().catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: AppBar(backgroundColor: AppColors.backgroundSoft, surfaceTintColor: Colors.transparent, title: const Text('Perfil', style: AppText.h3)),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Center(child: Avatar(name: s.nombre, size: 84, color: const Color(0xFF6B4F3A))),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () => _editName(context),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(s.nombre, style: AppText.h2),
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Row(children: [
                const Icon(Icons.smart_toy_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Aliadas simuladas', style: AppText.bodyStrong),
                    Text('Para demos: 3 aliadas falsas responden a tus alertas.', style: AppText.caption),
                  ]),
                ),
                Switch(value: s.aliadasSimuladas, onChanged: s.setAliadasSimuladas),
              ]),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(children: [
                _Row(icon: Icons.contact_phone_outlined, title: 'Contacto de emergencia', value: '${s.contactoNombre} · ${s.contactoTel}'),
                const Divider(height: 20),
                _Row(icon: Icons.pin_outlined, title: 'PIN para cancelar alertas', value: '${s.demoPin} (demo)'),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.value});
  final IconData icon;
  final String title, value;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: AppText.bodyStrong)),
        Text(value, style: AppText.caption),
      ]);
}
