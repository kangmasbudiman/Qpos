import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/database_tables.dart';
import '../database/database_helper.dart';

enum ConflictResolutionStrategy {
  serverWins,    // Server data overwrites local
  clientWins,    // Local data overwrites server
  lastWriteWins, // Most recent timestamp wins
  manual,        // User decides
}

class ConflictResolver extends GetxService {
  final DatabaseHelper _db = DatabaseHelper();
  
  /// Resolve sync conflicts
  Future<bool> resolveConflict({
    required String tableName,
    required Map<String, dynamic> localData,
    required Map<String, dynamic> serverData,
    ConflictResolutionStrategy strategy = ConflictResolutionStrategy.lastWriteWins,
  }) async {
    
    try {
      switch (strategy) {
        case ConflictResolutionStrategy.serverWins:
          return await _applyServerData(tableName, serverData);
        
        case ConflictResolutionStrategy.clientWins:
          return await _applyLocalData(tableName, localData);
        
        case ConflictResolutionStrategy.lastWriteWins:
          return await _resolveByTimestamp(tableName, localData, serverData);
        
        case ConflictResolutionStrategy.manual:
          return await _requestManualResolution(tableName, localData, serverData);
      }
    } catch (e) {
      print('Conflict resolution failed: $e');
      return false;
    }
  }

