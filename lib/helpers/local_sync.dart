import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A durable per-user outbox. Financial data remains local when offline;
/// only acknowledged changes leave the outbox. Existing storage keys are kept.
class LocalSync {
  static const collections = [
    'categories',
    'items',
    'transactions',
    'budgets',
    'customers',
    'lenders',
    'debts',
    'receivables',
  ];
  static final _random = Random.secure();
  static int _lastId = 0;
  static Future<void> _tail = Future.value();
  static Future<void>? _syncing;
  static String? lastError;

  static Future<T> serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  // Millisecond time plus random bits fits in a signed 64-bit integer and
  // avoids reusing deleted IDs or allocating the same counter on two devices.
  static int newId() {
    final candidate =
        DateTime.now().millisecondsSinceEpoch * 1000000 +
        _random.nextInt(1000000);
    _lastId = candidate > _lastId ? candidate : _lastId + 1;
    return _lastId;
  }

  static String identity(String collection, Map<String, dynamic> row) =>
      collection == 'budgets'
      ? '${row['category_id']}_${row['year']}_${row['month']}'
      : '${row['id']}';

  static String documentId(
    String uid,
    String collection,
    Map<String, dynamic> row,
  ) {
    final id = identity(collection, row);
    final prefix = {
      'categories': 'cat',
      'items': 'item',
      'transactions': 'tx',
      'customers': 'customer',
      'lenders': 'lender',
      'debts': 'debt',
      'receivables': 'receivable',
    }[collection];
    return collection == 'budgets' ? '${uid}_cat$id' : '${uid}_${prefix}_$id';
  }

