import 'package:json_annotation/json_annotation.dart';

part 'sale_model.g.dart';

@JsonSerializable()
class Sale {
  final int? id;
  final int? branchId;
  final int? customerId;
  final String invoiceNumber;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double cash;
  final double change;
  final String paymentMethod;
  final String status;
  final String? notes;
  final String? cashierName;
  final String createdAt;
  final String? updatedAt;
  
  // Offline support
  final bool isSynced;
  final String? syncedAt;
  final List<SaleItem>? items;

  const Sale({
    this.id,
    this.branchId,
    this.customerId,
    required this.invoiceNumber,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.total,
    required this.cash,
    required this.change,
    required this.paymentMethod,
    this.status = 'completed',
    this.notes,
    this.cashierName,
    required this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.syncedAt,
    this.items,
  });

  factory Sale.fromJson(Map<String, dynamic> json) => _$SaleFromJson(json);
  Map<String, dynamic> toJson() => _$SaleToJson(this);
  
  /// Convert to API format (snake_case) for backend sync
  Map<String, dynamic> toApiJson() {
    return {
      if (id != null) 'id': id,
      'branch_id': branchId ?? 1, // Always send branch_id (default 1 if null)
      if (customerId != null) 'customer_id': customerId,
      'invoice_number': invoiceNumber,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'paid': cash, // Backend expects 'paid' instead of 'cash'
      'change': change, // Backend expects 'change' instead of 'change_amount'
      'payment_method': paymentMethod,
      'status': status,
      if (notes != null) 'notes': notes,
      if (cashierName != null) 'cashier_name': cashierName,
      // Don't send created_at/updated_at - let backend generate
      // Include items if available
      if (items != null && items!.isNotEmpty)
        'items': items!.map((item) => item.toApiJson()).toList(),
    };
  }

  factory Sale.fromDatabase(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as int?,
      branchId: map['branch_id'] as int?,
      customerId: map['customer_id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['discount'] as num? ?? 0).toDouble(),
      tax: (map['tax'] as num? ?? 0).toDouble(),
      total: (map['total'] as num).toDouble(),
      cash: (map['cash'] as num).toDouble(),
      change: (map['change_amount'] as num).toDouble(), // Fixed: use change_amount from DB
      paymentMethod: map['payment_method'] as String,
      status: map['status'] as String? ?? 'completed',
      notes: map['notes'] as String?,
      cashierName: map['cashier_name'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      syncedAt: map['synced_at'] as String?,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      if (id != null) 'id': id,
      if (branchId != null) 'branch_id': branchId,
      if (customerId != null) 'customer_id': customerId,
      'invoice_number': invoiceNumber,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'cash': cash,
      'change_amount': change, // Fixed: map to change_amount in DB
      'payment_method': paymentMethod,
      'status': status,
      if (notes != null) 'notes': notes,
      if (cashierName != null) 'cashier_name': cashierName,
      'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
      if (syncedAt != null) 'synced_at': syncedAt,
    };
  }

  Sale copyWith({
    int? id,
    int? branchId,
    int? customerId,
    String? invoiceNumber,
    double? subtotal,
    double? discount,
    double? tax,
    double? total,
    double? cash,
    double? change,
    String? paymentMethod,
    String? status,
    String? notes,
    String? cashierName,
    String? createdAt,
    String? updatedAt,
    bool? isSynced,
    String? syncedAt,
    List<SaleItem>? items,
  }) {
    return Sale(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      customerId: customerId ?? this.customerId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      cash: cash ?? this.cash,
      change: change ?? this.change,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      cashierName: cashierName ?? this.cashierName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      items: items ?? this.items,
    );
  }
}

@JsonSerializable()
class SaleItem {
  final int? id;
  final int? saleId;
  final int productId;
  final String productName;
  final double price;
  final int quantity;
  final double discount;
  final double subtotal;

  const SaleItem({
    this.id,
    this.saleId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.discount = 0.0,
    required this.subtotal,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) => _$SaleItemFromJson(json);
  Map<String, dynamic> toJson() => _$SaleItemToJson(this);
  
  /// Convert to API format (snake_case) for backend sync
  Map<String, dynamic> toApiJson() {
    return {
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
      'discount': discount,
      'subtotal': subtotal,
    };
  }

  factory SaleItem.fromDatabase(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int?,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      discount: (map['discount'] as num? ?? 0).toDouble(),
      subtotal: (map['subtotal'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      if (id != null) 'id': id,
      if (saleId != null) 'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
      'discount': discount,
      'subtotal': subtotal,
      'created_at': DateTime.now().toIso8601String(), // Add created_at timestamp
    };
  }
}