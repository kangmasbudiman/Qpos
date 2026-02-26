// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Customer _$CustomerFromJson(Map<String, dynamic> json) => Customer(
  id: (json['id'] as num?)?.toInt(),
  name: json['name'] as String,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
  address: json['address'] as String?,
  notes: json['notes'] as String?,
  isActive: json['isActive'] as bool? ?? true,
  createdAt: json['createdAt'] as String,
  updatedAt: json['updatedAt'] as String?,
  isSynced: json['isSynced'] as bool? ?? false,
  syncedAt: json['syncedAt'] as String?,
);

Map<String, dynamic> _$CustomerToJson(Customer instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'phone': instance.phone,
  'email': instance.email,
  'address': instance.address,
  'notes': instance.notes,
  'isActive': instance.isActive,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
  'isSynced': instance.isSynced,
  'syncedAt': instance.syncedAt,
};
