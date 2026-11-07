import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
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
    } catch (_) {}
    _go();
  }

  void _go() => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));

  @override
  Widget build(BuildContext context) {
    Widget item(IconData i, String t, String d) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
              child: Icon(i, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: AppText.bodyStrong),
                const SizedBox(height: 2),
                Text(d, style: AppText.caption),
              ]),
            ),
          ]),
        );
    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Spacer(),
            Image.asset('assets/images/logo.png', width: 88, height: 88),
            const SizedBox(height: 24),
            const MixedTitle(bold: 'Para cuidarte,', regular: 'necesitamos tu ubicación'),
            const SizedBox(height: 24),
            item(Icons.sos_rounded, 'Solo durante una alerta', 'Compartimos dónde estás únicamente mientras tu alerta está activa.'),
            item(Icons.lock_clock_outlined, '"Permitir siempre"', 'Así seguimos enviando tu ubicación aunque bloquees el teléfono o cambies de app.'),
            item(Icons.delete_sweep_outlined, 'Se borra en 24 h', 'Tu recorrido se elimina automáticamente 24 horas después de cerrar la alerta.'),
            const Spacer(),
            AppButton(label: 'Permitir ubicación', icon: Icons.check_rounded, onPressed: _busy ? null : _request),
            const SizedBox(height: 8),
            Center(child: TextButton(onPressed: _go, child: const Text('Ahora no', style: TextStyle(color: AppColors.gray)))),
          ]),
        ),
      ),
    );
  }
}
