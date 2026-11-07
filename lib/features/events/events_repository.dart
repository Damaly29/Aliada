import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/cloud.dart';
import 'event_models.dart';

/// Error controlado para mostrar mensajes claros en la UI.
class EventsException implements Exception {
  const EventsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resultado de una inscripción gratuita.
enum RegistrationOutcome {
  confirmed,
  alreadyRegistered,
  soldOut,
  ended,
  requiresPayment,
  unavailable,
  notAuthenticated,
  error,
}

class RegistrationResult {
  const RegistrationResult(this.outcome, [this.message]);

  final RegistrationOutcome outcome;
  final String? message;
}

/// Acceso a Supabase para el catálogo de eventos, inscripciones y favoritos.
class EventsRepository {
  EventsRepository._();

  static final instance = EventsRepository._();

  SupabaseClient get _db => Cloud.instance.db;

  Future<List<Event>> fetchEvents({String? search, DateTime? day, String? eventId}) async {
    await _ensureClient();
    final response = await _db.rpc('events_feed', params: {
      'p_search': _clean(search),
      'p_day': day == null ? null : _dateOnly(day),
      'p_event': eventId,
    });
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map((row) => Event.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<Event?> fetchEvent(String eventId) async {
    final events = await fetchEvents(eventId: eventId);
    return events.isEmpty ? null : events.first;
  }

  Future<List<EventAttendee>> fetchAttendees(String eventId) async {
    await _ensureAuth();
    final response = await _db.rpc('event_attendees', params: {'p_event': eventId});
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map((row) => EventAttendee.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> setFavorite(String eventId, bool favorite) async {
    await _ensureAuth();
    final uid = Cloud.instance.uid;
    if (uid == null) {
      throw const EventsException('Inicia sesión para guardar tus eventos favoritos.');
    }

    if (favorite) {
      try {
        await _db.from('event_favorites').insert({'event_id': eventId, 'user_id': uid});
      } on PostgrestException catch (error) {
        // 23505 = ya estaba guardado. El estado optimista ya es el correcto.
        if (error.code != '23505') rethrow;
      }
    } else {
      await _db.from('event_favorites').delete().eq('event_id', eventId).eq('user_id', uid);
    }
  }

  Future<RegistrationResult> registerFree(String eventId) async {
    try {
      await _ensureAuth();
      final response = await _db.rpc('register_free_event', params: {'p_event': eventId});
      final code = response?.toString().trim() ?? '';
      final outcome = _outcome(code);
      if (code.isEmpty || outcome == RegistrationOutcome.error) {
        return const RegistrationResult(
          RegistrationOutcome.error,
          'No pudimos completar tu inscripción. Inténtalo de nuevo.',
        );
      }
      return RegistrationResult(outcome, code);
    } on EventsException catch (error) {
      return RegistrationResult(RegistrationOutcome.error, error.message);
    } on PostgrestException catch (_) {
      return const RegistrationResult(
        RegistrationOutcome.error,
        'No pudimos completar tu inscripción. Revisa tu conexión e inténtalo de nuevo.',
      );
    } catch (_) {
      return const RegistrationResult(
        RegistrationOutcome.error,
        'No pudimos completar tu inscripción. Revisa tu conexión e inténtalo de nuevo.',
      );
    }
  }

  /// Espera a que Supabase esté inicializado. El catálogo es público: no exige sesión.
  Future<void> _ensureClient() async {
    if (!Cloud.instance.configured) {
      throw const EventsException('La cartelera de eventos no está configurada en esta compilación.');
    }
    if (!Cloud.instance.clientReady.value) unawaited(Cloud.instance.init());
    await _waitFor(
      Cloud.instance.clientReady,
      'No pudimos conectar con los eventos. Revisa tu conexión e inténtalo de nuevo.',
    );
  }

  /// Espera a que la sesión de la usuaria esté lista (favoritos/inscripciones).
  Future<void> _ensureAuth() async {
    await _ensureClient();
    if (Cloud.instance.ready.value) return;
    unawaited(Cloud.instance.init());
    await _waitFor(
      Cloud.instance.ready,
      'No pudimos iniciar tu sesión. Revisa tu conexión e inténtalo de nuevo.',
    );
  }

  Future<void> _waitFor(ValueNotifier<bool> flag, String message) async {
    if (flag.value) return;

    final completer = Completer<void>();
    void onChange() {
      if (flag.value && !completer.isCompleted) completer.complete();
    }

    flag.addListener(onChange);
    if (flag.value && !completer.isCompleted) completer.complete();
    try {
      await completer.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw EventsException(message);
    } finally {
      flag.removeListener(onChange);
    }

    if (!flag.value) throw EventsException(message);
  }

  String? _clean(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  RegistrationOutcome _outcome(String code) {
    return switch (code) {
      'confirmada' => RegistrationOutcome.confirmed,
      'ya_inscrita' => RegistrationOutcome.alreadyRegistered,
      'agotado' => RegistrationOutcome.soldOut,
      'finalizado' => RegistrationOutcome.ended,
      'requiere_pago' => RegistrationOutcome.requiresPayment,
      'no_disponible' => RegistrationOutcome.unavailable,
      'no_autenticada' => RegistrationOutcome.notAuthenticated,
      _ => RegistrationOutcome.error,
    };
  }
}
