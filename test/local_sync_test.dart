import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dompet_harian_dukeduk/helpers/local_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores original transaction ID from old deterministic document', () {
    final row = LocalSync.normalizeCloud('transactions', 'user_tx_42', {
      'title': 'Pembayaran',
      'amount': 100,
      'category_id': 2,
    }, []);
    expect(row['id'], 42);
    expect(row['category_id'], 2);
    expect(LocalSync.documentId('user', 'transactions', row), 'user_tx_42');
  });

  test('legacy random category matches existing local ID by name', () {
    final row = LocalSync.normalizeCloud(
      'categories',
      'random-doc',
      {'name': 'Gaji', 'type': 'income'},
      [
        {'id': 1, 'name': 'Gaji'},
      ],
    );
    expect(row['id'], 1);
    expect(row['is_active'], true);
  });

  test(
    'unknown legacy IDs are stable and do not use the old small hash modulus',
    () {
      final a = LocalSync.normalizeCloud('transactions', 'random-a', {}, []);
      final b = LocalSync.normalizeCloud('transactions', 'random-b', {}, []);
      expect(a['id'], LocalSync.stableLegacyId('random-a'));
      expect(a['id'], isNegative);
      expect(a['id'], isNot(b['id']));
    },
  );

  test(
    'new IDs do not collide in a burst or exceed Android signed 64-bit storage',
    () {
      final ids = List.generate(1000, (_) => LocalSync.newId());
      expect(ids.toSet().length, ids.length);
      expect(ids.every((id) => id > 0 && id < 9223372036854775807), isTrue);
    },
  );

  test(
    'outbox retains changed rows and tombstones separately for each user',
    () async {
      SharedPreferences.setMockInitialValues({
        'transactions_data_a': jsonEncode([
          {'id': 1, 'amount': 10},
          {'id': 2, 'amount': 20},
        ]),
        'transactions_data_b': jsonEncode([
          {'id': 1, 'amount': 999},
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      await LocalSync.writeForUser(
        prefs,
        'a',
        'transactions_data_a',
        jsonEncode([
          {'id': 1, 'amount': 15},
        ]),
      );
      final outbox = jsonDecode(prefs.getString('sync_outbox_v1_a')!) as Map;
      expect(outbox['transactions']['1']['amount'], 15);
      expect(outbox['transactions']['2']['is_deleted'], true);
      expect(
        LocalSync.decode(prefs.getString('transactions_data_b'))
            .single['amount'],
        999,
      );
      expect(prefs.getString('sync_outbox_v1_b'), isNull);
    },
  );

  test('payment status is backed up inside its parent cloud record', () async {
    SharedPreferences.setMockInitialValues({
      'debts_data_a': jsonEncode([
        {'id': 1, 'lender_name': 'Bank'},
      ]),
      'debt_installments_data_a': jsonEncode([
        {'parent_id': 1, 'installment_number': 1, 'is_paid': false},
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    await LocalSync.writeForUser(
      prefs,
      'a',
      'debt_installments_data_a',
      jsonEncode([
        {
          'parent_id': 1,
          'installment_number': 1,
          'is_paid': true,
          'paid_date': '2026-11-01',
        },
      ]),
    );
    final outbox = jsonDecode(prefs.getString('sync_outbox_v1_a')!) as Map;
    expect(outbox['debts']['1']['installments'][0]['is_paid'], true);
  });

  test('recover interrupted financial action restores transaction and bill together', () async {
    final oldTx = jsonEncode([
      {'id': 1, 'amount': 100},
    ]);
    final oldBill = jsonEncode([
      {'parent_id': 1, 'is_paid': false},
    ]);
    SharedPreferences.setMockInitialValues({
      'transactions_data_a': '[]',
      'debt_installments_data_a': '[]',
      'sync_outbox_v1_a': '{"changed":true}',
      'financial_transaction_v1_a': jsonEncode({
        'transactions_data_a': oldTx,
        'debt_installments_data_a': oldBill,
        'sync_outbox_v1_a': null,
      }),
    });
    final prefs = await SharedPreferences.getInstance();
    await LocalSync.recoverTransaction(prefs, 'a');
    expect(prefs.getString('transactions_data_a'), oldTx);
    expect(prefs.getString('debt_installments_data_a'), oldBill);
    expect(prefs.getString('sync_outbox_v1_a'), isNull);
    expect(prefs.getString('financial_transaction_v1_a'), isNull);
  });

  test('serial actions remain ordered after a failed write', () async {
    final events = <int>[];
    final failed = LocalSync.serial(() async {
      events.add(1);
      throw StateError('disk');
    });
    final next = LocalSync.serial(() async {
      events.add(2);
    });
    await expectLater(failed, throwsStateError);
    await next;
    expect(events, [1, 2]);
  });
}
