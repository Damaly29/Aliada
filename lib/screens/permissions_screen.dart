import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/mixed_title.dart';
import 'home_shell.dart';

/// Pantalla previa: explica por qué pedimos ubicación (incluido "siempre") antes del diálogo del sistema.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});
  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _busy = false;

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      var p = await Geolocator.requestPermission();
      // "Siempre": en Android 11+ el sistema lo concede desde Ajustes tras "mientras se usa".
      if (p == LocationPermission.whileInUse) p = await Geolocator.requestPermission();
      if (p == LocationPermission.whileInUse && mounted) {
        await _offerAlwaysInSettings();
      }
    } catch (_) {}
    if (mounted) _go();
  }

  /// Sin "Permitir siempre" la ubicación se corta al bloquear el teléfono: explicamos
  /// cómo activarlo en Ajustes (Android 11+ e iOS no lo muestran en el diálogo).
  Future<void> _offerAlwaysInSettings() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activa "Permitir siempre"'),
        content: const Text(
          'Para seguir compartiendo tu ubicación con la pantalla apagada, entra a Ajustes › Permisos › Ubicación y elige "Permitir siempre". '
          'Sin eso, la alerta funciona, pero la ubicación se detiene al bloquear el teléfono.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abrir Ajustes')),
        ],
      ),
    );
    if (go == true) await Geolocator.openAppSettings();
  }

  void _go() => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));

  @override
  Widget build(BuildContext context) {
    Widget item(IconData i, String t, String d) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
              child: Icon(i, color: AppColors.primary, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: AppText.bodyStrong.copyWith(fontSize: 14)),
                const SizedBox(height: 3),
                Text(d, style: AppText.caption.copyWith(fontSize: 12)),
              ]),
            ),
          ]),
        );
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4EFFF), AppColors.background, Colors.white],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Spacer(),
              Container(
                width: 92,
                height: 92,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: AppShadows.card,
                ),
                child: Image.asset('assets/images/logo.png'),
              ),
              const SizedBox(height: 26),
              const MixedTitle(bold: 'Para cuidarte,', regular: 'necesitamos tu ubicación', size: 29),
              const SizedBox(height: 10),
              Text(
                'Solo la compartimos cuando tu alerta está activa. Tú decides hasta dónde.',
                style: AppText.body.copyWith(color: AppColors.textSoft, fontSize: 13.5),
              ),
              const SizedBox(height: 26),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Column(children: [
                  item(Icons.sos_rounded, 'Solo durante una alerta', 'Compartimos dónde estás únicamente mientras tu alerta está activa.'),
                  const Divider(height: 1, color: AppColors.border),
                  item(Icons.lock_clock_outlined, '"Permitir siempre"', 'Así seguimos enviando tu ubicación aunque bloquees el teléfono o cambies de app.'),
                  const Divider(height: 1, color: AppColors.border),
                  item(Icons.delete_sweep_outlined, 'Se borra en 24 h', 'Tu recorrido se elimina automáticamente 24 horas después de cerrar la alerta.'),
                ]),
              ),
              const Spacer(),
              AppButton(label: 'Permitir ubicación', icon: Icons.check_rounded, onPressed: _busy ? null : _request),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: _go,
                  style: TextButton.styleFrom(foregroundColor: AppColors.gray),
                  child: const Text('Ahora no', style: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
