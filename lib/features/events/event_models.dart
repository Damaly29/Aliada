import 'package:latlong2/latlong.dart';

import '../../core/geo.dart';

/// Modalidad del evento.
enum EventModality { presencial, virtual }

/// Estado de la inscripción de la usuaria autenticada.
enum RegistrationState { confirmed, pendingPayment, cancelled }

/// Estado visual del botón principal del detalle.
enum EventCta { free, paid, pendingPayment, soldOut, registered, ended, unavailable }

/// Evento publicado en el módulo Edúcate.
class Event {
  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.organizer,
    required this.organizerBio,
    required this.startAt,
    required this.endAt,
    required this.venue,
    required this.address,
    required this.modality,
    required this.price,
    required this.capacity,
    required this.attendees,
    required this.createdAt,
    this.organizerAvatarUrl,
    this.registration,
    this.isFavorite = false,
    this.lat,
    this.lng,
  });

  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String category;
  final String organizer;
  final String? organizerAvatarUrl;
  final String? organizerBio;
  final DateTime startAt;
  final DateTime endAt;
  final String venue;
  final String? address;
  final EventModality modality;
  final double price;
  final int capacity;
  final int attendees;
  final DateTime createdAt;
  final RegistrationState? registration;
  final bool isFavorite;
  final double? lat;
  final double? lng;

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: _text(map['id'], fallback: ''),
      title: _text(map['titulo'], fallback: 'Evento'),
      description: _text(map['descripcion']),
      imageUrl: _nullableText(map['imagen_url']),
      category: _text(map['categoria'], fallback: 'Comunidad'),
      organizer: _text(map['organizador'], fallback: 'Aliada'),
      organizerAvatarUrl: _nullableText(map['organizador_avatar_url']),
      organizerBio: _nullableText(map['organizador_bio']),
      startAt: _dateOrNow(map['inicio']),
      endAt: _dateOrNow(map['fin']),
      venue: _text(map['lugar'], fallback: 'Por confirmar'),
      address: _nullableText(map['direccion']),
      modality: _text(map['modalidad']) == 'virtual' ? EventModality.virtual : EventModality.presencial,
      price: _double(map['precio']),
      capacity: _int(map['capacidad']),
      attendees: _int(map['asistentes']),
      createdAt: _dateOrNow(map['created_at']),
      registration: _registrationState(map['mi_estado']),
      isFavorite: map['es_favorito'] == true,
      lat: _doubleOrNull(map['lat']),
      lng: _doubleOrNull(map['lng']),
    );
  }

  bool get isFree => price <= 0;

  bool get hasEnded => !DateTime.now().isBefore(endAt);

  bool get isSoldOut => attendees >= capacity;

  bool get isRegistered => registration == RegistrationState.confirmed;

  bool get isPendingPayment => registration == RegistrationState.pendingPayment;

  int get spotsLeft => (capacity - attendees).clamp(0, capacity);

  String get priceLabel => isFree ? 'Gratuito' : 'S/ ${price.toStringAsFixed(2)}';

  String get modalityLabel => modality == EventModality.virtual ? 'Virtual' : 'Presencial';

  String get attendeesLabel => attendees == 1 ? '1 persona inscrita' : '$attendees personas inscritas';

  EventCta get cta {
    if (hasEnded) return EventCta.ended;
    if (isRegistered) return EventCta.registered;
    if (isSoldOut) return EventCta.soldOut;
    if (isPendingPayment) return EventCta.pendingPayment;
    return isFree ? EventCta.free : EventCta.paid;
  }

  String get ctaLabel => switch (cta) {
        EventCta.free => 'Inscribirme gratis',
        EventCta.paid => 'Comprar entrada $priceLabel',
        EventCta.pendingPayment => 'Completar pago',
        EventCta.soldOut => 'Cupos agotados',
        EventCta.registered => 'Ya estás inscrita',
        EventCta.ended => 'Evento finalizado',
        EventCta.unavailable => 'No disponible',
      };

  /// Distancia en metros desde una ubicación, si el evento tiene coordenadas.
  double? distanceFrom(LatLng origin) {
    final latitude = lat;
    final longitude = lng;
    if (latitude == null || longitude == null) return null;
    return metersBetween(origin, LatLng(latitude, longitude));
  }

  Event copyWith({
    bool? isFavorite,
    int? attendees,
    RegistrationState? registration,
  }) {
    return Event(
      id: id,
      title: title,
      description: description,
      imageUrl: imageUrl,
      category: category,
      organizer: organizer,
      organizerAvatarUrl: organizerAvatarUrl,
      organizerBio: organizerBio,
      startAt: startAt,
      endAt: endAt,
      venue: venue,
      address: address,
      modality: modality,
      price: price,
      capacity: capacity,
      attendees: attendees ?? this.attendees,
      createdAt: createdAt,
      registration: registration ?? this.registration,
      isFavorite: isFavorite ?? this.isFavorite,
      lat: lat,
      lng: lng,
    );
  }
}

/// Persona inscrita (solo se expone el primer nombre desde Supabase).
class EventAttendee {
  const EventAttendee({required this.name, this.joinedAt});

  final String name;
  final DateTime? joinedAt;

  factory EventAttendee.fromMap(Map<String, dynamic> map) {
    return EventAttendee(
      name: _text(map['nombre'], fallback: 'Estudiante'),
      joinedAt: _dateOrNull(map['created_at']),
    );
  }
}

// ───────────────────────── Formato en español ─────────────────────────

const _monthsShort = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'set', 'oct', 'nov', 'dic'];
const _monthsLong = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const _weekdaysShort = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _weekdaysLong = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

String formatEventDay(DateTime date) => '${date.day} ${_monthsShort[date.month - 1]}';

String formatEventMonthShort(DateTime date) => _monthsShort[date.month - 1];

String formatEventMonthYear(DateTime date) {
  final month = _monthsLong[date.month - 1];
  return '${month[0].toUpperCase()}${month.substring(1)} ${date.year}';
}

String formatEventDateLong(DateTime date) =>
    '${_weekdaysLong[date.weekday - 1]}, ${date.day} de ${_monthsLong[date.month - 1]} de ${date.year}';

String formatEventDateChip(DateTime date) =>
    '${_weekdaysShort[date.weekday - 1]}, ${date.day} ${_monthsShort[date.month - 1]}';

String formatEventTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'am' : 'pm'}';
}

String formatEventRange(Event event) => '${formatEventTime(event.startAt)} – ${formatEventTime(event.endAt)}';

String formatEventDistance(double meters) => meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)} km' : '${(meters / 10).round() * 10} m';

// ───────────────────────── Helpers de parseo ─────────────────────────

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double _double(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _doubleOrNull(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _dateOrNow(dynamic value) => _dateOrNull(value) ?? DateTime.now();

DateTime? _dateOrNull(dynamic value) {
  if (value is DateTime) return value.toLocal();
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

RegistrationState? _registrationState(dynamic value) {
  return switch (_text(value)) {
    'confirmada' => RegistrationState.confirmed,
    'pendiente_pago' => RegistrationState.pendingPayment,
    'cancelada' => RegistrationState.cancelled,
    _ => null,
  };
}