  static List<Map<String, dynamic>> decode(String? value) => value == null
      ? []
      : (jsonDecode(value) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

  static Map<String, dynamic> _outbox(SharedPreferences prefs, String uid) =>
      Map<String, dynamic>.from(
        jsonDecode(prefs.getString('sync_outbox_v1_$uid') ?? '{}') as Map,
      );

  static Future<bool> isEnabled() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('cloud_sync_enabled_$uid') ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await serial(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('cloud_sync_enabled_$uid', enabled);
    });
  }

  /// Run inside serial(). A crash or exception rolls back the complete local
  /// financial action (including its outbox), so payment and transaction status
  /// cannot diverge between preference writes.
  static Future<T> transaction<T>(Future<T> Function() action) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Silakan masuk kembali sebelum menyimpan data.');
    }
    final prefs = await SharedPreferences.getInstance();
    final keys = [
      for (final c in collections) '${c}_data_$uid',
      'debt_installments_data_$uid',
      'receivable_installments_data_$uid',
      'sync_outbox_v1_$uid',
    ];
    final backup = {for (final key in keys) key: prefs.getString(key)};
    await prefs.setString('financial_transaction_v1_$uid', jsonEncode(backup));
    try {
      final result = await action();
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        throw StateError('Sesi akun berubah. Silakan coba kembali.');
      }
      await prefs.remove('financial_transaction_v1_$uid');
      return result;
    } catch (_) {
      await recoverTransaction(prefs, uid);
      rethrow;
    }
  }

  static Future<void> recoverTransaction(
    SharedPreferences prefs,
    String uid,
  ) async {
    final marker = prefs.getString('financial_transaction_v1_$uid');
    if (marker == null) return;
    final backup = Map<String, dynamic>.from(jsonDecode(marker) as Map);
    for (final entry in backup.entries) {
      if (entry.value == null) {
        await prefs.remove(entry.key);
      } else {
        await prefs.setString(entry.key, entry.value as String);
      }
    }
    await prefs.remove('financial_transaction_v1_$uid');
  }

  /// Called within serial(), before publishing the local write.
  static Future<void> write(
    SharedPreferences prefs,
    String key,
    String value,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      await prefs.setString(key, value);
      return;
    }
    await writeForUser(prefs, uid, key, value);
  }

  static Future<void> writeForUser(
    SharedPreferences prefs,
    String uid,
    String key,
    String value,
  ) async {
    final collection = collections
        .where((c) => key == '${c}_data_$uid')
        .firstOrNull;
    final type = key == 'debt_installments_data_$uid'
        ? 'debts'
        : key == 'receivable_installments_data_$uid'
        ? 'receivables'
        : null;
    final outbox = _outbox(prefs, uid);
    if (collection != null) {
      final before = {
        for (final r in decode(prefs.getString(key)))
          identity(collection, r): r,
      };
      final after = {for (final r in decode(value)) identity(collection, r): r};
      final changes = Map<String, dynamic>.from(
        outbox[collection] as Map? ?? {},
      );
      for (final entry in after.entries) {
        if (jsonEncode(before[entry.key]) != jsonEncode(entry.value)) {
          changes[entry.key] = entry.value;
        }
      }
      for (final entry in before.entries) {
        if (!after.containsKey(entry.key)) {
          changes[entry.key] = {...entry.value, 'is_deleted': true};
        }
      }
      outbox[collection] = changes;
    } else if (type != null) {
      final changes = Map<String, dynamic>.from(outbox[type] as Map? ?? {});
      final installments = decode(value);
      final old = decode(prefs.getString(key));
      final parents = {
        ...old.map((r) => r['parent_id']),
        ...installments.map((r) => r['parent_id']),
      };
      for (final row in decode(prefs.getString('${type}_data_$uid'))) {
        if (parents.contains(row['id'])) {
          changes[identity(type, row)] = {
            ...row,
            'installments': installments
                .where((r) => r['parent_id'] == row['id'])
                .toList(),
          };
        }
      }
      outbox[type] = changes;
    }
    // Journal first, so a killed process cannot lose an unsynced financial edit.
    await prefs.setString('sync_outbox_v1_$uid', jsonEncode(outbox));
    await prefs.setString(key, value);
  }

  static void syncInBackground() {
    unawaited(
      sync().catchError((Object e) {
        lastError = e.toString();
        debugPrint('Cloud sync pending: $e');
      }),
    );
  }

  static Future<void> sync() {
    if (_syncing != null) return _syncing!;
    final future = serial(_sync);
    _syncing = future;
    return future.whenComplete(() => _syncing = null);
  }

  static Future<void> _sync() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !await isEnabled()) return;
    final prefs = await SharedPreferences.getInstance();
    await recoverTransaction(prefs, uid);
    final outbox = _outbox(prefs, uid);
    if (!(prefs.getBool('sync_migrated_v1_$uid') ?? false)) {
      final backup = <String, dynamic>{};
      for (final c in collections) {
        final rows = decode(prefs.getString('${c}_data_$uid'));
        backup[c] = rows;
        // First upgrade preserves existing local rows, including changes made
        // by older versions without an outbox.
        final changes = Map<String, dynamic>.from(outbox[c] as Map? ?? {});
        for (final row in rows) {
          changes.putIfAbsent(identity(c, row), () => row);
        }
        outbox[c] = changes;
      }
      for (final type in ['debt', 'receivable']) {
        backup['${type}_installments'] = decode(
          prefs.getString('${type}_installments_data_$uid'),
        );
      }
      await prefs.setString('pre_sync_backup_v1_$uid', jsonEncode(backup));
      await prefs.setString('sync_outbox_v1_$uid', jsonEncode(outbox));
      await prefs.setBool('sync_migrated_v1_$uid', true);
    }

    await syncUser(
      uid,
      backend: FirestoreSyncBackend(),
      stillSignedIn: () => FirebaseAuth.instance.currentUser?.uid == uid,
    );
  }

  /// Separated transport allows full migration/retry tests without touching a
  /// live Firebase project. Call under serial() in production.
  static Future<void> syncUser(
    String uid, {
    required SyncBackend backend,
    bool Function()? stillSignedIn,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final outbox = _outbox(prefs, uid);
    for (final collection in collections) {
      if (stillSignedIn != null && !stillSignedIn()) return;
      final remote = await backend.read(collection, uid);
      if (stillSignedIn != null && !stillSignedIn()) return;
      final localKey = '${collection}_data_$uid';
      final local = decode(prefs.getString(localKey));
      final merged = <String, Map<String, dynamic>>{};
      final aliases = <String, List<String>>{};
      // Prefer canonical documents over legacy randomly named duplicates.
      final docs = remote.toList()
        ..sort((a, b) {
          final aCanonical = a.id.startsWith('${uid}_');
          final bCanonical = b.id.startsWith('${uid}_');
          return (aCanonical ? 1 : 0).compareTo(bCanonical ? 1 : 0);
        });
      // Legacy random category/item documents omitted their numeric ID.
      // Resolve them against canonical cloud rows as well as local rows, so a
      // clean installation does not restore duplicate names with new IDs.
      final knownRows = [...local];
      if (collection == 'categories' || collection == 'items') {
        final field = collection == 'categories' ? 'category_id' : 'item_id';
        final prefix = collection == 'categories' ? 'cat' : 'item';
        for (final doc in docs) {
          if (doc.id.startsWith('${uid}_${prefix}_') ||
              doc.data['id'] != null ||
              doc.data[field] != null) {
            knownRows.add(normalizeCloud(collection, doc.id, doc.data, local));
          }
        }
      }
      for (final doc in docs) {
        final row = normalizeCloud(collection, doc.id, doc.data, knownRows);
        final id = identity(collection, row);
        merged[id] = row;
        (aliases[id] ??= []).add(doc.id);
      }
      // Preserve device-only data even when the cloud has a partial backup.
      for (final row in local) {
        merged.putIfAbsent(identity(collection, row), () => row);
      }
      final changes = Map<String, dynamic>.from(
        outbox[collection] as Map? ?? {},
      );
      // A legacy upload may omit defaults/items altogether. Upload missing
      // records without overwriting records already present remotely.
      for (final row in local) {
        final id = identity(collection, row);
        if (!aliases.containsKey(id)) changes.putIfAbsent(id, () => row);
      }
      for (final entry in changes.entries.toList()) {
        final row = Map<String, dynamic>.from(entry.value as Map);
        if (collection == 'debts' || collection == 'receivables') {
          final type = collection == 'debts' ? 'debt' : 'receivable';
          row['installments'] = decode(
            prefs.getString('${type}_installments_data_$uid'),
          ).where((r) => r['parent_id'] == row['id']).toList();
        }
        final canonical = documentId(uid, collection, row);
        final cloud = {
          ...row,
          'user_id': uid,
          'updated_at': FieldValue.serverTimestamp(),
        };
        final idField = {
          'categories': 'category_id',
          'items': 'item_id',
          'transactions': 'transaction_id',
          'customers': 'customer_id',
          'lenders': 'lender_id',
          'debts': 'debt_id',
          'receivables': 'receivable_id',
        }[collection];
        if (idField != null) cloud[idField] = row['id'];
        await backend.write(
          collection,
          canonical,
          cloud,
          (aliases[entry.key] ?? <String>[])
              .where((alias) => alias != canonical)
              .toList(),
        );
        merged[entry.key] = row;
        changes.remove(entry.key); // persisted below only after acknowledgment
        outbox[collection] = changes;
        await prefs.setString('sync_outbox_v1_$uid', jsonEncode(outbox));
      }
      final rows = merged.values.where((r) => r['is_deleted'] != true).toList();
      if (rows.isNotEmpty || prefs.containsKey(localKey) || remote.isNotEmpty) {
        await prefs.setString(
          localKey,
          jsonEncode(
            rows
                .map(
                  (r) => Map<String, dynamic>.from(r)..remove('installments'),
                )
                .toList(),
          ),
        );
      }
      if (collection == 'debts' || collection == 'receivables') {
        final type = collection == 'debts' ? 'debt' : 'receivable';
        final key = '${type}_installments_data_$uid';
        final restored = decode(prefs.getString(key));
        for (final row in merged.values) {
          if (row['installments'] is List || row['is_deleted'] == true) {
            restored.removeWhere((r) => r['parent_id'] == row['id']);
            if (row['is_deleted'] != true) {
              restored.addAll(
                (row['installments'] as List).map(
                  (r) => Map<String, dynamic>.from(r as Map),
                ),
              );
            }
          }
        }
        await prefs.setString(key, jsonEncode(restored));
      }
    }
    if (prefs.getBool('profile_dirty_$uid') ?? false) {
      final data = Map<String, dynamic>.from(
        jsonDecode(prefs.getString('profile_cache_$uid') ?? '{}') as Map,
      );
      await backend.write('users', uid, {
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
      }, []);
      await prefs.setBool('profile_dirty_$uid', false);
    }
    lastError = null;
  }

  @visibleForTesting
  static Map<String, dynamic> normalizeCloud(
    String collection,
    String docId,
    Map<String, dynamic> data,
    List<Map<String, dynamic>> local,
  ) {
    final row = Map<String, dynamic>.from(data)
      ..remove('updated_at')
      ..remove('created_at')
      ..remove('user_id');
    if (collection == 'budgets') return row;
    final field = {
      'categories': 'category_id',
      'items': 'item_id',
      'transactions': 'transaction_id',
      'customers': 'customer_id',
      'lenders': 'lender_id',
      'debts': 'debt_id',
      'receivables': 'receivable_id',
    }[collection]!;
    final suffix = RegExp(
      r'_(?:cat|item|tx|customer|lender|debt|receivable)_(\d+)$',
    ).firstMatch(docId);
    final localMatch = collection == 'categories' || collection == 'items'
        ? local.where((r) => r['name'] == row['name']).firstOrNull
        : null;
    row['id'] =
        row['id'] ??
        row[field] ??
        (suffix == null
            ? (localMatch == null ? null : localMatch['id'])
            : int.parse(suffix.group(1)!)) ??
        stableLegacyId(docId);
    row.remove(field);
    if (collection == 'categories' || collection == 'items') {
      row['is_active'] ??= true;
    }
    return row;
  }

  static int stableLegacyId(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0x7fffffff;
    }
    return -hash - 1; // separate namespace from existing positive numeric IDs
  }
}

