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
        version: 2,
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
        sort_order INTEGER DEFAULT 0,
        icon TEXT,
        icon_color TEXT,
        notes TEXT,
        category TEXT,
        preset_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
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
        model_id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        input_cost_per_million TEXT NOT NULL,
        output_cost_per_million TEXT NOT NULL,
        cache_read_cost_per_million TEXT DEFAULT '0',
        cache_creation_cost_per_million TEXT DEFAULT '0'
      )
    ''');

    // 插入默认模型定价
    await _seedModelPricing(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // providers 表添加 sort_order 和 updated_at 字段
      try {
        await db.execute('ALTER TABLE providers ADD COLUMN sort_order INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE providers ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      // 将旧的 created_at TEXT 迁移到 INTEGER（尽力而为）
      try {
        await db.execute("UPDATE providers SET updated_at = CAST(strftime('%s', created_at) AS INTEGER) WHERE updated_at = 0");
      } catch (_) {}

      // 重建 model_pricing 表
      try {
        await db.execute('DROP TABLE IF EXISTS model_pricing');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS model_pricing (
            model_id TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            input_cost_per_million TEXT NOT NULL,
            output_cost_per_million TEXT NOT NULL,
            cache_read_cost_per_million TEXT DEFAULT '0',
            cache_creation_cost_per_million TEXT DEFAULT '0'
          )
        ''');
        await _seedModelPricing(db);
      } catch (_) {}
    }
  }

  /// 插入默认模型定价种子数据
  static Future<void> _seedModelPricing(Database db) async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM model_pricing'));
    if (count != null && count > 0) return;

    final seedData = [
      // Claude
      ('claude-3.5-haiku-20241022', 'Claude 3.5 Haiku', '0.8', '4.0', '0.08', '1.0'),
      ('claude-3-5-sonnet-20241022', 'Claude 3.5 Sonnet', '3.0', '15.0', '0.3', '3.75'),
      ('claude-sonnet-4-20250514', 'Claude 4 Sonnet', '3.0', '15.0', '0.3', '3.75'),
      ('claude-opus-4-20250514', 'Claude 4 Opus', '15.0', '75.0', '1.5', '18.75'),
      // OpenAI
      ('gpt-4o', 'GPT-4o', '2.5', '10.0', '1.25', '0'),
      ('gpt-4o-mini', 'GPT-4o Mini', '0.15', '0.6', '0.075', '0'),
      ('gpt-4.1', 'GPT-4.1', '2.0', '8.0', '0.5', '0'),
      ('gpt-4.1-mini', 'GPT-4.1 Mini', '0.4', '1.6', '0.1', '0'),
      ('gpt-4.1-nano', 'GPT-4.1 Nano', '0.1', '0.4', '0.025', '0'),
      ('o3', 'o3', '2.0', '8.0', '0.5', '0'),
      ('o3-mini', 'o3 Mini', '1.1', '4.4', '0.275', '0'),
      ('o4-mini', 'o4 Mini', '1.1', '4.4', '0.275', '0'),
      ('codex-mini-latest', 'Codex Mini', '1.5', '6.0', '0.375', '0'),
      // Gemini
      ('gemini-2.5-pro-preview-05-06', 'Gemini 2.5 Pro', '1.25', '10.0', '0.31', '0'),
      ('gemini-2.5-flash-preview-05-20', 'Gemini 2.5 Flash', '0.15', '0.6', '0.0375', '0'),
      ('gemini-2.0-flash', 'Gemini 2.0 Flash', '0.1', '0.4', '0.025', '0'),
      // DeepSeek
      ('deepseek-chat', 'DeepSeek V3', '0.27', '1.1', '0.07', '0'),
      ('deepseek-reasoner', 'DeepSeek R1', '0.55', '2.19', '0.14', '0'),
    ];

    for (final (modelId, displayName, input, output, cacheRead, cacheCreate) in seedData) {
      await db.insert('model_pricing', {
        'model_id': modelId,
        'display_name': displayName,
        'input_cost_per_million': input,
        'output_cost_per_million': output,
        'cache_read_cost_per_million': cacheRead,
        'cache_creation_cost_per_million': cacheCreate,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ==================== Provider CRUD ====================

  /// 获取所有 Provider
  Future<List<Provider>> getAllProviders() async {
    final rows = await db.query('providers', orderBy: 'sort_order ASC, created_at ASC');
    return rows.map((r) => Provider.fromMap(r)).toList();
  }

  /// 获取指定工具的 Provider 列表
  Future<List<Provider>> getProvidersByTool(String tool) async {
    final rows = await db.query(
      'providers',
      where: 'tool = ?',
      whereArgs: [tool],
      orderBy: 'sort_order ASC, created_at ASC',
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
    // 获取要删除的 Provider
    final rows = await db.query('providers', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;
    final provider = Provider.fromMap(rows.first);

    await db.delete('providers', where: 'id = ?', whereArgs: [id]);

    // 如果删除了激活的 Provider，自动激活同 tool 下一个
    if (provider.isActive) {
      final nextRows = await db.query(
        'providers',
        where: 'tool = ?',
        whereArgs: [provider.tool],
        orderBy: 'updated_at DESC',
        limit: 1,
      );
      if (nextRows.isNotEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await db.update(
          'providers',
          {'is_active': 1, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [nextRows.first['id']],
        );
      }
    }
  }

  /// 切换激活 Provider（同工具下只能有一个激活）
  Future<void> switchActiveProvider(int id, String tool) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.transaction((txn) async {
      // 先取消同工具所有激活
      await txn.update(
        'providers',
        {'is_active': 0, 'updated_at': now},
        where: 'tool = ?',
        whereArgs: [tool],
      );
      // 激活指定 Provider
      await txn.update(
        'providers',
        {'is_active': 1, 'updated_at': now},
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

  /// 获取所有模型定价
  Future<List<ModelPricing>> getAllModelPricing() async {
    final rows = await db.query('model_pricing', orderBy: 'model_id ASC');
    return rows.map((row) => ModelPricing(
      modelId: row['model_id'] as String,
      displayName: row['display_name'] as String,
      inputCostPerMillion: double.tryParse(row['input_cost_per_million'] as String? ?? '0') ?? 0,
      outputCostPerMillion: double.tryParse(row['output_cost_per_million'] as String? ?? '0') ?? 0,
      cacheReadCostPerMillion: double.tryParse(row['cache_read_cost_per_million'] as String? ?? '0') ?? 0,
      cacheCreationCostPerMillion: double.tryParse(row['cache_creation_cost_per_million'] as String? ?? '0') ?? 0,
    )).toList();
  }

  /// 获取指定模型的定价
  Future<ModelPricing?> getModelPricing(String modelId) async {
    final rows = await db.query(
      'model_pricing',
      where: 'model_id = ?',
      whereArgs: [modelId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return ModelPricing(
      modelId: row['model_id'] as String,
      displayName: row['display_name'] as String,
      inputCostPerMillion: double.tryParse(row['input_cost_per_million'] as String? ?? '0') ?? 0,
      outputCostPerMillion: double.tryParse(row['output_cost_per_million'] as String? ?? '0') ?? 0,
      cacheReadCostPerMillion: double.tryParse(row['cache_read_cost_per_million'] as String? ?? '0') ?? 0,
      cacheCreationCostPerMillion: double.tryParse(row['cache_creation_cost_per_million'] as String? ?? '0') ?? 0,
    );
  }

  /// 关闭数据库
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _instance = null;
  }
}
