import 'package:koala/employee/features/jobs/models/timesheet_event.dart';
import 'package:sqflite/sqflite.dart';

/// Kalıcı mesai kayıtlarının saklama seam'i.
abstract interface class TimesheetEventStore {
  Future<void> add(TimesheetEvent event);

  Future<List<TimesheetEvent>> readForUser(String userId);

  Future<void> remove(String clientEventId);

  Future<void> markRequiresSupport(String clientEventId, String message);

  Future<String?> readLastActiveUser();

  Future<void> setLastActiveUser(String? userId);
}

/// Yeniden açılışta profil ağına ihtiyaç duymadan doğru kullanıcı bölümü
/// bulunabilsin diye olaylarla son etkin kullanıcıyı aynı SQLite dosyasında
/// tutan adapter.
class SqfliteTimesheetEventStore implements TimesheetEventStore {
  SqfliteTimesheetEventStore({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactory,
      _databasePath = databasePath;

  static const String _databaseName = 'koala_timesheet_queue.db';
  static const String _table = 'timesheet_events';
  static const String _metadataTable = 'timesheet_queue_metadata';
  static const String _activeUserKey = 'active_user_id';
  final DatabaseFactory _factory;
  final String? _databasePath;
  Database? _database;
  Future<Database>? _openingDatabase;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;
    final opening = _openingDatabase;
    if (opening != null) return opening;

    final future = _openDatabase();
    _openingDatabase = future;
    try {
      return _database = await future;
    } finally {
      if (identical(_openingDatabase, future)) _openingDatabase = null;
    }
  }

  Future<Database> _openDatabase() async {
    final explicitPath = _databasePath;
    final path =
        explicitPath ?? '${await _factory.getDatabasesPath()}/$_databaseName';
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, _) async {
          await database.execute('''
            CREATE TABLE $_table (
              sequence_id INTEGER PRIMARY KEY AUTOINCREMENT,
              client_event_id TEXT NOT NULL UNIQUE,
              user_id TEXT NOT NULL,
              assignment_id TEXT NOT NULL,
              action TEXT NOT NULL,
              captured_at TEXT NOT NULL,
              monotonic_micros INTEGER NOT NULL,
              latitude REAL,
              longitude REAL,
              status TEXT NOT NULL,
              support_message TEXT
            )
          ''');
          await database.execute('''
            CREATE INDEX timesheet_events_user_sequence
            ON $_table (user_id, sequence_id)
          ''');
          await database.execute('''
            CREATE TABLE $_metadataTable (
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
        },
      ),
    );
  }

  /// Testlerde ve sınırlı yaşam döngüsü sahiplerinde dosyayı kapatır.
  Future<void> close() async {
    final database = _database ?? await _openingDatabase;
    _database = null;
    _openingDatabase = null;
    await database?.close();
  }

  @override
  Future<void> add(TimesheetEvent event) async {
    final database = await _db;
    await database.transaction((transaction) async {
      await transaction.insert(_table, event.toDatabase());
    });
  }

  @override
  Future<List<TimesheetEvent>> readForUser(String userId) async {
    final database = await _db;
    final rows = await database.query(
      _table,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'sequence_id ASC',
    );
    return rows.map(TimesheetEvent.fromDatabase).toList(growable: false);
  }

  @override
  Future<void> remove(String clientEventId) async {
    final database = await _db;
    await database.transaction((transaction) async {
      await transaction.delete(
        _table,
        where: 'client_event_id = ?',
        whereArgs: [clientEventId],
      );
    });
  }

  @override
  Future<void> markRequiresSupport(String clientEventId, String message) async {
    final database = await _db;
    await database.transaction((transaction) async {
      await transaction.update(
        _table,
        {
          'status': TimesheetEventStatus.requiresSupport.code,
          'support_message': message,
        },
        where: 'client_event_id = ?',
        whereArgs: [clientEventId],
      );
    });
  }

  @override
  Future<String?> readLastActiveUser() async {
    final database = await _db;
    final rows = await database.query(
      _metadataTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_activeUserKey],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['value'] as String?;
  }

  @override
  Future<void> setLastActiveUser(String? userId) async {
    final database = await _db;
    await database.transaction((transaction) async {
      if (userId == null) {
        await transaction.delete(
          _metadataTable,
          where: 'key = ?',
          whereArgs: [_activeUserKey],
        );
        return;
      }
      await transaction.insert(_metadataTable, {
        'key': _activeUserKey,
        'value': userId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
