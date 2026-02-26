// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
  id: (json['id'] as num?)?.toInt(),
  merchantId: (json['merchantId'] as num?)?.toInt(),
  categoryId: (json['categoryId'] as num?)?.toInt(),
  name: json['name'] as String,
  sku: json['sku'] as String,
  barcode: json['barcode'] as String?,
  description: json['description'] as String?,
  price: (json['price'] as num).toDouble(),
  cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
  unit: json['unit'] as String? ?? 'pcs',
  minStock: (json['minStock'] as num?)?.toInt() ?? 0,
  image: json['image'] as String?,
  isActive: json['isActive'] as bool? ?? true,
  createdAt: json['createdAt'] as String?,
  updatedAt: json['updatedAt'] as String?,
  isSynced: json['isSynced'] as bool? ?? false,
  syncedAt: json['syncedAt'] as String?,
  localStock: (json['localStock'] as num?)?.toInt(),
);

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
  'id': instance.id,
  'merchantId': instance.merchantId,
  'categoryId': instance.categoryId,
  'name': instance.name,
  'sku': instance.sku,
  'barcode': instance.barcode,
  'description': instance.description,
  'price': instance.price,
  'cost': instance.cost,
  'unit': instance.unit,
  'minStock': instance.minStock,
  'image': instance.image,
  'isActive': instance.isActive,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
  'isSynced': instance.isSynced,
  'syncedAt': instance.syncedAt,
  'localStock': instance.localStock,
};
