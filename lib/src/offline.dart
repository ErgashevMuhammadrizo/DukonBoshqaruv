import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

import 'api.dart';

/// Offline sotuv navbatidagi yozuv holati.
enum OpStatus { pending, ack, conflict }

/// Offline navbatdagi bitta operatsiya.
class OfflineOp {
  final String id;
  final Map<String, dynamic> payload;
  final OpStatus status;
  final int retries;
  final String? error;

  const OfflineOp({
    required this.id,
    required this.payload,
    required this.status,
    required this.retries,
    this.error,
  });

  factory OfflineOp.fromRow(Map<String, Object?> row) {
    final statusStr = row['status'] as String;
    final status = switch (statusStr) {
      'ack' => OpStatus.ack,
      'conflict' => OpStatus.conflict,
      _ => OpStatus.pending,
    };
    return OfflineOp(
      id: row['id'] as String,
      payload: Map<String, dynamic>.from(
          jsonDecode(row['payload'] as String) as Map),
      status: status,
      retries: row['retries'] as int,
      error: row['error'] as String?,
    );
  }
}

/// Doimiy (durable) offline sotuvlar navbati — SQLite asosida.
/// Tarmoq xatolarida sotuvlar saqlanib, ulanish tiklanganda yuboriladi.
class OfflineQueue {
  final String dbName;
  Database? _db;

  OfflineQueue({this.dbName = 'dokon_queue.db'});

  Future<Database> get db async => _db ??= await openDatabase(
        join(await getDatabasesPath(), dbName),
        version: 2,
        onCreate: (d, v) async {
          await d.execute(
            'CREATE TABLE operations('
            'id TEXT PRIMARY KEY, '
            'payload TEXT NOT NULL, '
            'status TEXT NOT NULL, '
            'retries INTEGER NOT NULL DEFAULT 0, '
            'error TEXT)',
          );
          await d.execute(
            'CREATE TABLE cache('
            'key TEXT PRIMARY KEY, '
            'payload TEXT NOT NULL)',
          );
        },
        onUpgrade: (d, oldV, newV) async {
          // v1 → v2: jadval tuzilishi o'zgarmadi, faqat versiya ko'tarildi.
          if (oldV < 2) {
            // Kelajakdagi migratsiyalar uchun joy.
          }
        },
      );

  /// Sotuvni navbatga qo'shish.
  /// [operationId] — oldindan berilgan UUID (idempotency uchun).
  /// [payload] — sotuv ma'lumotlari (items, cash, card, discount).
  Future<String> enqueueSale(
      Map<String, dynamic> payload, [String? operationId]) async {
    final id = operationId ?? const Uuid().v4();
    final d = await db;
    // Takroriy qo'shilishdan himoya: mavjud bo'lsa, yangi yozuv yaratmaymiz.
    final existing = await d.query('operations', where: 'id=?', whereArgs: [id]);
    if (existing.isEmpty) {
      await d.insert('operations', {
        'id': id,
        'payload': jsonEncode(payload),
        'status': 'pending',
        'retries': 0,
      });
    }
    return id;
  }

  /// App oldingi qismidagi `sync` metodlariga mos keluvchi umumiy wrapper.
  Future<SyncResult> sync(Api api) => syncOnce(api);

  /// Kutilayotgan va ziddiyatli operatsiyalar.
  Future<List<OfflineOp>> pendingOps() async {
    final rows = await (await db).query(
      'operations',
      where: "status IN ('pending','conflict')",
      orderBy: 'rowid ASC',
    );
    return rows.map(OfflineOp.fromRow).toList();
  }

