import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/cloud.dart';
import 'event_models.dart';
import 'events_repository.dart';

/// Estado de la pantalla de exploración de eventos.
class EventsController extends ChangeNotifier {
  EventsController({EventsRepository? repository}) : _repo = repository ?? EventsRepository.instance {
    Cloud.instance.clientReady.addListener(_onClientReady);
    Cloud.instance.ready.addListener(_onCloudChanged);
    if (Cloud.instance.configured) {
      unawaited(load());
    } else {
      _loading = false;
      _error = 'La cartelera de eventos no está configurada en esta compilación.';
    }
  }

  static const double nearbyRadiusMeters = 25000;

  final EventsRepository _repo;

  List<Event> _events = const [];
  bool _loading = true;
  bool _refreshing = false;
  bool _disposed = false;
  String? _error;
  String _search = '';
  DateTime? _day;
  LatLng? _position;
  String? _locationNotice;
  bool _locationPermanentlyDenied = false;
  bool _locationServiceDisabled = false;
  int _request = 0;

  bool get loading => _loading;
  bool get refreshing => _refreshing;
  bool get hasPosition => _position != null;
  bool get locationPermanentlyDenied => _locationPermanentlyDenied;
  bool get locationServiceDisabled => _locationServiceDisabled;
  bool get hasActiveFilters => _search.trim().isNotEmpty || _day != null;
  String? get error => _error;
  String? get locationNotice => _locationNotice;
  String get search => _search;
  DateTime? get day => _day;
  List<Event> get events => _events;

  /// Eventos recién publicados (ordenados por fecha de creación).
  List<Event> get latest {
    final list = _filtered.toList()
      ..sort((a, b) {
        final byCreated = b.createdAt.compareTo(a.createdAt);
        return byCreated != 0 ? byCreated : a.startAt.compareTo(b.startAt);
      });
    return list;
  }

  /// Eventos presenciales ordenados por distancia (o por fecha si no hay GPS).
  List<Event> get nearby {
    final position = _position;
    final list = _filtered.where((event) => event.modality == EventModality.presencial).toList();
    if (position == null) {
      list.sort(_upcomingFirst);
      return list;
    }

    final withDistance = <(Event, double)>[];
    for (final event in list) {
      final distance = event.distanceFrom(position);
      if (distance != null && distance <= nearbyRadiusMeters) {
        withDistance.add((event, distance));
      }
    }
    withDistance.sort((a, b) {
      if (a.$1.hasEnded != b.$1.hasEnded) return a.$1.hasEnded ? 1 : -1;
      return a.$2.compareTo(b.$2);
    });
    return withDistance.map((entry) => entry.$1).toList();
  }

  int _upcomingFirst(Event a, Event b) {
    if (a.hasEnded != b.hasEnded) return a.hasEnded ? 1 : -1;
    return a.startAt.compareTo(b.startAt);
  }

