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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Perfil'),
      ),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            // Cabecera de identidad
            Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.floating,
              ),
              child: Column(children: [
                Avatar(name: s.nombre, size: 86, color: const Color(0xFF4A3A2A), ring: Colors.white.withValues(alpha: 0.9)),
                const SizedBox(height: 12),
                Text(s.nombre, style: AppText.h2.copyWith(color: Colors.white)),
                const SizedBox(height: 3),
                Text(
                  'Tu perfil en la red de aliadas',
                  style: TextStyle(fontFamily: AppFonts.ui, fontSize: 11.5, color: Colors.white.withValues(alpha: 0.78)),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: () => _editName(context),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Editar nombre'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('PREFERENCIAS', style: AppText.label),
            ),
            AppCard(
              child: Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 21),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Aliadas simuladas', style: AppText.bodyStrong),
                    SizedBox(height: 2),
                    Text('Para demos: 3 aliadas falsas responden a tus alertas.', style: AppText.caption),
                  ]),
                ),
                Switch(value: s.aliadasSimuladas, onChanged: s.setAliadasSimuladas),
              ]),
            ),
            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('SEGURIDAD', style: AppText.label),
            ),
            AppCard(
              child: Column(children: [
                _Row(icon: Icons.contact_phone_outlined, title: 'Contacto de emergencia', value: '${s.contactoNombre} · ${s.contactoTel}'),
                const Divider(height: 22, color: AppColors.border),
                _Row(icon: Icons.pin_outlined, title: 'PIN para cancelar alertas', value: '${s.demoPin} (demo)'),
              ]),
            ),
            const SizedBox(height: 14),
            Text(
              'El PIN de demo debe validarse en el servidor antes de publicar la app.',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(fontSize: 11),
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
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: AppColors.primaryMist, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppColors.primary, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: AppText.bodyStrong.copyWith(fontSize: 13.5))),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(fontSize: 11.5),
          ),
        ),
      ]);
}
