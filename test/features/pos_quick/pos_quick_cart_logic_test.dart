import 'package:flutter_test/flutter_test.dart';

import 'package:fasostock/features/pos_quick/pos_quick_models.dart';

void main() {
  group('PosQuickCartLogic.subtotal', () {
    test('empty cart returns 0', () {
      expect(PosQuickCartLogic.subtotal([]), 0.0);
    });

    test('single item returns item total', () {
      final cart = [
        PosCartItem(
          productId: 'p1',
          name: 'Produit A',
          unit: 'pce',
          quantity: 2,
          unitPrice: 100,
          total: 200,
        ),
      ];
      expect(PosQuickCartLogic.subtotal(cart), 200.0);
    });

    test('multiple items returns sum of totals', () {
      final cart = [
        PosCartItem(productId: 'p1', name: 'A', unit: 'pce', quantity: 1, unitPrice: 50, total: 50),
        PosCartItem(productId: 'p2', name: 'B', unit: 'pce', quantity: 3, unitPrice: 10, total: 30),
      ];
      expect(PosQuickCartLogic.subtotal(cart), 80.0);
    });
  });

  group('PosQuickCartLogic.totalWithDiscount', () {
    test('zero discount equals subtotal', () {
      final cart = [
        PosCartItem(productId: 'p1', name: 'A', unit: 'pce', quantity: 1, unitPrice: 100, total: 100),
      ];
      expect(PosQuickCartLogic.totalWithDiscount(cart, 0), 100.0);
    });

    test('discount reduces total', () {
      final cart = [
        PosCartItem(productId: 'p1', name: 'A', unit: 'pce', quantity: 1, unitPrice: 100, total: 100),
      ];
      expect(PosQuickCartLogic.totalWithDiscount(cart, 20), 80.0);
    });

    test('discount greater than subtotal clamps to 0', () {
      final cart = [
        PosCartItem(productId: 'p1', name: 'A', unit: 'pce', quantity: 1, unitPrice: 100, total: 100),
      ];
      expect(PosQuickCartLogic.totalWithDiscount(cart, 150), 0.0);
    });

    test('empty cart with discount returns 0', () {
      expect(PosQuickCartLogic.totalWithDiscount([], 10), 0.0);
    });
  });

  group('PosQuickCartLogic.canPay', () {
    test('empty cart returns false', () {
      expect(PosQuickCartLogic.canPay([], 0), false);
      expect(PosQuickCartLogic.canPay([], 100), false);
    });

    test('non-empty cart with total >= 0 returns true', () {
      final cart = [
        PosCartItem(productId: 'p1', name: 'A', unit: 'pce', quantity: 1, unitPrice: 100, total: 100),
      ];
      expect(PosQuickCartLogic.canPay(cart, 100), true);
      expect(PosQuickCartLogic.canPay(cart, 80), true); // after discount
    });

    test('non-empty cart with negative total returns false', () {
      final cart = [
        PosCartItem(productId: 'p1', name: 'A', unit: 'pce', quantity: 1, unitPrice: 100, total: 100),
      ];
      // total passed in can be negative if discount > subtotal (shouldn't happen in UI due to clamp)
      expect(PosQuickCartLogic.canPay(cart, -1), false);
    });
  });

  group('PosQuickCartLogic payment flow (regression)', () {
    test('cart with multiple items and discount: subtotal, total, canPay consistent', () {
      final cart = [
        PosCartItem(productId: 'p1', name: 'Article 1', unit: 'pce', quantity: 2, unitPrice: 500, total: 1000),
        PosCartItem(productId: 'p2', name: 'Article 2', unit: 'pce', quantity: 1, unitPrice: 300, total: 300),
      ];
      const discount = 100.0;

      final st = PosQuickCartLogic.subtotal(cart);
      final total = PosQuickCartLogic.totalWithDiscount(cart, discount);
      final canPay = PosQuickCartLogic.canPay(cart, total);

      expect(st, 1300.0);
      expect(total, 1200.0);
      expect(canPay, true);
      // Payment amount would be total (1200)
      expect(total, lessThanOrEqualTo(st));
      expect(total, greaterThanOrEqualTo(0));
    });
  });
}
