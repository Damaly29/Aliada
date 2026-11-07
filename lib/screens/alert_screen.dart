import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_state.dart';
import '../features/alert/alert_controller.dart';
import '../features/alert/models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_tab_bar.dart';
import '../widgets/avatar.dart';
import '../widgets/emergency_links.dart';
import '../widgets/live_map.dart';
import '../widgets/measure_size.dart';
import '../widgets/pin_sheet.dart';
import '../widgets/sos_button.dart';
import '../widgets/toast_stack.dart';
import '../widgets/ui_parts.dart';
import 'chat_screen.dart';
import 'safe_screen.dart';

/// Alerta – Lugar no seguro (Figma 69:1287).
class AlertScreen extends StatefulWidget {
  const AlertScreen({super.key, this.level = AlertLevel.emergency});
  final AlertLevel level;
  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {
  late final _c = AlertController(level: widget.level);
  final _map = GlobalKey<LiveMapState>();
  double _topH = 190, _bottomH = 200;

  @override
  void initState() {
    super.initState();
    _c.start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    final ok = await showPinSheet(context, title: '¿Cancelar la alerta?', verify: (p) => p == AppState.instance.demoPin);
    if (!ok || !mounted) return;
    _c.close(AlertStatus.cancelled);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alerta cancelada. Avisamos a las aliadas.')));
  }

  void _safe() {
    HapticFeedback.mediumImpact();
    final names = _c.approaching.map((r) => firstName(r.nombre)).toList();
    final elapsed = _c.elapsed;
    _c.close(AlertStatus.safe);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SafeScreen(helpers: names, elapsed: elapsed)));
  }

  void _openChat() {
    _c.markRead();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(controller: _c)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        extendBody: true,
        body: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            final people = _c.approaching
                .map((r) => MapPerson(
                      id: r.id,
                      name: firstName(r.nombre),
                      position: r.position,
                      color: Color(r.color),
                      arrived: r.status == ResponderStatus.llego,
                    ))
                .toList();
            // El panel inferior se apoya justo encima del botón central (que sobresale ~34 px de la barra).
            final panelBottom = AppTabBar.barHeight + bottomInset + 44;
            return Stack(children: [
              Positioned.fill(
                child: LiveMap(
                  key: _map,
                  user: _c.userPosition,
                  userAccuracy: _c.accuracy,
                  people: people,
                  // Solo el área que NO tapan el encabezado ni el panel: nada queda debajo de los botones.
                  fitPadding: EdgeInsets.fromLTRB(28, _topH + 12, 28, panelBottom + _bottomH + 12),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: MeasureSize(
                    onChange: (sz) => setState(() => _topH = sz.height + MediaQuery.paddingOf(context).top),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        _HeaderCard(c: _c),
                        const SizedBox(height: 8),
                        const _EmergencyChips(),
                        const SizedBox(height: 8),
                        ToastStack(toasts: _c.toasts),
                      ]),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: panelBottom,
                child: MeasureSize(
                  onChange: (sz) => setState(() => _bottomH = sz.height),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      _CircleAction(
                        label: _map.currentState?.threeD == false ? '3D' : '2D',
                        onTap: () => setState(() => _map.currentState?.toggle3D()),
                      ),
                      const SizedBox(width: 10),
                      _CircleAction(icon: Icons.my_location_rounded, onTap: () => _map.currentState?.recenter()),
                    ]),
                    const SizedBox(height: 10),
                    _MessageCard(c: _c, onTap: _openChat),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _Pill(label: 'Estoy en un lugar seguro', bg: AppColors.primary, fg: Colors.white, onTap: _safe)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Pill(
                          label: _c.nearest != null ? 'Llamar a ${firstName(_c.nearest!.nombre)}' : 'Llamar a ${AppState.instance.contactoNombre}',
                          icon: Icons.call_outlined,
                          bg: AppColors.lime,
                          fg: AppColors.limeText,
                          onTap: () => callNumber(_c.nearest != null ? '999000111' : AppState.instance.contactoTel),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ]);
          },
        ),
        bottomNavigationBar: AppTabBar(
          index: -1,
          onTap: null,
          center: SosButton(active: true, onTrigger: () {}, onCancelPress: _cancel),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.c});
  final AlertController c;

  @override
  Widget build(BuildContext context) {
    final e = c.elapsed;
    final clock = '${e.inMinutes.toString().padLeft(2, '0')}:${(e.inSeconds % 60).toString().padLeft(2, '0')}';
    final emergency = c.level == AlertLevel.emergency;
    final accent = emergency ? AppColors.alertRed : const Color(0xFFC9A227);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(
              style: const TextStyle(fontFamily: AppFonts.title, fontSize: 15.5, letterSpacing: -0.2, color: AppColors.text),
              children: [
                const TextSpan(text: 'Estamos contigo, ', style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: c.nombre, style: const TextStyle(fontWeight: FontWeight.w400, color: AppColors.textSoft)),
              ],
            )),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 6, spreadRadius: 1)]),
              ),
              const SizedBox(width: 6),
              Text(emergency ? 'Emergencia' : 'Compañía', style: AppText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSoft)),
              const SizedBox(width: 6),
              Text(clock, style: const TextStyle(fontFamily: AppFonts.title, fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  c.accuracy == null ? '· ubicación aprox.' : '· GPS ±${c.accuracy!.round()} m',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(fontSize: 11),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 6),
        _SquareAction(
          icon: c.recording ? Icons.stop_rounded : Icons.mic_none_rounded,
          active: c.recording,
          activeColor: AppColors.alertRed,
          tooltip: c.recording ? 'Detener grabación' : 'Grabar',
          onTap: c.toggleRecording,
        ),
        const SizedBox(width: 8),
        _SquareAction(
          icon: c.sirenOn ? Icons.volume_up_rounded : Icons.volume_up_outlined,
          active: c.sirenOn,
          tooltip: c.sirenOn ? 'Apagar sirena' : 'Activar sirena',
          onTap: c.toggleSiren,
        ),
      ]),
    );
  }
}

