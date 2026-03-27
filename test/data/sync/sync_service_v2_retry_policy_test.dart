import 'package:flutter_test/flutter_test.dart';
import 'package:fasostock/data/sync/sync_service_v2.dart';

void main() {
  group('SyncServiceV2 retry delay policy', () {
    test('returns zero for first attempt', () {
      expect(SyncServiceV2.retryDelayMsForFailCount(0), 0);
      expect(SyncServiceV2.retryDelayMsForFailCount(-1), 0);
    });

    test('grows exponentially then caps at max delay', () {
      expect(SyncServiceV2.retryDelayMsForFailCount(1), 1500);
      expect(SyncServiceV2.retryDelayMsForFailCount(2), 3000);
      expect(SyncServiceV2.retryDelayMsForFailCount(3), 6000);
      expect(SyncServiceV2.retryDelayMsForFailCount(4), 12000);
      expect(SyncServiceV2.retryDelayMsForFailCount(5), 24000);
      expect(SyncServiceV2.retryDelayMsForFailCount(9), 300000);
      expect(SyncServiceV2.retryDelayMsForFailCount(20), 300000);
    });
  });
}
