import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/unified_bluetooth_device.dart';
import '../../utils/app_logger.dart';
import 'dart:async';

class UnifiedBluetoothDatabase {
  static final UnifiedBluetoothDatabase instance = UnifiedBluetoothDatabase._init();
  static Database? _database;
  static bool _isInitializing = false;
  
  // Write lock to prevent simultaneous database writes
  final _writeLock = Completer<void>()..complete();
  bool _isWriting = false;

  UnifiedBluetoothDatabase._init();

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    if (_isInitializing) {
      // Wait for initialization to complete
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return _database!;
    }
    _isInitializing = true;
    _database = await _initDB('unified_bluetooth.db');
    _isInitializing = false;
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    AppLogger.info('Initializing Unified Bluetooth database at: $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE unified_devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT UNIQUE NOT NULL,
        device_type TEXT NOT NULL,
        name TEXT NOT NULL,
        custom_alias TEXT,
        rssi INTEGER DEFAULT 0,
        is_paired INTEGER DEFAULT 0,
        
        -- Bluetooth Classic fields (nullable)
        baud_rate INTEGER,
        data_bits INTEGER,
        stop_bits INTEGER,
        parity INTEGER DEFAULT 0,
        buffer_size INTEGER,
        
        -- BLE fields (nullable)
        service_uuid TEXT,
        rx_characteristic_uuid TEXT,
        tx_characteristic_uuid TEXT,
        mtu INTEGER,
        
        -- Common fields
        auto_reconnect INTEGER DEFAULT 1,
        connection_timeout INTEGER DEFAULT 10,
        last_connected TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_device_type ON unified_devices(device_type)
    ''');

    await db.execute('''
      CREATE INDEX idx_device_id ON unified_devices(device_id)
    ''');

    AppLogger.success('Unified Bluetooth database created');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.info('Upgrading database from v$oldVersion to v$newVersion');
    // Add migration logic here if schema changes
  }

  /// Acquire write lock
  Future<void> _acquireWriteLock() async {
    while (_isWriting) {
      await _writeLock.future;
    }
    _isWriting = true;
  }

  /// Release write lock
  void _releaseWriteLock() {
    _isWriting = false;
    if (!_writeLock.isCompleted) {
      _writeLock.complete();
    }
  }

  /// Insert or update device (THREAD-SAFE)
  Future<int> upsertDevice(UnifiedBluetoothDevice device) async {
    await _acquireWriteLock();
    try {
      final db = await database;
      final map = device.toMap();

      // Check if device exists
      final existing = await db.query(
        'unified_devices',
        where: 'device_id = ?',
        whereArgs: [device.id],
      );

      if (existing.isNotEmpty) {
        // Update
        await db.update(
          'unified_devices',
          map,
          where: 'device_id = ?',
          whereArgs: [device.id],
        );
        AppLogger.info('Updated device: ${device.displayName}');
        return existing.first['id'] as int;
      } else {
        // Insert
        final id = await db.insert('unified_devices', map);
        AppLogger.info('Inserted device: ${device.displayName}');
        return id;
      }
    } catch (e) {
      AppLogger.error('Failed to upsert device: $e');
      rethrow;
    } finally {
      _releaseWriteLock();
    }
  }

  /// Get all saved devices
  Future<List<UnifiedBluetoothDevice>> getAllDevices() async {
    try {
      final db = await database;
      final maps = await db.query(
        'unified_devices',
        orderBy: 'updated_at DESC',
      );

      return maps.map((map) => UnifiedBluetoothDevice.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Failed to get devices: $e');
      return [];
    }
  }

  /// Get devices by type
  Future<List<UnifiedBluetoothDevice>> getDevicesByType(
    BluetoothDeviceType type,
  ) async {
    try {
      final db = await database;
      final typeStr = type == BluetoothDeviceType.classic ? 'classic' : 'ble';
      final maps = await db.query(
        'unified_devices',
        where: 'device_type = ?',
        whereArgs: [typeStr],
        orderBy: 'updated_at DESC',
      );

      return maps.map((map) => UnifiedBluetoothDevice.fromMap(map)).toList();
    } catch (e) {
      AppLogger.error('Failed to get devices by type: $e');
      return [];
    }
  }

  /// Get device by ID
  Future<UnifiedBluetoothDevice?> getDeviceById(String deviceId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'unified_devices',
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );

      if (maps.isNotEmpty) {
        return UnifiedBluetoothDevice.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get device: $e');
      return null;
    }
  }

  /// Delete device (THREAD-SAFE)
  Future<void> deleteDevice(String deviceId) async {
    await _acquireWriteLock();
    try {
      final db = await database;
      await db.delete(
        'unified_devices',
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );
      AppLogger.info('Deleted device: $deviceId');
    } catch (e) {
      AppLogger.error('Failed to delete device: $e');
      rethrow;
    } finally {
      _releaseWriteLock();
    }
  }

  /// Update last connected time (THREAD-SAFE)
  Future<void> updateLastConnected(String deviceId) async {
    await _acquireWriteLock();
    try {
      final db = await database;
      await db.update(
        'unified_devices',
        {
          'last_connected': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );
    } catch (e) {
      AppLogger.error('Failed to update last connected: $e');
    } finally {
      _releaseWriteLock();
    }
  }

  /// Migrate from old Bluetooth Classic database
  Future<void> migrateFromClassicDatabase(Database oldDb) async {
    await _acquireWriteLock();
    try {
      AppLogger.info('Migrating Classic devices...');
      
      final oldDevices = await oldDb.query('bluetooth_devices');
      int migrated = 0;

      for (final map in oldDevices) {
        // Convert to unified format
        final unifiedMap = {
          'device_id': map['address'],
          'device_type': 'classic',
          'name': map['name'],
          'custom_alias': map['custom_alias'],
          'rssi': 0,
          'is_paired': 1,
          'baud_rate': map['baud_rate'],
          'data_bits': map['data_bits'],
          'stop_bits': map['stop_bits'],
          'parity': map['parity'],
          'buffer_size': map['buffer_size'],
          'auto_reconnect': map['auto_reconnect'],
          'connection_timeout': map['connection_timeout'],
          'last_connected': map['last_connected'],
          'created_at': map['created_at'],
          'updated_at': map['updated_at'],
        };

        final db = await database;
        await db.insert(
          'unified_devices',
          unifiedMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        migrated++;
      }

      AppLogger.success('Migrated $migrated Classic devices');
    } catch (e) {
      AppLogger.error('Classic migration failed: $e');
    } finally {
      _releaseWriteLock();
    }
  }

  /// Migrate from old BLE database
  Future<void> migrateFromBleDatabase(Database oldDb) async {
    await _acquireWriteLock();
    try {
      AppLogger.info('Migrating BLE devices...');
      
      final oldDevices = await oldDb.query('ble_devices');
      int migrated = 0;

      for (final map in oldDevices) {
        // Convert to unified format
        final unifiedMap = {
          'device_id': map['device_id'],
          'device_type': 'ble',
          'name': map['device_name'] ?? 'Unknown',
          'custom_alias': map['custom_alias'],
          'rssi': map['rssi'],
          'is_paired': 0,
          'service_uuid': map['service_uuid'],
          'rx_characteristic_uuid': map['rx_characteristic_uuid'],
          'tx_characteristic_uuid': map['tx_characteristic_uuid'],
          'mtu': map['mtu'],
          'auto_reconnect': map['auto_reconnect'],
          'connection_timeout': map['connection_timeout'],
          'last_connected': map['last_connected_at'],
          'created_at': map['created_at'],
          'updated_at': map['created_at'], // Use created_at as updated_at fallback
        };

        final db = await database;
        await db.insert(
          'unified_devices',
          unifiedMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        migrated++;
      }

      AppLogger.success('Migrated $migrated BLE devices');
    } catch (e) {
      AppLogger.error('BLE migration failed: $e');
    } finally {
      _releaseWriteLock();
    }
  }

  /// Clear all devices (THREAD-SAFE)
  Future<void> clearAllDevices() async {
    await _acquireWriteLock();
    try {
      final db = await database;
      await db.delete('unified_devices');
      AppLogger.info('Cleared all devices');
    } finally {
      _releaseWriteLock();
    }
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
