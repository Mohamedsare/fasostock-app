import 'package:flutter_test/flutter_test.dart';

import 'package:fasostock/data/models/sale.dart';
import 'package:fasostock/features/credit/credit_math.dart';

Sale _saleWithPayments({
  required double total,
  required List<SalePayment> payments,
}) {
  return Sale(
    id: 's1',
    companyId: 'c1',
    storeId: 'st1',
    customerId: 'cu1',
    saleNumber: 'V-1',
    status: SaleStatus.completed,
    total: total,
    createdBy: 'u1',
    createdAt: '2026-01-01T12:00:00.000Z',
    updatedAt: '2026-01-01T12:00:00.000Z',
    store: const StoreRef(id: 'st1', name: 'B'),
    customer: const CustomerRef(id: 'cu1', name: 'Client'),
    salePayments: payments,
    /// Évite « en retard » dans les tests (date fixe vs horloge réelle).
    creditDueAt: '2099-12-31T00:00:00.000Z',
  );
}

void main() {
  group('paidRealized / partiel POS', () {
    test('acompte sous PaymentMethod.other seul : compte comme encaissé', () {
      final s = _saleWithPayments(
        total: 500,
        payments: [
          SalePayment(
            id: 'p1',
            saleId: 's1',
            method: PaymentMethod.other,
            amount: 100,
            createdAt: '2026-01-01T12:00:00.000Z',
          ),
        ],
      );
      expect(paidRealized(s), closeTo(100, 0.001));
      expect(remainingTotal(s), closeTo(400, 0.001));
      expect(creditLineStatus(s), CreditLineStatus.partiel);
    });

    test('crédit total une ligne other = total : n’entre pas dans l’encaissé', () {
      final s = _saleWithPayments(
        total: 500,
        payments: [
          SalePayment(
            id: 'p1',
            saleId: 's1',
            method: PaymentMethod.other,
            amount: 500,
            reference: 'À crédit',
            createdAt: '2026-01-01T12:00:00.000Z',
          ),
        ],
      );
      expect(paidRealized(s), 0);
      expect(creditLineStatus(s), CreditLineStatus.nonPaye);
    });

    test('acompte cash + reliquat other : seul le cash compte', () {
      final s = _saleWithPayments(
        total: 500,
        payments: [
          SalePayment(
            id: 'p1',
            saleId: 's1',
            method: PaymentMethod.cash,
            amount: 100,
            createdAt: '2026-01-01T12:00:00.000Z',
          ),
          SalePayment(
            id: 'p2',
            saleId: 's1',
            method: PaymentMethod.other,
            amount: 400,
            createdAt: '2026-01-01T12:00:00.000Z',
          ),
        ],
      );
      expect(paidRealized(s), closeTo(100, 0.001));
      expect(creditLineStatus(s), CreditLineStatus.partiel);
    });
  });
}
