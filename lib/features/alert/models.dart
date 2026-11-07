import 'package:latlong2/latlong.dart';

enum AlertStatus { active, safe, cancelled }

/// 🟡 compañía (sin sirena, solo aliadas) · 🔴 emergencia (flujo SOS completo).
enum AlertLevel { companion, emergency }

String firstName(String full) => full.trim().split(RegExp(r'\s+')).first;

enum ResponderStatus { notified, enCamino, llego, rechazo }

class Responder {
  Responder({required this.id, required this.nombre, required this.position, required this.color, this.status = ResponderStatus.notified});
  final String id;
  final String nombre;
  LatLng position;
  ResponderStatus status;
  final int color;
}

class ChatMessage {
  ChatMessage({required this.senderId, required this.senderName, required this.body, DateTime? at}) : at = at ?? DateTime.now();
  final String senderId;
  final String senderName;
  final String body;
  final DateTime at;
  bool get isMine => senderId == 'me';
}