  /// Kutilayotgan operatsiyalar soni (AppBar badge uchun).
  Future<int> pendingCount() async {
    final result = await (await db).rawQuery(
      "SELECT COUNT(*) as cnt FROM operations WHERE status IN ('pending','conflict')",
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Barcha ziddiyatli operatsiyalar (foydalanuvchi ko'rishi uchun).
  Future<List<OfflineOp>> conflictOps() async {
    final rows = await (await db).query(
      'operations',
      where: "status='conflict'",
      orderBy: 'rowid ASC',
    );
    return rows.map(OfflineOp.fromRow).toList();
  }

  /// Operatsiyani qayta urinish uchun 'pending' holatga qaytarish.
  Future<void> retryOp(String id) async {
    await (await db).update(
      'operations',
      {'status': 'pending', 'error': null},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  /// Operatsiyani navbatdan o'chirish (bekor qilish).
  Future<void> cancelOp(String id) async {
    await (await db).delete('operations', where: 'id=?', whereArgs: [id]);
  }

  /// Serverga sinxronlash — bir vaqtda faqat bitta sinxronlash ishlaydi.
  bool _syncing = false;

  /// Tarmoq orqali pending operatsiyalarni serverga yuborish.
  ///
  /// Faqat tarmoq xatolarida navbatda ushlab qolamiz.
  /// Server validatsiya xatosi (4xx) — conflict sifatida belgilanadi
  /// (navbatdan o'chirilmaydi, foydalanuvchi ko'radi).
  Future<SyncResult> syncOnce(Api api) async {
    if (_syncing) return SyncResult(acked: 0, conflicts: 0, networkError: false);
    _syncing = true;
    int acked = 0;
    int conflicts = 0;
    bool networkError = false;
    try {
      final d = await db;
      final ops = await pendingOps();
      if (ops.isEmpty) return SyncResult(acked: 0, conflicts: 0, networkError: false);

      // Barcha pending operatsiyalarni bir paketda yuborish.
      final operations = ops
          .map((op) => {
                'operation_id': op.id,
                'type': 'sale',
                'payload': op.payload,
              })
          .toList();

      try {
        final result = await api.syncPush(operations);
        final results = result['results'] as List<dynamic>;

        for (final item in results) {
          final opId = item['operation_id'] as String?;
          if (opId == null) continue;
          final status = item['status'] as String?;

          if (status == 'ack') {
            await d.update(
              'operations',
              {'status': 'ack', 'error': null},
              where: 'id=?',
              whereArgs: [opId],
            );
            acked++;
          } else {
            // Server validatsiya xatosi yoki ombor yetishmasligi — conflict.
            await d.update(
              'operations',
              {
                'status': 'conflict',
                'error': item['message']?.toString() ?? 'Server xatosi',
              },
              where: 'id=?',
              whereArgs: [opId],
            );
            conflicts++;
          }
        }
      } on Exception catch (e) {
        // Tarmoq xatosi — retries hisoblagichni oshiramiz, pending qoladi.
        networkError = true;
        for (final op in ops) {
          await d.rawUpdate(
            'UPDATE operations SET retries=retries+1, error=? WHERE id=?',
            [e.toString(), op.id],
          );
        }
      }
    } finally {
      _syncing = false;
    }
    return SyncResult(acked: acked, conflicts: conflicts, networkError: networkError);
  }

  // ─── Mahsulotlar keshi ────────────────────────────────────────────────────

  Future<void> cacheProducts(List<dynamic> products) async =>
      (await db).insert(
        'cache',
        {'key': 'products', 'payload': jsonEncode(products)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<dynamic>> cachedProducts() async {
    final rows = await (await db)
        .query('cache', where: 'key=?', whereArgs: ['products']);
    return rows.isEmpty
        ? []
        : jsonDecode(rows.first['payload'] as String) as List<dynamic>;
  }
}

/// Sinxronlash natijasi.
class SyncResult {
  final int acked;
  final int conflicts;
  final bool networkError;

  const SyncResult({
    required this.acked,
    required this.conflicts,
    required this.networkError,
  });
}

/// Fon sinxronlash xizmati.
/// - Ilova ochilganda bir marta sinxronlaydi.
/// - Ulanish tiklanganda sinxronlaydi (connectivity_plus orqali).
/// - Har 30 soniyada tekshiradi (faqat ulanish bor bo'lsa).
class OfflineSyncService {
  final OfflineQueue queue;
  final Api api;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicTimer;

  OfflineSyncService({required this.queue, required this.api});

  /// Xizmatni ishga tushirish.
  void start() {
    // Ilova ochilganda darhol sinxronlash.
    _triggerSync();

    // Ulanish o'zgarganda sinxronlash.
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any(
        (r) => r != ConnectivityResult.none,
      );
      if (isOnline) _triggerSync();
    });

    // Har 30 soniyada sinxronlash.
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _triggerSync();
    });
  }

  /// Xizmatni to'xtatish.
  void stop() {
    _connectivitySub?.cancel();
    _periodicTimer?.cancel();
    _connectivitySub = null;
    _periodicTimer = null;
  }

  Future<void> _triggerSync() async {
    try {
      await queue.syncOnce(api);
    } catch (_) {
      // Xatolarni yutamiz — UI ko'rinmasligi uchun.
    }
  }
}
