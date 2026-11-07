import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../features/alert/models.dart';
import '../features/lumai/lumai_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/emergency_links.dart';
import 'alert_screen.dart';

const lumaiAvatar = 'assets/images/luma_saludo.png';

/// LumAI: asistente de primera orientación. Orienta, informa y deriva; nunca decide ni diagnostica.
class LumaiScreen extends StatefulWidget {
  const LumaiScreen({super.key});
  @override
  State<LumaiScreen> createState() => _LumaiScreenState();
}

class _LumaiScreenState extends State<LumaiScreen> {
  final _s = LumaiService.instance;
  final _text = TextEditingController();
  final _scroll = ScrollController();
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _s.enabled().then((v) => mounted ? setState(() => _enabled = v) : null);
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? v]) {
    _s.send(v ?? _text.text);
    _text.clear();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar conversación?'),
        content: const Text('Se borrará de este teléfono. En el servidor no guardamos el contenido de tus chats con LumAI.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: AppColors.alertRed))),
        ],
      ),
    );
    if (ok == true) _s.clear();
  }

  @override
  Widget build(BuildContext context) {
    final consent = AppState.instance.lumaiConsent;
    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(children: [
          const CircleAvatar(radius: 18, backgroundColor: AppColors.lavenderChip, backgroundImage: AssetImage(lumaiAvatar)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('LumAI', style: AppText.h3.copyWith(color: AppColors.primary)),
            const Text('Asistente de primera orientación', style: AppText.caption),
          ]),
        ]),
        actions: [
          if (consent)
            IconButton(tooltip: 'Eliminar conversación', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded, color: AppColors.text)),
        ],
      ),
      body: !consent
          ? _Consent(onAccept: () => setState(() => AppState.instance.setLumaiConsent(true)))
          : _enabled == false
              ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('LumAI no está disponible por ahora. Si lo necesitas, habla con una persona: Línea 100.', textAlign: TextAlign.center)))
              : ListenableBuilder(listenable: _s, builder: (context, _) => _chat()),
    );
  }

  Widget _chat() {
    final last = _s.lastReply;
    final items = <Widget>[
      _Bubble.lumai(
        'Hola, soy LumAI 💜 Estoy aquí para escucharte y orientarte, sin juicios. '
        'Todo lo que me cuentes es confidencial.\n\n¿Qué necesitas ahora: información, acompañamiento, apoyo emocional o hacer un reporte?',
      ),
      for (final m in _s.messages)
        m.fromLumai ? _Bubble.lumai(m.text, reply: m.reply, onMenu: m.reply == null ? null : (a) => _onMenu(a, m.reply!)) : _Bubble.user(m.text),
      if (_s.thinking) const _Typing(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
    return Column(children: [
      _AiBanner(onHuman: () => showHumanHelp(context)),
      Expanded(child: ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), children: items)),
      if (last != null && last.riesgo == 'inmediato') _EmergencyCard(),
      if (last != null && last.riesgo != 'inmediato' && (last.riesgo == 'posible' || last.derivacion)) _DerivationCard(onYes: () => showHumanHelp(context)),
      _Chips(
        actions: _s.messages.isEmpty ? const ['_info', '_acomp', '_emocional', '_reporte'] : (last?.acciones ?? const []),
        onAction: _onChip,
      ),
      _Composer(controller: _text, onSend: _send, enabled: !_s.thinking),
    ]);
  }

  void _onChip(String a) {
    switch (a) {
      case '_info':
        _send('Necesito información');
      case '_acomp':
        _send('Necesito acompañamiento');
      case '_emocional':
        _send('Necesito apoyo emocional');
      case '_reporte':
        _send('Quiero saber cómo hacer un reporte');
      case 'ver_protocolo':
        _send('¿Cuál es el protocolo de mi universidad?');
      case 'iniciar_reporte':
        _send('¿Cómo podría iniciar un reporte? Aún no decido.');
      case 'solicitar_acompanamiento':
        _askCompanion();
      case 'contactar_psicologia':
      case 'contactar_bienestar':
        showHumanHelp(context);
      case 'emergencia':
        callNumber('105');
    }
  }

  Future<void> _askCompanion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Pedir compañía?'),
        content: const Text('Avisaremos en silencio (sin sirena) a aliadas disponibles cerca de ti y compartiremos tu ubicación con quienes acepten, solo durante la alerta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, pedir compañía')),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlertScreen(level: AlertLevel.companion)));
    }
  }

  Future<void> _onMenu(String action, LumaiReply r) async {
    String? comentario;
    if (action == 'correccion') {
      final c = TextEditingController();
      comentario = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Corregir respuesta'),
          content: TextField(controller: c, maxLines: 4, decoration: const InputDecoration(hintText: '¿Qué estuvo mal o qué esperabas?')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Enviar')),
          ],
        ),
      );
      if (comentario == null) return;
    }
    final ok = await _s.flag(tipo: action, reply: r, comentario: comentario);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Gracias. Lo revisará el equipo profesional (se guarda sin tus datos).' : 'No se pudo enviar ahora. Intenta más tarde.'),
    ));
  }
}