  double? distanceFor(Event event) {
    final position = _position;
    if (position == null) return null;
    return event.distanceFrom(position);
  }

  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    _notify();
  }

  void setDay(DateTime? value) {
    final normalized = value == null ? null : DateTime(value.year, value.month, value.day);
    if (_day == normalized) return;
    _day = normalized;
    _notify();
  }

  void clearFilters() {
    if (!hasActiveFilters) return;
    _search = '';
    _day = null;
    _notify();
  }

  Future<void> load({bool silent = false}) async {
    final request = ++_request;
    if (silent) {
      _refreshing = true;
    } else {
      _loading = true;
      _error = null;
      _notify();
    }

    try {
      unawaited(_resolvePosition().then((_) {
        if (!_disposed && request == _request) _notify();
      }));
      final events = await _repo.fetchEvents();
      if (_disposed || request != _request) return;
      _events = events;
      _error = null;
    } on EventsException catch (error) {
      if (_disposed || request != _request) return;
      _error = error.message;
    } catch (_) {
      if (_disposed || request != _request) return;
      _error = 'No pudimos cargar los eventos. Revisa tu conexión e inténtalo de nuevo.';
    } finally {
      if (!_disposed && request == _request) {
        _loading = false;
        _refreshing = false;
        _notify();
      }
    }
  }

  Future<void> refresh() async {
    await _reviveCloud();
    return load(silent: true);
  }

  Future<void> retry() async {
    await _reviveCloud();
    return load();
  }

  /// Si el arranque no alcanzó a inicializar Supabase (red, configuración),
  /// «Reintentar» vuelve a intentarlo antes de consultar la cartelera.
  Future<void> _reviveCloud() async {
    if (Cloud.instance.configured && !Cloud.instance.clientReady.value) {
      await Cloud.instance.init();
    }
  }

  Future<void> requestLocation() async {
    await _resolvePosition(request: true);
    _notify();
  }

  /// Pide el permiso o abre los ajustes del sistema cuando ya no se puede pedir.
  Future<void> enableLocation() async {
    if (_locationServiceDisabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    if (_locationPermanentlyDenied) {
      await Geolocator.openAppSettings();
      return;
    }
    await requestLocation();
  }

  Future<bool> toggleFavorite(Event event) async {
    final index = _events.indexWhere((item) => item.id == event.id);
    if (index < 0) return false;

    final previous = _events[index];
    final next = !previous.isFavorite;
    _events = List<Event>.of(_events)..[index] = previous.copyWith(isFavorite: next);
    _notify();

    try {
      await _repo.setFavorite(previous.id, next);
      return true;
    } catch (_) {
      if (!_disposed) {
        final currentIndex = _events.indexWhere((item) => item.id == previous.id);
        if (currentIndex >= 0) {
          _events = List<Event>.of(_events)..[currentIndex] = previous;
          _notify();
        }
      }
      return false;
    }
  }

  Future<void> _resolvePosition({bool request = false}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationServiceDisabled = true;
        _locationPermanentlyDenied = false;
        _locationNotice = 'Activa la ubicación de tu dispositivo para ver eventos cerca de ti.';
        return;
      }
      _locationServiceDisabled = false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && request) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _locationPermanentlyDenied = true;
        _locationNotice = 'Habilita la ubicación desde los ajustes del dispositivo para ordenar los eventos por distancia.';
        return;
      }
      _locationPermanentlyDenied = false;
      if (permission == LocationPermission.denied) {
        _locationNotice = 'Activa tu ubicación para ordenar los eventos por distancia.';
        return;
      }

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _position = LatLng(last.latitude, last.longitude);
      }

      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      _position = LatLng(current.latitude, current.longitude);
      _locationNotice = null;
    } catch (_) {
      _locationNotice = 'No pudimos obtener tu ubicación. Mostramos los eventos por fecha.';
    }
  }

  List<Event> get _filtered {
    final query = _normalize(_search.trim());
    return _events.where((event) {
      final matchesSearch = query.isEmpty ||
          _normalize(event.title).contains(query) ||
          _normalize(event.venue).contains(query) ||
          _normalize(event.address ?? '').contains(query) ||
          _normalize(event.organizer).contains(query);
      final matchesDay = _day == null || _sameDay(event.startAt, _day!);
      return matchesSearch && matchesDay;
    }).toList();
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _normalize(String input) {
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const to = 'aaaaaeeeeiiiiooooouuuunc';
    var result = input.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result;
  }

  void _onCloudChanged() {
    if (Cloud.instance.ready.value && _events.isEmpty && !_loading) {
      unawaited(load());
    }
  }

  /// El catálogo es público: si el cliente terminó de inicializarse después del
  /// primer intento, se recarga sin esperar a que la sesión esté lista.
  void _onClientReady() {
    if (Cloud.instance.clientReady.value && _events.isEmpty && !_loading) {
      unawaited(load());
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    Cloud.instance.clientReady.removeListener(_onClientReady);
    Cloud.instance.ready.removeListener(_onCloudChanged);
    super.dispose();
  }
}
