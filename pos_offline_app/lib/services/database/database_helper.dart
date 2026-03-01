import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/database_tables.dart';

class DatabaseHelper {
  static Database? _database;
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), AppConstants.databaseName);
    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.users} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phone TEXT,
        role TEXT NOT NULL,
        merchant_id INTEGER,
        branch_id INTEGER,
        ${DatabaseColumns.isActive} INTEGER DEFAULT 1,
        ${DatabaseColumns.createdAt} TEXT NOT NULL,
        ${DatabaseColumns.updatedAt} TEXT
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.products} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant_id INTEGER,
        category_id INTEGER,
        name TEXT NOT NULL,
        sku TEXT UNIQUE NOT NULL,
        barcode TEXT UNIQUE,
        description TEXT,
        price REAL NOT NULL,
        cost REAL DEFAULT 0,
        unit TEXT DEFAULT 'pcs',
        min_stock INTEGER DEFAULT 0,
        image TEXT,
        local_stock INTEGER DEFAULT 0,
        ${DatabaseColumns.isActive} INTEGER DEFAULT 1,
        ${DatabaseColumns.isSynced} INTEGER DEFAULT 0,
        ${DatabaseColumns.syncedAt} TEXT,
        ${DatabaseColumns.createdAt} TEXT NOT NULL,
        ${DatabaseColumns.updatedAt} TEXT
      )
    ''');

    // Categories table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.categories} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant_id INTEGER,
        branch_id INTEGER,
        branch_name TEXT,
        name TEXT NOT NULL,
        description TEXT,
        ${DatabaseColumns.isActive} INTEGER DEFAULT 1,
        ${DatabaseColumns.isSynced} INTEGER DEFAULT 0,
        ${DatabaseColumns.syncedAt} TEXT,
        ${DatabaseColumns.createdAt} TEXT NOT NULL,
        ${DatabaseColumns.updatedAt} TEXT
      )
    ''');

    // Sales table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.sales} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_id INTEGER,
        customer_id INTEGER,
        invoice_number TEXT UNIQUE NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL DEFAULT 0,
        tax REAL DEFAULT 0,
        total REAL NOT NULL,
        cash REAL NOT NULL,
        change_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        status TEXT DEFAULT 'completed',
        notes TEXT,
        cashier_name TEXT,
        ${DatabaseColumns.isSynced} INTEGER DEFAULT 0,
        ${DatabaseColumns.syncedAt} TEXT,
        ${DatabaseColumns.createdAt} TEXT NOT NULL,
        ${DatabaseColumns.updatedAt} TEXT
      )
    ''');

    // Sale Items table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.saleItems} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        discount REAL DEFAULT 0,
        subtotal REAL NOT NULL,
        ${DatabaseColumns.createdAt} TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES ${DatabaseTables.sales} (${DatabaseColumns.id}) ON DELETE CASCADE
      )
    ''');

    // Sync Queue table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.syncQueue} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseColumns.tableName} TEXT NOT NULL,
        ${DatabaseColumns.operation} TEXT NOT NULL,
        ${DatabaseColumns.recordId} INTEGER,
        ${DatabaseColumns.data} TEXT NOT NULL,
        ${DatabaseColumns.retryCount} INTEGER DEFAULT 0,
        ${DatabaseColumns.lastError} TEXT,
        ${DatabaseColumns.createdAt} TEXT NOT NULL,
        ${DatabaseColumns.updatedAt} TEXT
      )
    ''');

    // Customers table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.customers} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        merchant_id INTEGER,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        ${DatabaseColumns.isActive} INTEGER DEFAULT 1,
        ${DatabaseColumns.isSynced} INTEGER DEFAULT 0,
        ${DatabaseColumns.syncedAt} TEXT,
        ${DatabaseColumns.createdAt} TEXT NOT NULL,
        ${DatabaseColumns.updatedAt} TEXT
      )
    ''');

    // App Settings table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.appSettings} (
        key TEXT PRIMARY KEY,
        value TEXT,
        ${DatabaseColumns.updatedAt} TEXT
      )
    ''');

    // Stock Movements table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.stockMovements} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        quantity_before INTEGER NOT NULL,
        quantity_after INTEGER NOT NULL,
        reference_type TEXT,
        notes TEXT,
        ${DatabaseColumns.createdAt} TEXT NOT NULL
      )
    ''');

    // Suppliers table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.suppliers} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY,
        merchant_id INTEGER,
        name TEXT NOT NULL,
        company_name TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        ${DatabaseColumns.isActive} INTEGER DEFAULT 1,
        ${DatabaseColumns.createdAt} TEXT,
        ${DatabaseColumns.updatedAt} TEXT
      )
    ''');

    // Purchases table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.purchases} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_number TEXT,
        merchant_id INTEGER,
        branch_id INTEGER,
        supplier_id INTEGER,
        supplier_name TEXT,
        purchase_date TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL DEFAULT 0,
        tax REAL DEFAULT 0,
        total REAL NOT NULL,
        status TEXT DEFAULT 'received',
        notes TEXT,
        ${DatabaseColumns.isSynced} INTEGER DEFAULT 0,
        ${DatabaseColumns.syncedAt} TEXT,
        ${DatabaseColumns.createdAt} TEXT NOT NULL,
        ${DatabaseColumns.updatedAt} TEXT
      )
    ''');

    // Purchase Items table
    await db.execute('''
      CREATE TABLE ${DatabaseTables.purchaseItems} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        cost REAL NOT NULL,
        quantity INTEGER NOT NULL,
        discount REAL DEFAULT 0,
        subtotal REAL NOT NULL,
        ${DatabaseColumns.createdAt} TEXT NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES ${DatabaseTables.purchases} (${DatabaseColumns.id}) ON DELETE CASCADE
      )
    ''');

    // Held Transactions table (for Hold/Resume feature)
    await db.execute('''\
      CREATE TABLE ${DatabaseTables.heldTransactions} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT,
        cart_data TEXT NOT NULL,
        customer_id INTEGER,
        customer_name TEXT,
        total REAL DEFAULT 0,
        ${DatabaseColumns.createdAt} TEXT NOT NULL
      )
    ''');

    // Stock Opname tables (v7)
    await db.execute('''
      CREATE TABLE ${DatabaseTables.stockOpnames} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        opname_number TEXT NOT NULL,
        branch_id INTEGER,
        user_id INTEGER,
        opname_date TEXT NOT NULL,
        status TEXT DEFAULT 'completed',
        notes TEXT,
        ${DatabaseColumns.isSynced} INTEGER DEFAULT 0,
        ${DatabaseColumns.syncedAt} TEXT,
        ${DatabaseColumns.createdAt} TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.stockOpnameItems} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_opname_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        system_qty INTEGER NOT NULL,
        counted_qty INTEGER NOT NULL,
        variance INTEGER NOT NULL,
        notes TEXT,
        FOREIGN KEY (stock_opname_id) REFERENCES ${DatabaseTables.stockOpnames} (${DatabaseColumns.id}) ON DELETE CASCADE
      )
    ''');

    // Loyalty Member tables (v8)
    await db.execute('''
      CREATE TABLE ${DatabaseTables.loyaltyMembers} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER UNIQUE NOT NULL,
        points_balance INTEGER DEFAULT 0,
        total_points_earned INTEGER DEFAULT 0,
        tier TEXT DEFAULT 'bronze',
        ${DatabaseColumns.createdAt} TEXT NOT NULL,
        ${DatabaseColumns.updatedAt} TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.loyaltyTransactions} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        sale_id INTEGER,
        type TEXT NOT NULL,
        points INTEGER NOT NULL,
        description TEXT,
        ${DatabaseColumns.createdAt} TEXT NOT NULL
      )
    ''');

    // Cashier Shift table (v8)
    await db.execute('''
      CREATE TABLE ${DatabaseTables.cashierShifts} (
        ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        user_name TEXT,
        branch_id INTEGER,
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        opening_cash REAL DEFAULT 0,
        closing_cash REAL,
        expected_cash REAL,
        cash_variance REAL,
        total_sales INTEGER DEFAULT 0,
        total_revenue REAL DEFAULT 0,
        status TEXT DEFAULT 'open',
        notes TEXT,
        ${DatabaseColumns.createdAt} TEXT NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_products_sku ON ${DatabaseTables.products}(sku)');
    await db.execute('CREATE INDEX idx_sales_invoice ON ${DatabaseTables.sales}(invoice_number)');
    await db.execute('CREATE INDEX idx_sync_queue_table ON ${DatabaseTables.syncQueue}(${DatabaseColumns.tableName})');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Tambah branch_id & branch_name ke tabel categories
      await db.execute('ALTER TABLE ${DatabaseTables.categories} ADD COLUMN branch_id INTEGER');
      await db.execute('ALTER TABLE ${DatabaseTables.categories} ADD COLUMN branch_name TEXT');
    }
    if (oldVersion < 3) {
      // Tambah is_synced & synced_at ke tabel categories (dibutuhkan oleh _markRecordAsSynced)
      await db.execute('ALTER TABLE ${DatabaseTables.categories} ADD COLUMN is_synced INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE ${DatabaseTables.categories} ADD COLUMN synced_at TEXT');
    }
    if (oldVersion < 4) {
      // Buat tabel stock_movements
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.stockMovements} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          type TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          quantity_before INTEGER NOT NULL,
          quantity_after INTEGER NOT NULL,
          reference_type TEXT,
          notes TEXT,
          ${DatabaseColumns.createdAt} TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      // Buat tabel suppliers, purchases, purchase_items
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.suppliers} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY,
          merchant_id INTEGER,
          name TEXT NOT NULL,
          company_name TEXT,
          phone TEXT,
          email TEXT,
          address TEXT,
          ${DatabaseColumns.isActive} INTEGER DEFAULT 1,
          ${DatabaseColumns.createdAt} TEXT,
          ${DatabaseColumns.updatedAt} TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.purchases} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          purchase_number TEXT,
          merchant_id INTEGER,
          branch_id INTEGER,
          supplier_id INTEGER,
          supplier_name TEXT,
          purchase_date TEXT NOT NULL,
          subtotal REAL NOT NULL,
          discount REAL DEFAULT 0,
          tax REAL DEFAULT 0,
          total REAL NOT NULL,
          status TEXT DEFAULT 'received',
          notes TEXT,
          ${DatabaseColumns.isSynced} INTEGER DEFAULT 0,
          ${DatabaseColumns.syncedAt} TEXT,
          ${DatabaseColumns.createdAt} TEXT NOT NULL,
          ${DatabaseColumns.updatedAt} TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.purchaseItems} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          purchase_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          product_name TEXT NOT NULL,
          cost REAL NOT NULL,
          quantity INTEGER NOT NULL,
          discount REAL DEFAULT 0,
          subtotal REAL NOT NULL,
          ${DatabaseColumns.createdAt} TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      // Buat tabel held_transactions untuk fitur Hold/Resume
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.heldTransactions} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          label TEXT,
          cart_data TEXT NOT NULL,
          customer_id INTEGER,
          customer_name TEXT,
          total REAL DEFAULT 0,
          ${DatabaseColumns.createdAt} TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 7) {
      // Buat tabel stock_opnames & stock_opname_items untuk fitur Stock Opname
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.stockOpnames} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          opname_number TEXT NOT NULL,
          branch_id INTEGER,
          user_id INTEGER,
          opname_date TEXT NOT NULL,
          status TEXT DEFAULT 'completed',
          notes TEXT,
          ${DatabaseColumns.isSynced} INTEGER DEFAULT 0,
          ${DatabaseColumns.syncedAt} TEXT,
          ${DatabaseColumns.createdAt} TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.stockOpnameItems} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          stock_opname_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          product_name TEXT NOT NULL,
          system_qty INTEGER NOT NULL,
          counted_qty INTEGER NOT NULL,
          variance INTEGER NOT NULL,
          notes TEXT,
          FOREIGN KEY (stock_opname_id) REFERENCES ${DatabaseTables.stockOpnames} (${DatabaseColumns.id}) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 8) {
      // Loyalty Member tables
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.loyaltyMembers} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER UNIQUE NOT NULL,
          points_balance INTEGER DEFAULT 0,
          total_points_earned INTEGER DEFAULT 0,
          tier TEXT DEFAULT 'bronze',
          ${DatabaseColumns.createdAt} TEXT NOT NULL,
          ${DatabaseColumns.updatedAt} TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.loyaltyTransactions} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          sale_id INTEGER,
          type TEXT NOT NULL,
          points INTEGER NOT NULL,
          description TEXT,
          ${DatabaseColumns.createdAt} TEXT NOT NULL
        )
      ''');
      // Cashier Shift table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.cashierShifts} (
          ${DatabaseColumns.id} INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          user_name TEXT,
          branch_id INTEGER,
          opened_at TEXT NOT NULL,
          closed_at TEXT,
          opening_cash REAL DEFAULT 0,
          closing_cash REAL,
          expected_cash REAL,
          cash_variance REAL,
          total_sales INTEGER DEFAULT 0,
          total_revenue REAL DEFAULT 0,
          status TEXT DEFAULT 'open',
          notes TEXT,
          ${DatabaseColumns.createdAt} TEXT NOT NULL
        )
      ''');
    }
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    List<String>? columns,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  Future<int> update(String table, Map<String, dynamic> data,
      {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // Clear all data (for logout or reset)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(DatabaseTables.sales);
    await db.delete(DatabaseTables.saleItems);
    await db.delete(DatabaseTables.products);
    await db.delete(DatabaseTables.categories);
    await db.delete(DatabaseTables.customers);
    await db.delete(DatabaseTables.syncQueue);
  }
}