/// "Hablar con una persona". La derivación con resumen editable es el Módulo 2.
void showHumanHelp(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hablar con una persona', style: AppText.h3.copyWith(color: AppColors.primary)),
          const SizedBox(height: 4),
          const Text('Tú decides si quieres contacto humano y qué compartir. Esto no es un diagnóstico ni una decisión institucional.', style: AppText.caption),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.support_agent, color: AppColors.primary),
            title: const Text('Línea 100 · 24 horas'),
            subtitle: const Text('Orientación gratuita ante violencia familiar y sexual'),
            onTap: () => callNumber('100'),
          ),
          for (final (t, s) in const [
            ('Psicología', 'Atención psicológica de tu universidad'),
            ('Bienestar Universitario', 'Orientación y medidas de protección'),
            ('Defensoría Universitaria', 'Canal institucional de quejas y derechos'),
          ])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_balance_outlined, color: AppColors.primary),
              title: Text(t),
              subtitle: Text('$s · DEMO: falta configurar el contacto real'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Pronto podrás enviar tu solicitud eligiendo qué compartir. Por ahora, llama a la Línea 100 o acude a tu universidad.'),
                ));
              },
            ),
        ]),
      ),
    ),
  );
}

class _Consent extends StatelessWidget {
  const _Consent({required this.onAccept});
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    Widget row(IconData i, Color c, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, color: c, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: AppText.body)),
          ]),
        );
    return ListView(padding: const EdgeInsets.all(20), children: [
      Center(child: Image.asset('assets/images/luma_hola.png', height: 170)),
      const SizedBox(height: 12),
      Text('Hola, soy LumAI', textAlign: TextAlign.center, style: AppText.h2.copyWith(color: AppColors.primary)),
      const SizedBox(height: 6),
      const Text('Usarme es opcional. Antes de empezar, esto es lo que hago y lo que no:', textAlign: TextAlign.center, style: AppText.caption),
      const SizedBox(height: 18),
      Text('Puedo', style: AppText.bodyStrong.copyWith(color: AppColors.primary)),
      const SizedBox(height: 8),
      row(Icons.check_circle_outline, const Color(0xFF3D9970), 'Escucharte y orientarte sin juicios.'),
      row(Icons.check_circle_outline, const Color(0xFF3D9970), 'Explicarte qué es consentimiento, acoso u hostigamiento y qué canales existen.'),
      row(Icons.check_circle_outline, const Color(0xFF3D9970), 'Ayudarte a ordenar lo que pasó, solo si tú me lo pides.'),
      row(Icons.check_circle_outline, const Color(0xFF3D9970), 'Conectarte con una persona capacitada.'),
      const SizedBox(height: 8),
      Text('No hago', style: AppText.bodyStrong.copyWith(color: AppColors.alertRed)),
      const SizedBox(height: 8),
      row(Icons.block, AppColors.alertRed, 'No decido si algo fue hostigamiento ni juzgo si tu relato es creíble.'),
      row(Icons.block, AppColors.alertRed, 'No diagnostico ni reemplazo a una profesional.'),
      row(Icons.block, AppColors.alertRed, 'No envío reportes ni comparto tus datos sin tu permiso.'),
      row(Icons.block, AppColors.alertRed, 'No respondo emergencias: para eso está el botón de alerta, el 105 y la Línea 100.'),
      const SizedBox(height: 8),
      Text('Tus datos', style: AppText.bodyStrong.copyWith(color: AppColors.primary)),
      const SizedBox(height: 8),
      row(Icons.lock_outline, AppColors.primary, 'La conversación se guarda solo en este teléfono y puedes eliminarla cuando quieras.'),
      row(Icons.lock_outline, AppColors.primary, 'Para responderte, tus mensajes pasan por un modelo de IA (Google Gemini) y no se guardan en nuestro servidor.'),
      row(Icons.lock_outline, AppColors.primary, 'Nunca usamos tus conversaciones para entrenar ni para la base de conocimiento.'),
      const SizedBox(height: 16),
      AppButton(label: 'Entiendo, empezar', onPressed: onAccept),
      const SizedBox(height: 8),
      AppButton(label: 'Ahora no', variant: AppButtonVariant.ghost, onPressed: () => Navigator.pop(context)),
    ]);
  }
}

