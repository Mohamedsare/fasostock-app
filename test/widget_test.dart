// Smoke test : vérifie que le framework de test et un widget minimal fonctionnent.
// L'app complète (FasoStockApp) nécessite Supabase + providers ; testée manuellement / e2e.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test — widget minimal', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('FasoStock')),
        ),
      ),
    );
    expect(find.text('FasoStock'), findsOneWidget);
  });
}
