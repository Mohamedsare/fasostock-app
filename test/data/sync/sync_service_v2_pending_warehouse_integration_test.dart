import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fasostock/data/local/drift/app_database.dart';
import 'package:fasostock/data/sync/sync_service_v2.dart';

void main() {
  test('sync pushes warehouse pending action and marks it synced', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    Map<String, dynamic>? receivedPayload;
    final sync = SyncServiceV2(
      db,
      null,
      pushWarehouseSetThresholdOverride: (payload) async {
        receivedPayload = payload;
      },
    );

    await db.enqueuePendingAction(
      'warehouse_set_threshold',
      jsonEncode({
        'company_id': 'co_1',
        'product_id': 'prod_9',
        'min': 7,
      }),
    );

    final result = await sync.sync(
      userId: 'user_1',
      companyId: null,
      storeId: null,
    );

    expect(result.sent, 1);
    expect(result.errors, 0);
    expect(receivedPayload, isNotNull);
    expect(receivedPayload!['company_id'], 'co_1');
    expect(receivedPayload!['product_id'], 'prod_9');
    expect(receivedPayload!['min'], 7);

    final pending = await db.getPendingActions();
    expect(pending, isEmpty);
  });
}