class _SquareAction extends StatelessWidget {
  const _SquareAction({required this.icon, required this.active, required this.tooltip, required this.onTap, this.activeColor = AppColors.primary});
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: active ? activeColor : AppColors.primaryMist,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 19, color: active ? Colors.white : AppColors.primary)),
          ),
        ),
      );
}

/// 105 y Línea 100 siempre visibles durante la alerta.
class _EmergencyChips extends StatelessWidget {
  const _EmergencyChips();
  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String tel) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: Colors.white,
            elevation: 0,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => callNumber(tel),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: AppShadows.soft,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.call_rounded, size: 13, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Text(label, style: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.primary)),
                ]),
              ),
            ),
          ),
        );
    return Row(children: [chip('105 · Policía', '105'), chip('Línea 100', '100')]);
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({this.icon, this.label, required this.onTap});
  final IconData? icon;
  final String? label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: AppShadows.floating),
        child: Material(
          color: AppColors.primary,
          shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 2.5)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: Colors.white, size: 20)
                    : Text(label ?? '', style: const TextStyle(fontFamily: AppFonts.title, fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
              ),
            ),
          ),
        ),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.c, required this.onTap});
  final AlertController c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final msg = c.lastMessage;
    final sender = msg == null || msg.isMine ? null : c.responders.where((r) => r.id == msg.senderId).firstOrNull;
    final time = msg == null ? '' : '${msg.at.hour.toString().padLeft(2, '0')}:${msg.at.minute.toString().padLeft(2, '0')}';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
            color: Colors.white,
          ),
          child: Row(children: [
            if (msg != null && !msg.isMine)
              Avatar(name: msg.senderName, size: 42, color: sender == null ? AppColors.primary : Color(sender.color))
            else
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.primaryMist, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 19),
              ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(msg == null ? 'Chat de la alerta' : (msg.isMine ? 'Tú' : msg.senderName),
                    style: AppText.bodyStrong.copyWith(fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  msg?.body ?? 'Las aliadas que acepten podrán escribirte aquí.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(fontSize: 11.5),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(time, style: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 10, color: AppColors.primary)),
              const SizedBox(height: 5),
              if (c.unread > 0) UnreadBadge(count: c.unread),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg, required this.onTap, this.icon});
  final String label;
  final Color bg, fg;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.soft,
          ),
          child: TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              textStyle: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      );
}
