import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

Future<void> callNumber(String tel) => launchUrl(Uri(scheme: 'tel', path: tel));

/// 105 (Policía) y Línea 100. Siempre visibles en la alerta; no dependen de red ni backend.
class EmergencyLinks extends StatelessWidget {
  const EmergencyLinks({super.key});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String tel, IconData icon) => Expanded(
          child: OutlinedButton.icon(
            onPressed: () => callNumber(tel),
            icon: Icon(icon, size: 18),
            label: Text(label, style: AppText.bodyStrong.copyWith(color: AppColors.primary)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              backgroundColor: AppColors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        );
    return Row(children: [
      chip('105 · Policía', '105', Icons.local_police_outlined),
      const SizedBox(width: 8),
      chip('Línea 100', '100', Icons.support_agent),
    ]);
  }
}
