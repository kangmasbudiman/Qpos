class DatabaseTables {
  // Master Data Tables
  static const String users = 'users';
  static const String products = 'products';
  static const String categories = 'categories';
  static const String customers = 'customers';
  static const String suppliers = 'suppliers';
  static const String branches = 'branches';
  
  // Transaction Tables
  static const String sales = 'sales';
  static const String saleItems = 'sale_items';
  static const String purchases = 'purchases';
  static const String purchaseItems = 'purchase_items';
  static const String stocks = 'stocks';
  
  // Sync & Queue Tables
  static const String syncQueue = 'sync_queue';
  static const String appSettings = 'app_settings';
  static const String stockMovements = 'stock_movements';

  // Hold Transaction Table
  static const String heldTransactions = 'held_transactions';

  // Stock Opname Tables
  static const String stockOpnames     = 'stock_opnames';
  static const String stockOpnameItems = 'stock_opname_items';

  // Loyalty / Member Tables (v8)
  static const String loyaltyMembers       = 'loyalty_members';
  static const String loyaltyTransactions  = 'loyalty_transactions';

  // Cashier Shift Table (v8)
  static const String cashierShifts = 'cashier_shifts';
}

class DatabaseColumns {
  // Common columns
  static const String id = 'id';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  static const String isActive = 'is_active';
  static const String isSynced = 'is_synced';
  static const String syncedAt = 'synced_at';
  
  // Sync Queue columns
  static const String tableName = 'table_name';
  static const String operation = 'operation'; // CREATE, UPDATE, DELETE
  static const String recordId = 'record_id';
  static const String data = 'data';
  static const String retryCount = 'retry_count';
  static const String lastError = 'last_error';
}