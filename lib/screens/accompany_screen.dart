import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import 'lumai_screen.dart';
import 'responder_screen.dart';

/// Tab "Acompañame": LumAI (orientación) + modo aliada (acompañar a otras).
class AccompanyScreen extends StatelessWidget {
  const AccompanyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    Widget card(Widget child) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: AppShadows.card),
          child: child,
        );
    return Container(
      color: AppColors.backgroundSoft,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 130),
            children: [
              Text('Acompáñame', textAlign: TextAlign.center, style: AppText.h1.copyWith(color: AppColors.primary, fontSize: 22)),
              const SizedBox(height: 12),
              const LumaiHeroCard(),
              const SizedBox(height: 16),
              Text('Modo aliada', style: AppText.h3.copyWith(color: AppColors.primary)),
              const SizedBox(height: 8),
              card(Row(children: [
                const Icon(Icons.volunteer_activism_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Disponible para ayudar', style: AppText.bodyStrong),
                    Text('Recibirás alertas de estudiantes cerca de ti.', style: AppText.caption),
                  ]),
                ),
                Switch(value: s.disponible, onChanged: s.setDisponible),
              ])),
              const SizedBox(height: 10),
              card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Probar el modo aliada', style: AppText.bodyStrong),
                const SizedBox(height: 4),
                const Text('Simula que una estudiante cerca activó su alarma para ver lo que recibe una aliada.', style: AppText.caption),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Simular alerta cercana (demo)',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResponderScreen())),
                ),
              ])),
              const SizedBox(height: 10),
              card(const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Una acompañante voluntaria no debe enfrentar físicamente a un agresor ni reemplaza a la seguridad del campus. '
                    'Tu rol es estar presente y ayudar a llegar a un lugar seguro.',
                    style: AppText.caption,
                  ),
                ),
              ])),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acceso a LumAI con la mascota.
class LumaiHeroCard extends StatelessWidget {
  const LumaiHeroCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LumaiScreen())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('LumAI', style: TextStyle(fontFamily: AppFonts.title, fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white)),
                const SizedBox(height: 4),
                const Text('Tu asistente de primera orientación. Confidencial y sin juicios.',
                    style: TextStyle(fontFamily: AppFonts.ui, fontSize: 12.5, color: Colors.white, height: 1.35)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: AppColors.lime, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Hablar con LumAI', style: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.limeText)),
                ),
              ]),
            ),
            Image.asset('assets/images/luma_hola.png', height: 110),
          ]),
        ),
      ),
    );
  }
}
