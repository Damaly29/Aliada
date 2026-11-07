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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: child,
        );
    return Container(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: s,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
            children: [
              Text('Acompáñame', style: AppText.h1),
              const SizedBox(height: 4),
              Text('Apoya a otras estudiantes y pide orientación cuando la necesites.', style: AppText.caption.copyWith(fontSize: 13)),
              const SizedBox(height: 18),
              const LumaiHeroCard(),
              const SizedBox(height: 22),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),
                child: Text('MODO ALIADA', style: AppText.label),
              ),
              card(Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.volunteer_activism_outlined, color: AppColors.primary, size: 21),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Disponible para ayudar', style: AppText.bodyStrong),
                    SizedBox(height: 2),
                    Text('Recibirás alertas de estudiantes cerca de ti.', style: AppText.caption),
                  ]),
                ),
                Switch(value: s.disponible, onChanged: s.setDisponible),
              ])),
              const SizedBox(height: 12),
              card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Probar el modo aliada', style: AppText.bodyStrong),
                const SizedBox(height: 4),
                const Text('Simula que una estudiante cerca activó su alarma para ver lo que recibe una aliada.', style: AppText.caption),
                const SizedBox(height: 14),
                AppButton(
                  label: 'Simular alerta cercana (demo)',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResponderScreen())),
                ),
              ])),
              const SizedBox(height: 12),
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LumaiScreen())),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadows.floating,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(right: -40, top: -50, child: _glow(150, 0.09)),
              Positioned(right: 60, bottom: -60, child: _glow(110, 0.06)),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('LumAI', style: TextStyle(fontFamily: AppFonts.title, fontWeight: FontWeight.w700, fontSize: 21, letterSpacing: -0.3, color: Colors.white)),
                      const SizedBox(height: 5),
                      Text(
                        'Tu asistente de primera orientación. Confidencial y sin juicios.',
                        style: TextStyle(fontFamily: AppFonts.ui, fontSize: 12.5, color: Colors.white.withValues(alpha: 0.82), height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(gradient: AppColors.limeGradient, borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Hablar con LumAI', style: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.limeText)),
                          SizedBox(width: 5),
                          Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.limeText),
                        ]),
                      ),
                    ]),
                  ),
                  Image.asset('assets/images/luma_hola.png', height: 116),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _glow(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacity)),
      );
}
