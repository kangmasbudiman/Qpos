// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Sale _$SaleFromJson(Map<String, dynamic> json) => Sale(
  id: (json['id'] as num?)?.toInt(),
  branchId: (json['branchId'] as num?)?.toInt(),
  customerId: (json['customerId'] as num?)?.toInt(),
  invoiceNumber: json['invoiceNumber'] as String,
  subtotal: (json['subtotal'] as num).toDouble(),
  discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
  tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
  total: (json['total'] as num).toDouble(),
  cash: (json['cash'] as num).toDouble(),
  change: (json['change'] as num).toDouble(),
  paymentMethod: json['paymentMethod'] as String,
  status: json['status'] as String? ?? 'completed',
  notes: json['notes'] as String?,
  cashierName: json['cashierName'] as String?,
  createdAt: json['createdAt'] as String,
  updatedAt: json['updatedAt'] as String?,
  isSynced: json['isSynced'] as bool? ?? false,
  syncedAt: json['syncedAt'] as String?,
  items: (json['items'] as List<dynamic>?)
      ?.map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$SaleToJson(Sale instance) => <String, dynamic>{
  'id': instance.id,
  'branchId': instance.branchId,
  'customerId': instance.customerId,
  'invoiceNumber': instance.invoiceNumber,
  'subtotal': instance.subtotal,
  'discount': instance.discount,
  'tax': instance.tax,
  'total': instance.total,
  'cash': instance.cash,
  'change': instance.change,
  'paymentMethod': instance.paymentMethod,
  'status': instance.status,
  'notes': instance.notes,
  'cashierName': instance.cashierName,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
  'isSynced': instance.isSynced,
  'syncedAt': instance.syncedAt,
  'items': instance.items,
};

SaleItem _$SaleItemFromJson(Map<String, dynamic> json) => SaleItem(
  id: (json['id'] as num?)?.toInt(),
  saleId: (json['saleId'] as num?)?.toInt(),
  productId: (json['productId'] as num).toInt(),
  productName: json['productName'] as String,
  price: (json['price'] as num).toDouble(),
  quantity: (json['quantity'] as num).toInt(),
  discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
  subtotal: (json['subtotal'] as num).toDouble(),
);

Map<String, dynamic> _$SaleItemToJson(SaleItem instance) => <String, dynamic>{
  'id': instance.id,
  'saleId': instance.saleId,
  'productId': instance.productId,
  'productName': instance.productName,
  'price': instance.price,
  'quantity': instance.quantity,
  'discount': instance.discount,
  'subtotal': instance.subtotal,
};