class _AiBanner extends StatelessWidget {
  const _AiBanner({required this.onHuman});
  final VoidCallback onHuman;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: AppColors.lavenderChip,
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(children: [
          const Icon(Icons.auto_awesome_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Esta respuesta fue generada por IA y puede contener errores. Si deseas, puedes hablar con una persona capacitada.',
                style: TextStyle(fontFamily: AppFonts.ui, fontSize: 11, color: AppColors.text)),
          ),
          TextButton(
            onPressed: onHuman,
            style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            child: const Text('Hablar con\nuna persona', textAlign: TextAlign.center),
          ),
        ]),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble.user(this.text)
      : mine = true,
        reply = null,
        onMenu = null;
  const _Bubble.lumai(this.text, {this.reply, this.onMenu}) : mine = false;
  final String text;
  final bool mine;
  final LumaiReply? reply;
  final void Function(String action)? onMenu;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.74),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: mine ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(mine ? 14 : 2),
          bottomRight: Radius.circular(mine ? 2 : 14),
        ),
        boxShadow: AppShadows.card,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(text, style: AppText.body.copyWith(color: mine ? Colors.white : AppColors.text)),
          ),
        ),
        if (onMenu != null)
          SizedBox(
            width: 26,
            height: 26,
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              iconSize: 18,
              icon: const Icon(Icons.more_vert, color: AppColors.gray),
              onSelected: onMenu,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'correccion', child: Text('Corregir respuesta')),
                PopupMenuItem(value: 'danina', child: Text('Reportar respuesta dañina')),
              ],
            ),
          ),
      ]),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            const CircleAvatar(radius: 15, backgroundColor: AppColors.lavenderChip, backgroundImage: AssetImage(lumaiAvatar)),
            const SizedBox(width: 6),
          ],
          bubble,
        ],
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Row(children: [
          CircleAvatar(radius: 15, backgroundColor: AppColors.lavenderChip, backgroundImage: AssetImage(lumaiAvatar)),
          SizedBox(width: 8),
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
          SizedBox(width: 8),
          Text('LumAI está escribiendo…', style: AppText.caption),
        ]),
      );
}

class _EmergencyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.alertRed, borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('¿Estás en peligro ahora?', style: TextStyle(fontFamily: AppFonts.title, fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('La alerta comparte tu ubicación con aliadas cercanas y tu contacto de emergencia. LumAI no puede ir hasta ti.',
              style: TextStyle(fontFamily: AppFonts.ui, fontSize: 12, color: Colors.white)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.alertRed),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlertScreen(level: AlertLevel.emergency))),
                child: const Text('ACTIVAR ALERTA', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
              onPressed: () => callNumber('105'),
              child: const Text('105'),
            ),
            const SizedBox(width: 6),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
              onPressed: () => callNumber('100'),
              child: const Text('100'),
            ),
          ]),
        ]),
      );
}

class _DerivationCard extends StatelessWidget {
  const _DerivationCard({required this.onYes});
  final VoidCallback onYes;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withValues(alpha: 0.4))),
        child: Row(children: [
          const Icon(Icons.volunteer_activism_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('¿Quieres hablar con una persona? Es una recomendación, no un diagnóstico ni una decisión institucional.',
                style: TextStyle(fontFamily: AppFonts.ui, fontSize: 12, color: AppColors.text)),
          ),
          TextButton(onPressed: onYes, child: const Text('Sí, quiero')),
        ]),
      );
}

class _Chips extends StatelessWidget {
  const _Chips({required this.actions, required this.onAction});
  final List<String> actions;
  final ValueChanged<String> onAction;

  static const _labels = {
    '_info': 'Información',
    '_acomp': 'Acompañamiento',
    '_emocional': 'Apoyo emocional',
    '_reporte': 'Hacer un reporte',
    'ver_protocolo': 'Ver protocolo',
    'solicitar_acompanamiento': 'Pedir compañía',
    'contactar_psicologia': 'Hablar con psicología',
    'contactar_bienestar': 'Hablar con Bienestar',
    'iniciar_reporte': '¿Cómo reportar?',
    'emergencia': 'Llamar al 105',
  };

  @override
  Widget build(BuildContext context) {
    final list = actions.where(_labels.containsKey).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text(_labels[list[i]]!),
          onPressed: () => onAction(list[i]),
          backgroundColor: list[i] == 'emergencia' ? AppColors.alertRed.withValues(alpha: 0.1) : Colors.white,
          side: BorderSide(color: list[i] == 'emergencia' ? AppColors.alertRed : AppColors.primary.withValues(alpha: 0.4)),
          labelStyle: TextStyle(color: list[i] == 'emergencia' ? AppColors.alertRed : AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend, required this.enabled});
  final TextEditingController controller;
  final void Function([String?]) onSend;
  final bool enabled;
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Escribe a LumAI…',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            IconButton.filled(
              onPressed: enabled ? () => onSend() : null,
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ]),
        ),
      );
}
