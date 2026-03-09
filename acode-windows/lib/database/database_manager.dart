import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/provider.dart';
import '../models/usage_tracker.dart';

/// SQLite 数据库管理器
class DatabaseManager {
  static DatabaseManager? _instance;
  static DatabaseManager get instance => _instance ??= DatabaseManager._();

  Database? _db;

  DatabaseManager._();

  /// 初始化数据库
  Future<void> initialize() async {
    if (_db != null) return;

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final appDir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(appDir.path, 'ACode'));
    if (!dbDir.existsSync()) {
      dbDir.createSync(recursive: true);
    }
    final dbPath = p.join(dbDir.path, 'acode.db');

    _db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Database get db {
    if (_db == null) throw StateError('Database not initialized');
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS providers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        tool TEXT NOT NULL,
        api_key TEXT NOT NULL,
        api_base TEXT DEFAULT '',
        model TEXT DEFAULT '',
        extra_env TEXT DEFAULT '{}',
        is_active INTEGER DEFAULT 0,
        icon TEXT,
        icon_color TEXT,
        notes TEXT,
        category TEXT,
        preset_id TEXT,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS model_pricing (
        model TEXT PRIMARY KEY,
        input_price_per_million REAL NOT NULL,
        output_price_per_million REAL NOT NULL
      )
    ''');

    // 插入默认模型定价
    for (final pricing in ModelPricing.defaults) {
      await db.insert('model_pricing', {
        'model': pricing.model,
        'input_price_per_million': pricing.inputPricePerMillion,
        'output_price_per_million': pricing.outputPricePerMillion,
      });
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 未来版本升级逻辑
  }

  // ==================== Provider CRUD ====================

  /// 获取所有 Provider
  Future<List<Provider>> getAllProviders() async {
    final rows = await db.query('providers', orderBy: 'created_at ASC');
    return rows.map((r) => Provider.fromMap(r)).toList();
  }

  /// 获取指定工具的 Provider 列表
  Future<List<Provider>> getProvidersByTool(String tool) async {
    final rows = await db.query(
      'providers',
      where: 'tool = ?',
      whereArgs: [tool],
      orderBy: 'created_at ASC',
    );
    return rows.map((r) => Provider.fromMap(r)).toList();
  }

  /// 获取指定工具的激活 Provider
  Future<Provider?> getActiveProvider(String tool) async {
    final rows = await db.query(
      'providers',
      where: 'tool = ? AND is_active = 1',
      whereArgs: [tool],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Provider.fromMap(rows.first);
  }

  /// 插入 Provider
  Future<int> insertProvider(Provider provider) async {
    return await db.insert('providers', provider.toMap()..remove('id'));
  }

  /// 更新 Provider
  Future<void> updateProvider(Provider provider) async {
    if (provider.id == null) return;
    await db.update(
      'providers',
      provider.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [provider.id],
    );
  }

  /// 删除 Provider
  Future<void> deleteProvider(int id) async {
    await db.delete('providers', where: 'id = ?', whereArgs: [id]);
  }

  /// 切换激活 Provider（同工具下只能有一个激活）
  Future<void> switchActiveProvider(int id, String tool) async {
    await db.transaction((txn) async {
      // 先取消同工具所有激活
      await txn.update(
        'providers',
        {'is_active': 0},
        where: 'tool = ?',
        whereArgs: [tool],
      );
      // 激活指定 Provider
      await txn.update(
        'providers',
        {'is_active': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  // ==================== Settings ====================

  Future<String?> getSetting(String key) async {
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ==================== Model Pricing ====================

  Future<ModelPricing?> getModelPricing(String model) async {
    final rows = await db.query(
      'model_pricing',
      where: 'model = ?',
      whereArgs: [model],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return ModelPricing(
      model: row['model'] as String,
      inputPricePerMillion: (row['input_price_per_million'] as num).toDouble(),
      outputPricePerMillion: (row['output_price_per_million'] as num).toDouble(),
    );
  }

  /// 关闭数据库
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _instance = null;
  }
}
