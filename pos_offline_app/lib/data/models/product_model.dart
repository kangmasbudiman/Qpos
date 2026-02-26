import 'package:json_annotation/json_annotation.dart';

part 'product_model.g.dart';

@JsonSerializable()
class Product {
  final int? id;
  final int? merchantId;
  final int? categoryId;
  final String name;
  final String sku;
  final String? barcode;
  final String? description;
  final double price;
  final double cost;
  final String unit;
  final int minStock;
  final String? image;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;
  
  // Local fields for offline support
  final bool isSynced;
  final String? syncedAt;
  final int? localStock; // Current stock in this device/branch

  const Product({
    this.id,
    this.merchantId,
    this.categoryId,
    required this.name,
    required this.sku,
    this.barcode,
    this.description,
    required this.price,
    this.cost = 0.0,
    this.unit = 'pcs',
    this.minStock = 0,
    this.image,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.syncedAt,
    this.localStock,
  });

  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);
  Map<String, dynamic> toJson() => _$ProductToJson(this);

  factory Product.fromDatabase(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      merchantId: map['merchant_id'] as int?,
      categoryId: map['category_id'] as int?,
      name: map['name'] as String,
      sku: map['sku'] as String,
      barcode: map['barcode'] as String?,
      description: map['description'] as String?,
      price: (map['price'] as num).toDouble(),
      cost: (map['cost'] as num? ?? 0).toDouble(),
      unit: map['unit'] as String? ?? 'pcs',
      minStock: map['min_stock'] as int? ?? 0,
      image: map['image'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      syncedAt: map['synced_at'] as String?,
      localStock: map['local_stock'] as int?,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      if (id != null) 'id': id,
      if (merchantId != null) 'merchant_id': merchantId,
      if (categoryId != null) 'category_id': categoryId,
      'name': name,
      'sku': sku,
      if (barcode != null) 'barcode': barcode,
      if (description != null) 'description': description,
      'price': price,
      'cost': cost,
      'unit': unit,
      'min_stock': minStock,
      if (image != null) 'image': image,
      'is_active': isActive ? 1 : 0,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (localStock != null) 'local_stock': localStock,
    };
  }

  Product copyWith({
    int? id,
    int? merchantId,
    int? categoryId,
    String? name,
    String? sku,
    String? barcode,
    String? description,
    double? price,
    double? cost,
    String? unit,
    int? minStock,
    String? image,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    bool? isSynced,
    String? syncedAt,
    int? localStock,
  }) {
    return Product(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      description: description ?? this.description,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      unit: unit ?? this.unit,
      minStock: minStock ?? this.minStock,
      image: image ?? this.image,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      localStock: localStock ?? this.localStock,
    );
  }
}