import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fasostock/features/pos_quick/pos_quick_models.dart';
import 'package:fasostock/features/pos_quick/widgets/pos_quick_cart_tile.dart';

PosQuickCartTile _tile({
  required PosCartItem item,
  required int stock,
  required TextEditingController qtyController,
  void Function(int delta)? onQtyDelta,
  void Function(int value)? onSetQty,
  void Function()? onRemove,
  bool showQuantityInput = false,
  bool showQuantityButtons = true,
}) {
  return PosQuickCartTile(
    item: item,
    stock: stock,
    qtyController: qtyController,
    onQtyDelta: onQtyDelta ?? (_) {},
    onSetQty: onSetQty ?? (_) {},
    onRemove: onRemove ?? () {},
    showQuantityInput: showQuantityInput,
    showQuantityButtons: showQuantityButtons,
  );
}

void main() {
  group('PosQuickCartTile', () {
    testWidgets('displays item name, quantity and total', (WidgetTester tester) async {
      final item = PosCartItem(
        productId: 'p1',
        name: 'Café 250g',
        unit: 'pce',
        quantity: 2,
        unitPrice: 1500,
        total: 3000,
      );
      final ctrl = TextEditingController(text: '2');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _tile(item: item, stock: 10, qtyController: ctrl),
          ),
        ),
      );

      expect(find.text('Café 250g'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byType(PosQuickCartTile), findsOneWidget);
    });

    testWidgets('onQtyDelta(-1) when minus tapped', (WidgetTester tester) async {
      final item = PosCartItem(
        productId: 'p1',
        name: 'Thé',
        unit: 'pce',
        quantity: 2,
        unitPrice: 500,
        total: 1000,
      );
      int? lastDelta;
      final ctrl = TextEditingController(text: '2');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _tile(
              item: item,
              stock: 10,
              qtyController: ctrl,
              onQtyDelta: (delta) => lastDelta = delta,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();

      expect(lastDelta, -1);
    });

    testWidgets('onQtyDelta(1) when plus tapped', (WidgetTester tester) async {
      final item = PosCartItem(
        productId: 'p1',
        name: 'Thé',
        unit: 'pce',
        quantity: 1,
        unitPrice: 500,
        total: 500,
      );
      int? lastDelta;
      final ctrl = TextEditingController(text: '1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _tile(
              item: item,
              stock: 10,
              qtyController: ctrl,
              onQtyDelta: (delta) => lastDelta = delta,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();

      expect(lastDelta, 1);
    });

    testWidgets('onRemove when delete icon tapped', (WidgetTester tester) async {
      final item = PosCartItem(
        productId: 'p1',
        name: 'Sucre',
        unit: 'pce',
        quantity: 1,
        unitPrice: 200,
        total: 200,
      );
      bool removeCalled = false;
      final ctrl = TextEditingController(text: '1');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _tile(
              item: item,
              stock: 10,
              qtyController: ctrl,
              onRemove: () => removeCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pump();

      expect(removeCalled, true);
    });

    testWidgets('shows low stock warning when quantity > stock', (WidgetTester tester) async {
      final item = PosCartItem(
        productId: 'p1',
        name: 'Rare',
        unit: 'pce',
        quantity: 5,
        unitPrice: 100,
        total: 500,
      );
      final ctrl = TextEditingController(text: '5');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _tile(item: item, stock: 2, qtyController: ctrl),
          ),
        ),
      );

      expect(find.text('Stock: 2'), findsOneWidget);
    });
  });
}
