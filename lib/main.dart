import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'core/app_state.dart';
import 'core/cloud.dart';
import 'core/notifications.dart';
import 'features/incoming/incoming_alerts.dart';
import 'screens/responder_screen.dart';
import 'screens/home_shell.dart';
import 'screens/permissions_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await AppState.instance.load();
  // Backend y notificaciones sin bloquear el arranque: la alarma funciona aunque fallen.
  AlarmNotifications.init();
  Cloud.instance.init();
  IncomingAlertService.instance
    ..screenBuilder = ((a) => ResponderScreen(incoming: a))
    ..start();
  LocationPermission perm;
  try {
    perm = await Geolocator.checkPermission();
  } catch (_) {
    perm = LocationPermission.denied;
  }
  final granted = perm == LocationPermission.always || perm == LocationPermission.whileInUse;
  runApp(AliadaApp(showPermissions: !granted));
}

class AliadaApp extends StatelessWidget {
  const AliadaApp({super.key, required this.showPermissions});
  final bool showPermissions;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aliada',
      navigatorKey: IncomingAlertService.instance.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: showPermissions ? const PermissionsScreen() : const HomeShell(),
    );
  }
}