class CloudRecord {
  final String id;
  final Map<String, dynamic> data;
  const CloudRecord(this.id, this.data);
}

abstract class SyncBackend {
  Future<List<CloudRecord>> read(String collection, String uid);
  Future<void> write(
    String collection,
    String id,
    Map<String, dynamic> data,
    List<String> aliases,
  );
}

class FirestoreSyncBackend implements SyncBackend {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<List<CloudRecord>> read(String collection, String uid) async {
    final snapshot = await _db
        .collection(collection)
        .where('user_id', isEqualTo: uid)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 12));
    return snapshot.docs.map((doc) => CloudRecord(doc.id, doc.data())).toList();
  }

  @override
  Future<void> write(
    String collection,
    String id,
    Map<String, dynamic> data,
    List<String> aliases,
  ) async {
    // Commit the canonical row and aliases together. All writes fit a single
    // batch in ordinary migrations; reject pathological duplicates safely.
    if (aliases.length > 490) {
      throw StateError(
        'Terlalu banyak duplikat cloud. Hubungi pengelola aplikasi.',
      );
    }
    final batch = _db.batch();
    batch.set(
      _db.collection(collection).doc(id),
      data,
      SetOptions(merge: collection == 'users'),
    );
    for (final alias in aliases) {
      batch.set(_db.collection(collection).doc(alias), {
        'is_deleted': true,
      }, SetOptions(merge: true));
    }
    await batch.commit().timeout(const Duration(seconds: 12));
  }
}