  /// Apply server data (server wins)
  Future<bool> _applyServerData(String tableName, Map<String, dynamic> serverData) async {
    try {
      await _db.update(
        tableName,
        {
          ...serverData,
          'is_synced': 1,
          'synced_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [serverData['id']],
      );
      
      print('✅ Conflict resolved: Server data applied');
      return true;
    } catch (e) {
      print('❌ Failed to apply server data: $e');
      return false;
    }
  }

  /// Apply local data (client wins)
  Future<bool> _applyLocalData(String tableName, Map<String, dynamic> localData) async {
    try {
      // Keep local data and mark as synced
      await _db.update(
        tableName,
        {
          'is_synced': 1,
          'synced_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [localData['id']],
      );
      
      print('✅ Conflict resolved: Local data kept');
      return true;
    } catch (e) {
      print('❌ Failed to keep local data: $e');
      return false;
    }
  }

  /// Resolve by timestamp (last write wins)
  Future<bool> _resolveByTimestamp(
    String tableName, 
    Map<String, dynamic> localData, 
    Map<String, dynamic> serverData
  ) async {
    try {
      final localUpdated = DateTime.tryParse(localData['updated_at'] ?? '');
      final serverUpdated = DateTime.tryParse(serverData['updated_at'] ?? '');
      
      if (localUpdated == null && serverUpdated == null) {
        // If no timestamps, default to server wins
        return await _applyServerData(tableName, serverData);
      }
      
      if (localUpdated == null) {
        return await _applyServerData(tableName, serverData);
      }
      
      if (serverUpdated == null) {
        return await _applyLocalData(tableName, localData);
      }
      
      // Compare timestamps
      if (serverUpdated.isAfter(localUpdated)) {
        print('🕐 Server data is newer, applying server changes');
        return await _applyServerData(tableName, serverData);
      } else {
        print('🕐 Local data is newer, keeping local changes');
        return await _applyLocalData(tableName, localData);
      }
    } catch (e) {
      print('❌ Timestamp resolution failed: $e');
      // Default to server wins on error
      return await _applyServerData(tableName, serverData);
    }
  }

  /// Request manual conflict resolution from user
  Future<bool> _requestManualResolution(
    String tableName,
    Map<String, dynamic> localData,
    Map<String, dynamic> serverData,
  ) async {
    
    final resolution = await Get.dialog<ConflictResolutionChoice>(
      AlertDialog(
        title: Text('Sync Conflict Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A conflict was found in $tableName data:'),
            SizedBox(height: 16),
            
            Text('Local Version:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_formatDataForDisplay(localData)),
            SizedBox(height: 12),
            
            Text('Server Version:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_formatDataForDisplay(serverData)),
            SizedBox(height: 16),
            
            Text('Which version would you like to keep?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: ConflictResolutionChoice.keepLocal),
            child: Text('Keep Local'),
          ),
          TextButton(
            onPressed: () => Get.back(result: ConflictResolutionChoice.useServer),
            child: Text('Use Server'),
          ),
          TextButton(
            onPressed: () => Get.back(result: ConflictResolutionChoice.merge),
            child: Text('Merge'),
          ),
        ],
      ),
    );

    switch (resolution) {
      case ConflictResolutionChoice.keepLocal:
        return await _applyLocalData(tableName, localData);
      
      case ConflictResolutionChoice.useServer:
        return await _applyServerData(tableName, serverData);
      
      case ConflictResolutionChoice.merge:
        return await _mergeData(tableName, localData, serverData);
      
      default:
        // Default to server wins if user cancels
        return await _applyServerData(tableName, serverData);
    }
  }

  /// Merge local and server data
  Future<bool> _mergeData(
    String tableName,
    Map<String, dynamic> localData,
    Map<String, dynamic> serverData,
  ) async {
    try {
      // Simple merge strategy: prefer non-null local values, fallback to server
      final mergedData = <String, dynamic>{};
      
      // Start with server data as base
      mergedData.addAll(serverData);
      
      // Override with local data where local is not null/empty
      for (final entry in localData.entries) {
        if (entry.value != null && entry.value != '') {
          // Special handling for certain fields
          if (_shouldPreferLocalValue(entry.key, entry.value, serverData[entry.key])) {
            mergedData[entry.key] = entry.value;
          }
        }
      }
      
      // Apply merged data
      await _db.update(
        tableName,
        {
          ...mergedData,
          'is_synced': 1,
          'synced_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [mergedData['id']],
      );
      
      print('✅ Conflict resolved: Data merged successfully');
      return true;
    } catch (e) {
      print('❌ Data merge failed: $e');
      return false;
    }
  }

  /// Determine if local value should be preferred during merge
  bool _shouldPreferLocalValue(String key, dynamic localValue, dynamic serverValue) {
    // Prefer local for certain fields that are typically modified offline
    const localPreferredFields = [
      'local_stock',
      'last_sale_date',
      'notes',
      'discount',
    ];
    
    if (localPreferredFields.contains(key)) return true;
    
    // For prices and costs, prefer newer values (would need timestamp comparison)
    if (['price', 'cost'].contains(key)) {
      // Could implement more sophisticated logic here
      return false;
    }
    
    // Default to keeping local if different from server
    return localValue != serverValue;
  }

  /// Format data for user-friendly display
  String _formatDataForDisplay(Map<String, dynamic> data) {
    final displayData = <String, dynamic>{};
    
    // Only show relevant fields to user
    const relevantFields = ['name', 'price', 'stock', 'updated_at'];
    
    for (final field in relevantFields) {
      if (data.containsKey(field)) {
        displayData[field] = data[field];
      }
    }
    
    return displayData.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
  }

  /// Auto-resolve conflicts based on table-specific rules
  Future<bool> autoResolveConflict(
    String tableName,
    Map<String, dynamic> localData,
    Map<String, dynamic> serverData,
  ) async {
    
    switch (tableName) {
      case DatabaseTables.products:
        // For products, prefer server for master data, local for stock
        return await _resolveProductConflict(localData, serverData);
      
      case DatabaseTables.sales:
        // For sales, local always wins (sales are created offline)
        return await _applyLocalData(tableName, localData);
      
      case DatabaseTables.customers:
        // For customers, use last write wins
        return await _resolveByTimestamp(tableName, localData, serverData);
      
      default:
        // Default strategy
        return await _resolveByTimestamp(tableName, localData, serverData);
    }
  }

  /// Product-specific conflict resolution
  Future<bool> _resolveProductConflict(
    Map<String, dynamic> localData,
    Map<String, dynamic> serverData,
  ) async {
    
    try {
      // Merge strategy: Server wins for master data, local wins for stock
      final mergedData = Map<String, dynamic>.from(serverData);
      
      // Prefer local stock data
      if (localData.containsKey('local_stock')) {
        mergedData['local_stock'] = localData['local_stock'];
      }
      
      // Prefer local discount if any
      if (localData.containsKey('discount') && localData['discount'] != null) {
        mergedData['discount'] = localData['discount'];
      }
      
      await _db.update(
        DatabaseTables.products,
        {
          ...mergedData,
          'is_synced': 1,
          'synced_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [mergedData['id']],
      );
      
      print('✅ Product conflict resolved with custom merge');
      return true;
    } catch (e) {
      print('❌ Product conflict resolution failed: $e');
      return false;
    }
  }
}

enum ConflictResolutionChoice {
  keepLocal,
  useServer,
  merge,
}