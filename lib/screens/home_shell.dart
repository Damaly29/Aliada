import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/cloud.dart';
import '../features/alert/models.dart';
import '../theme/app_theme.dart';
import '../widgets/alert_type_dialog.dart';
import '../widgets/app_tab_bar.dart';
import '../widgets/sos_button.dart';
import 'accompany_screen.dart';
import 'alert_screen.dart';
import 'dashboard_screen.dart';
import 'events_screen.dart';
import 'messages_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _agendaRefreshToken = 0;

  void _selectTab(int index) {
    setState(() {
      _index = index;
      if (index == 0) _agendaRefreshToken++;
    });
  }

  void _returnToHomeFromEvents() {
    setState(() {
      _index = 0;
      // The events page can register the user before returning with its back
      // arrow, so refresh the dashboard agenda just like the Inicio tab does.
      _agendaRefreshToken++;
    });
  }

  @override
  void initState() {
    super.initState();
    if (!AppState.instance.nombreConfigurado) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askName());
    }
  }

  /// Primera vez: el nombre que verán las aliadas cuando pidas ayuda.
  Future<void> _askName() async {
    final ctl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cómo te llamas?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Es el nombre que verán tus aliadas si pides ayuda. Puedes usar un apodo.',
              style: AppText.caption,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Tu nombre'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctl.text),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    AppState.instance.setNombre(
      (v == null || v.trim().isEmpty) ? 'Estudiante' : v,
    );
    Cloud.instance.syncProfile().catchError((_) {});
  }

  /// Hold 2 s → modal "¿Qué peligro hay?" → nivel de alerta.
  Future<void> _triggerSos() async {
    final choice = await showAlertTypeDialog(context);
    if (!mounted || choice == AlertChoice.cancel) return;
    final level = choice == AlertChoice.emergency
        ? AlertLevel.emergency
        : AlertLevel.companion;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => AlertScreen(level: level),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        onOpenMessages: () => setState(() => _index = 2),
        onOpenEvents: () => setState(() => _index = 1),
        refreshToken: _agendaRefreshToken,
      ),
      EventsScreen(onBack: _returnToHomeFromEvents),
      const MessagesScreen(),
      const AccompanyScreen(),
    ];
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: AppTabBar(
        index: _index,
        onTap: _selectTab,
        center: SosButton(
          active: false,
          onTrigger: _triggerSos,
          onCancelPress: () {},
        ),
      ),
    );
  }
}
