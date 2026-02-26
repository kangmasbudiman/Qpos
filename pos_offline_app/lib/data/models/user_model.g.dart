// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
  id:          (json['id'] as num?)?.toInt(),
  name:        json['name'] as String,
  email:       json['email'] as String,
  phone:       json['phone'] as String?,
  role:        json['role'] as String,
  merchantId:  (json['merchant_id'] as num?)?.toInt(),
  branchId:    (json['branch_id'] as num?)?.toInt(),
  isActive:    json['is_active'] as bool? ?? true,
  createdAt:   json['created_at'] as String?,
  updatedAt:   json['updated_at'] as String?,
  companyCode: json['company_code'] as String?,
  companyName: json['company_name'] as String?,
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  'id':           instance.id,
  'name':         instance.name,
  'email':        instance.email,
  'phone':        instance.phone,
  'role':         instance.role,
  'merchant_id':  instance.merchantId,
  'branch_id':    instance.branchId,
  'is_active':    instance.isActive,
  'created_at':   instance.createdAt,
  'updated_at':   instance.updatedAt,
  'company_code': instance.companyCode,
  'company_name': instance.companyName,
};
