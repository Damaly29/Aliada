import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alaida/features/events/event_models.dart';
import 'package:alaida/screens/event_detail_screen.dart';
import 'package:alaida/screens/events_screen.dart';
import 'package:alaida/widgets/event_card.dart';
import 'package:alaida/widgets/event_checkout_sheet.dart';
import 'package:alaida/widgets/event_date_picker.dart';

Event _event({bool free = true, bool ended = false}) {
  final base = ended ? DateTime.now().subtract(const Duration(days: 6)) : DateTime.now().add(const Duration(days: 3));
  return Event(
    id: '11111111-1111-4111-8111-111111111111',
    title: 'Feria de Bienestar Universitario',
    description:
        'Un día para conocer los servicios de bienestar, participar en actividades al aire libre y conectar con otras estudiantes. '
        'Habrá stands informativos, espacios de descanso y actividades de autocuidado para toda la comunidad.',
    imageUrl: null,
    category: 'Bienestar',
    organizer: 'Bienestar Universitario',
    organizerBio: 'Acompañamos a las estudiantes con orientación, prevención y espacios de cuidado.',
    startAt: base,
    endAt: base.add(const Duration(hours: 4)),
    venue: 'Explanada Central',
    address: 'Campus Central, Lima',
    modality: EventModality.presencial,
    price: free ? 0 : 25,
    capacity: 150,
    attendees: 23,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  );
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapOpenSheet(WidgetTester tester, String label, Future<void> Function(BuildContext) open) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => open(context),
              child: Text(label),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tarjeta de evento se adapta al carrusel y al listado', (tester) async {
    await _phone(tester);
    final event = _event();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 330,
              height: 366,
              child: EventCard(
                event: event,
                compact: true,
                onTap: () {},
                onToggleFavorite: () {},
                onShare: () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text(event.title), findsOneWidget);
    expect(find.text('Gratuito'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              EventCard(
                event: event,
                onTap: () {},
                onToggleFavorite: () {},
                onShare: () {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pantalla de eventos muestra estado sin backend', (tester) async {
    await _phone(tester);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EventsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edúcate'), findsOneWidget);
    expect(find.text('Eventos'), findsOneWidget);
    expect(find.text('Buscar por nombre o lugar'), findsOneWidget);
    expect(find.text('No pudimos cargar los eventos'), findsOneWidget);
    expect(find.text('Ver eventos de ejemplo'), findsNothing);
    expect(find.textContaining('eventos de ejemplo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detalle de evento muestra info, asistentes y CTA', (tester) async {
    await _phone(tester);
    final event = _event();

    await tester.pumpWidget(
      MaterialApp(home: EventDetailScreen(event: event)),
    );
    await tester.pumpAndSettle();

    expect(find.text(event.title), findsOneWidget);
    expect(find.text('Sobre el evento'), findsOneWidget);
    expect(find.text('Inscribirme gratis'), findsOneWidget);
    expect(find.text('23 personas inscritas'), findsWidgets);
    expect(find.text('Cupos disponibles'), findsOneWidget);
    expect(find.text('127 de 150'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detalle de evento finalizado muestra CTA deshabilitado', (tester) async {
    await _phone(tester);
    final event = _event(ended: true);

    await tester.pumpWidget(
      MaterialApp(home: EventDetailScreen(event: event)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evento finalizado'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton).last);
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selector de fecha abre y permite aplicar un día', (tester) async {
    await _phone(tester);

    await _tapOpenSheet(tester, 'Abrir calendario', (context) async {
      final selection = await showEventDatePicker(context);
      expect(selection, isNotNull);
    });

    expect(find.text('Filtrar por fecha'), findsOneWidget);
    expect(find.text('Aplicar'), findsOneWidget);

    await tester.tap(find.text('${DateTime.now().day}').first);
    await tester.pump();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.text('Filtrar por fecha'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout de pago se muestra sin confirmar la inscripción', (tester) async {
    await _phone(tester);
    final event = _event(free: false);

    await _tapOpenSheet(tester, 'Comprar', (context) => showEventCheckoutSheet(context, event));

    expect(find.text('Confirmar compra'), findsOneWidget);
    expect(find.text('Método de pago'), findsOneWidget);
    expect(find.text('Yape'), findsOneWidget);
    expect(find.textContaining('no está conectada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
