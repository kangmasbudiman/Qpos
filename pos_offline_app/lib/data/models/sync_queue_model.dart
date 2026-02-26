enum SyncOperation { create, update, delete, cancel }

class SyncQueueItem {
  final int? id;
  final String tableName;
  final SyncOperation operation;
  final int? recordId;
  final Map<String, dynamic> data;
  final int retryCount;
  final String? lastError;
  final String createdAt;
  final String? updatedAt;

  const SyncQueueItem({
    this.id,
    required this.tableName,
    required this.operation,
    this.recordId,
    required this.data,
    this.retryCount = 0,
    this.lastError,
    required this.createdAt,
    this.updatedAt,
  });

  factory SyncQueueItem.fromDatabase(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] as int?,
      tableName: map['table_name'] as String,
      operation: SyncOperation.values.byName(map['operation'] as String),
      recordId: map['record_id'] as int?,
      data: map['data'] as Map<String, dynamic>,
      retryCount: map['retry_count'] as int? ?? 0,
      lastError: map['last_error'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      if (id != null) 'id': id,
      'table_name': tableName,
      'operation': operation.name,
      if (recordId != null) 'record_id': recordId,
      'data': data,
      'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  SyncQueueItem copyWith({
    int? id,
    String? tableName,
    SyncOperation? operation,
    int? recordId,
    Map<String, dynamic>? data,
    int? retryCount,
    String? lastError,
    String? createdAt,
    String? updatedAt,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      tableName: tableName ?? this.tableName,
      operation: operation ?? this.operation,
      recordId: recordId ?? this.recordId,
      data: data ?? this.data,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}