import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/cloud.dart';

class LumaiMessage {
  LumaiMessage.user(this.text)
      : fromLumai = false,
        reply = null;
  LumaiMessage.lumai(this.text, {this.reply}) : fromLumai = true;
  final String text;
  final bool fromLumai;
  final LumaiReply? reply;
}

class LumaiReply {
  LumaiReply({
    required this.respuesta,
    required this.riesgo,
    required this.necesidad,
    required this.derivacion,
    required this.acciones,
    this.model,
    this.promptVersion,
    this.fallback = false,
  });

  factory LumaiReply.fromJson(Map<String, dynamic> j) => LumaiReply(
        respuesta: j['respuesta'] as String? ?? '',
        riesgo: j['riesgo'] as String? ?? 'posible',
        necesidad: j['necesidad_detectada'] as String? ?? 'no_claro',
        derivacion: j['sugerir_derivacion'] as bool? ?? true,
        acciones: ((j['acciones_sugeridas'] as List?) ?? const []).whereType<String>().toList(),
        model: j['model'] as String?,
        promptVersion: j['prompt_version'] as String?,
        fallback: j['fallback'] as bool? ?? false,
      );

  /// Fallo seguro local (sin conexión): riesgo "posible" + derivación.
  factory LumaiReply.offline() => LumaiReply(
        respuesta: 'No tengo conexión para responderte ahora. Si lo necesitas, puedes hablar con una persona: '
            'Línea 100 (24 h) o Bienestar de tu universidad. Si estás en peligro, usa el botón de alerta o llama al 105.',
        riesgo: 'posible',
        necesidad: 'no_claro',
        derivacion: true,
        acciones: const ['contactar_bienestar', 'emergencia'],
        fallback: true,
      );

  final String respuesta;
  final String riesgo;
  final String necesidad;
  final bool derivacion;
  final List<String> acciones;
  final String? model;
  final String? promptVersion;
  final bool fallback;
}

/// Conversación con LumAI. El historial vive SOLO en este teléfono (memoria de la sesión);
/// el servidor recibe los últimos turnos para responder y descarta la conversación al terminar.
class LumaiService extends ChangeNotifier {
  LumaiService._();
  static final instance = LumaiService._();

  final List<LumaiMessage> messages = [];
  bool thinking = false;

  LumaiReply? get lastReply => messages.lastWhere((m) => m.fromLumai && m.reply != null, orElse: () => LumaiMessage.user('')).reply;

  Future<bool> enabled() async {
    if (!Cloud.instance.ready.value) return true; // sin red mostramos el chat con fallo seguro
    try {
      final r = await Cloud.instance.db.from('features').select('enabled').eq('key', 'lumai_chat').maybeSingle();
      return r == null ? true : (r['enabled'] as bool? ?? false);
    } catch (_) {
      return true;
    }
  }

  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || thinking) return;
    messages.add(LumaiMessage.user(t));
    thinking = true;
    notifyListeners();
    final reply = await _ask();
    messages.add(LumaiMessage.lumai(reply.respuesta, reply: reply));
    thinking = false;
    notifyListeners();
  }

  Future<LumaiReply> _ask() async {
    if (!Cloud.instance.ready.value) return LumaiReply.offline();
    final history = [
      for (final m in messages.where((m) => m.reply != null || !m.fromLumai))
        {'role': m.fromLumai ? 'model' : 'user', 'text': m.text},
    ];
    try {
      final id = await Cloud.instance.db.rpc('lumai_ask', params: {'p_messages': history});
      final deadline = DateTime.now().add(const Duration(seconds: 100));
      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 900));
        final r = Map<String, dynamic>.from(await Cloud.instance.db.rpc('lumai_result', params: {'p_id': id}) as Map);
        if (r['pending'] != true) return LumaiReply.fromJson(r);
      }
    } catch (_) {}
    return LumaiReply.offline();
  }

  /// Borra la conversación del teléfono. En el servidor no queda el contenido del chat.
  void clear() {
    messages.clear();
    thinking = false;
    notifyListeners();
  }

  /// Corrección o reporte. Se guarda ANONIMIZADO (sin usuaria; el servidor redacta correos/teléfonos/DNI).
  Future<bool> flag({required String tipo, required LumaiReply reply, String? comentario}) async {
    if (!Cloud.instance.ready.value) return false;
    try {
      await Cloud.instance.db.from('lumai_flags').insert({
        'tipo': tipo,
        'respuesta': reply.respuesta,
        'comentario': comentario,
        'riesgo': reply.riesgo,
        'model': reply.model,
        'prompt_version': reply.promptVersion,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
