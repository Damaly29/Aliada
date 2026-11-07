import 'package:alaida/screens/educate_screen.dart';
import 'package:alaida/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Educate funciona como comunidad: reacciona, comenta y publica', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const Scaffold(body: EducateScreen())));
    await tester.pumpAndSettle();

    expect(find.text('Educate'), findsOneWidget);
    expect(find.text('Lo que están hablando'), findsOneWidget);
    expect(find.text('Julia Linarez'), findsWidgets);
    expect(tester.takeException(), isNull);

    // Publicar desde la comunidad.
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Hoy me sentí acompañada por mi red.');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publicar en la comunidad'));
    await tester.pumpAndSettle();
    expect(find.text('Hoy me sentí acompañada por mi red.'), findsOneWidget);

    // Me gusta la primera publicación de Julia (24 → 25).
    await tester.scrollUntilVisible(
      find.text('24'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('24'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('24'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
    expect(find.text('25'), findsOneWidget);

    // Comentar y ver el comentario dentro de la hoja.
    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Comentarios'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Gracias por compartir');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Gracias por compartir'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Encuesta: votar y verificar porcentajes (128 votos · 48%/31%/21%).
    await tester.scrollUntilVisible(
      find.text('Límites y consentimiento'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    // Antes de votar debe mostrar "Vota".
    expect(find.text('Vota'), findsOneWidget);
    // Tap sobre la primera opción de la encuesta.
    await tester.tap(find.text('Límites y consentimiento'));
    await tester.pumpAndSettle();
    // Después de votar debe mostrar "128 votos" y el porcentaje de la opción elegida.
    expect(find.text('128 votos'), findsOneWidget);
    expect(find.text('48%'), findsOneWidget);
    expect(find.text('31%'), findsOneWidget);
    expect(find.text('21%'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Guías como recurso, no como centro.
    await tester.scrollUntilVisible(
      find.text('Aprende en 4 minutos'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Aprende en 4 minutos'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('¿Esto cuenta como acoso?'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('¿Esto cuenta como acoso?'));
    await tester.pumpAndSettle();
    expect(find.text('Listo, gracias'), findsOneWidget);
    expect(find.text('Prefiero preguntarle a LumAI'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Espacios de la comunidad.
    await tester.scrollUntilVisible(
      find.text('Espacios de la comunidad'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Mentoras'), findsOneWidget);
    expect(find.text('Varones aliados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
