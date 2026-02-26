import 'supplier_model.dart';

class Purchase {
  final int? id;
  final String? purchaseNumber;
  final int? merchantId;
  final int? branchId;
  final int? supplierId;
  final String? supplierName;
  final String purchaseDate;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String status;
  final String? notes;
  final bool isSynced;
  final String? syncedAt;
  final String? createdAt;
  final String? updatedAt;
  final List<PurchaseItem>? items;

  const Purchase({
    this.id,
    this.purchaseNumber,
    this.merchantId,
    this.branchId,
    this.supplierId,
    this.supplierName,
    required this.purchaseDate,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.total,
    this.status = 'received',
    this.notes,
    this.isSynced = false,
    this.syncedAt,
    this.createdAt,
    this.updatedAt,
    this.items,
  });

  factory Purchase.fromDatabase(Map<String, dynamic> map) {
    return Purchase(
      id:             map['id'] as int?,
      purchaseNumber: map['purchase_number'] as String?,
      merchantId:     map['merchant_id'] as int?,
      branchId:       map['branch_id'] as int?,
      supplierId:     map['supplier_id'] as int?,
      supplierName:   map['supplier_name'] as String?,
      purchaseDate:   map['purchase_date'] as String,
      subtotal:       (map['subtotal'] as num).toDouble(),
      discount:       (map['discount'] as num? ?? 0).toDouble(),
      tax:            (map['tax'] as num? ?? 0).toDouble(),
      total:          (map['total'] as num).toDouble(),
      status:         map['status'] as String? ?? 'received',
      notes:          map['notes'] as String?,
      isSynced:       (map['is_synced'] as int? ?? 0) == 1,
      syncedAt:       map['synced_at'] as String?,
      createdAt:      map['created_at'] as String?,
      updatedAt:      map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      if (id != null) 'id': id,
      if (purchaseNumber != null) 'purchase_number': purchaseNumber,
      if (merchantId != null) 'merchant_id': merchantId,
      if (branchId != null) 'branch_id': branchId,
      if (supplierId != null) 'supplier_id': supplierId,
      if (supplierName != null) 'supplier_name': supplierName,
      'purchase_date': purchaseDate,
      'subtotal':      subtotal,
      'discount':      discount,
      'tax':           tax,
      'total':         total,
      'status':        status,
      if (notes != null) 'notes': notes,
      'is_synced':     isSynced ? 1 : 0,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  /// Payload JSON untuk dikirim ke backend API
  Map<String, dynamic> toApiJson() {
    return {
      if (branchId != null) 'branch_id': branchId,
      if (supplierId != null) 'supplier_id': supplierId,
      'purchase_date': purchaseDate,
      'discount':      discount,
      'tax':           tax,
      if (notes != null) 'notes': notes,
      if (items != null)
        'items': items!.map((i) => i.toApiJson()).toList(),
    };
  }
}

class PurchaseItem {
  final int? id;
  final int? purchaseId;
  final int productId;
  final String productName;
  final double cost;
  final int quantity;
  final double discount;
  final double subtotal;
  final String? createdAt;

  const PurchaseItem({
    this.id,
    this.purchaseId,
    required this.productId,
    required this.productName,
    required this.cost,
    required this.quantity,
    this.discount = 0.0,
    required this.subtotal,
    this.createdAt,
  });

  factory PurchaseItem.fromDatabase(Map<String, dynamic> map) {
    return PurchaseItem(
      id:          map['id'] as int?,
      purchaseId:  map['purchase_id'] as int?,
      productId:   map['product_id'] as int,
      productName: map['product_name'] as String,
      cost:        (map['cost'] as num).toDouble(),
      quantity:    map['quantity'] as int,
      discount:    (map['discount'] as num? ?? 0).toDouble(),
      subtotal:    (map['subtotal'] as num).toDouble(),
      createdAt:   map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      if (id != null) 'id': id,
      if (purchaseId != null) 'purchase_id': purchaseId,
      'product_id':   productId,
      'product_name': productName,
      'cost':         cost,
      'quantity':     quantity,
      'discount':     discount,
      'subtotal':     subtotal,
      'created_at':   createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toApiJson() {
    return {
      'product_id': productId,
      'quantity':   quantity,
      'cost':       cost,
      'discount':   discount,
    };
  }

  PurchaseItem copyWith({int? quantity, double? cost, double? discount}) {
    final qty  = quantity  ?? this.quantity;
    final c    = cost      ?? this.cost;
    final disc = discount  ?? this.discount;
    return PurchaseItem(
      id:          id,
      purchaseId:  purchaseId,
      productId:   productId,
      productName: productName,
      cost:        c,
      quantity:    qty,
      discount:    disc,
      subtotal:    (c * qty) - disc,
      createdAt:   createdAt,
    );
  }
}
