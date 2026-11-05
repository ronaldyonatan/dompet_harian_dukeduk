import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dompet_harian_dukeduk/helpers/local_sync.dart';

class MemoryCloud extends SyncBackend {
  final records = <String, Map<String, Map<String, dynamic>>>{};
  bool failWrites = false;
  int writes = 0;
  @override
  Future<List<CloudRecord>> read(String collection, String uid) async =>
      (records[collection] ?? {}).entries
          .where((e) => e.value['user_id'] == uid)
          .map((e) => CloudRecord(e.key, Map.from(e.value)))
          .toList();
  @override
  Future<void> write(
    String collection,
    String id,
    Map<String, dynamic> data,
    List<String> aliases,
  ) async {
    if (failWrites) throw StateError('offline');
    writes++;
    final target = records.putIfAbsent(collection, () => {});
    target[id] = Map.from(data)..remove('updated_at');
    for (final alias in aliases) {
      target[alias]!['is_deleted'] = true;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late MemoryCloud cloud;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cloud = MemoryCloud();
  });

  test(
    'cloud restore merges partial backups without deleting local-only rows',
    () async {
      await prefs.setString(
        'transactions_data_a',
        jsonEncode([
          {'id': 1, 'title': 'Local', 'amount': 10},
        ]),
      );
      cloud.records['transactions'] = {
        'a_tx_2': {
          'user_id': 'a',
          'transaction_id': 2,
          'title': 'Cloud',
          'amount': 20,
        },
      };
      await LocalSync.syncUser('a', backend: cloud);
      final rows = LocalSync.decode(prefs.getString('transactions_data_a'));
      expect(rows.map((r) => r['id']).toSet(), {1, 2});
      expect(cloud.records['transactions']!['a_tx_1']!['transaction_id'], 1);
    },
  );

  test(
    'unsynced local edit wins over a stale cloud copy and upload is idempotent',
    () async {
      await prefs.setString(
        'transactions_data_a',
        jsonEncode([
          {'id': 1, 'amount': 10},
        ]),
      );
      await LocalSync.writeForUser(
        prefs,
        'a',
        'transactions_data_a',
        jsonEncode([
          {'id': 1, 'amount': 25},
        ]),
      );
      cloud.records['transactions'] = {
        'a_tx_1': {'user_id': 'a', 'transaction_id': 1, 'amount': 10},
      };
      await LocalSync.syncUser('a', backend: cloud);
      expect(cloud.records['transactions']!['a_tx_1']!['amount'], 25);
      expect(
        LocalSync.decode(prefs.getString('transactions_data_a'))
            .single['amount'],
        25,
      );
      final writes = cloud.writes;
      await LocalSync.syncUser('a', backend: cloud);
      expect(cloud.writes, writes);
      expect(cloud.records['transactions']!.length, 1);
    },
  );

  test(
    'deleted transaction stays deleted after repeated cloud restores',
    () async {
      await prefs.setString(
        'transactions_data_a',
        jsonEncode([
          {'id': 1, 'amount': 10},
        ]),
      );
      await LocalSync.writeForUser(prefs, 'a', 'transactions_data_a', '[]');
      cloud.records['transactions'] = {
        'a_tx_1': {'user_id': 'a', 'transaction_id': 1, 'amount': 10},
      };
      await LocalSync.syncUser('a', backend: cloud);
      await LocalSync.syncUser('a', backend: cloud);
      expect(LocalSync.decode(prefs.getString('transactions_data_a')), isEmpty);
      expect(cloud.records['transactions']!['a_tx_1']!['is_deleted'], true);
    },
  );

  test(
    'failed upload retains outbox and a later retry sends the edit',
    () async {
      await LocalSync.writeForUser(
        prefs,
        'a',
        'transactions_data_a',
        jsonEncode([
          {'id': 1, 'amount': 25},
        ]),
      );
      cloud.failWrites = true;
      await expectLater(
        LocalSync.syncUser('a', backend: cloud),
        throwsStateError,
      );
      expect(
        (jsonDecode(prefs.getString('sync_outbox_v1_a')!)
            as Map)['transactions']['1']['amount'],
        25,
      );
      expect(
        LocalSync.decode(prefs.getString('transactions_data_a'))
            .single['amount'],
        25,
      );
      cloud.failWrites = false;
      await LocalSync.syncUser('a', backend: cloud);
      expect(
        (jsonDecode(prefs.getString('sync_outbox_v1_a')!)
            as Map)['transactions'],
        isEmpty,
      );
      expect(cloud.records['transactions']!['a_tx_1']!['amount'], 25);
    },
  );

  test('restores debts and their paid installments on a new device', () async {
    cloud.records['debts'] = {
      'a_debt_1': {
        'user_id': 'a',
        'debt_id': 1,
        'lender_name': 'Bank',
        'installments': [
          {
            'parent_id': 1,
            'installment_number': 1,
            'is_paid': true,
            'paid_date': '2026-11-01',
          },
        ],
      },
    };
    await LocalSync.syncUser('a', backend: cloud);
    expect(LocalSync.decode(prefs.getString('debts_data_a')).single['id'], 1);
    expect(
      LocalSync.decode(prefs.getString('debt_installments_data_a'))
          .single['is_paid'],
      true,
    );
  });

  test(
    'canonical category wins over a historical duplicate tombstone',
    () async {
      cloud.records['categories'] = {
        'legacy': {
          'user_id': 'a',
          'id': 1,
          'name': 'Gaji',
          'type': 'income',
          'is_deleted': true,
        },
        'a_cat_1': {
          'user_id': 'a',
          'category_id': 1,
          'name': 'Gaji',
          'type': 'income',
        },
      };
      await LocalSync.syncUser('a', backend: cloud);
      expect(
        LocalSync.decode(prefs.getString('categories_data_a')).single['id'],
        1,
      );
    },
  );

  test(
    'clean install resolves legacy duplicate names using canonical cloud IDs',
    () async {
      cloud.records['categories'] = {
        'legacy-random-id': {'user_id': 'a', 'name': 'Gaji', 'type': 'income'},
        'a_cat_1': {'user_id': 'a', 'name': 'Gaji', 'type': 'income'},
      };
      await LocalSync.syncUser('a', backend: cloud);
      final rows = LocalSync.decode(prefs.getString('categories_data_a'));
      expect(rows.length, 1);
      expect(rows.single['id'], 1);
    },
  );

  test(
    'fresh empty cloud does not prevent initializing first-launch defaults',
    () async {
      await LocalSync.syncUser('a', backend: cloud);
      expect(prefs.containsKey('categories_data_a'), false);
      expect(prefs.containsKey('items_data_a'), false);
    },
  );

  test(
    'switching session aborts restore without applying another account data',
    () async {
      cloud.records['transactions'] = {
        'a_tx_1': {'user_id': 'a', 'transaction_id': 1, 'amount': 10},
      };
      await LocalSync.syncUser('a', backend: cloud, stillSignedIn: () => false);
      expect(prefs.getString('transactions_data_a'), isNull);
      expect(prefs.getString('transactions_data_b'), isNull);
    },
  );
}
