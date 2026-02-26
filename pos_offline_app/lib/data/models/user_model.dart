import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class User {
  final int? id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final int? merchantId;
  final int? branchId;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  // Info company (dari response login)
  final String? companyCode;
  final String? companyName;

  const User({
    this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.merchantId,
    this.branchId,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.companyCode,
    this.companyName,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  factory User.fromDatabase(Map<String, dynamic> map) {
    return User(
      id:          map['id'] as int?,
      name:        map['name'] as String,
      email:       map['email'] as String,
      phone:       map['phone'] as String?,
      role:        map['role'] as String,
      merchantId:  map['merchant_id'] as int?,
      branchId:    map['branch_id'] as int?,
      isActive:    (map['is_active'] as int? ?? 1) == 1,
      createdAt:   map['created_at'] as String?,
      updatedAt:   map['updated_at'] as String?,
      companyCode: map['company_code'] as String?,
      companyName: map['company_name'] as String?,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      if (id != null) 'id': id,
      'name':                   name,
      'email':                  email,
      if (phone != null) 'phone': phone,
      'role':                   role,
      if (merchantId != null) 'merchant_id': merchantId,
      if (branchId != null) 'branch_id': branchId,
      'is_active':              isActive ? 1 : 0,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (companyCode != null) 'company_code': companyCode,
      if (companyName != null) 'company_name': companyName,
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    int? merchantId,
    int? branchId,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    String? companyCode,
    String? companyName,
  }) {
    return User(
      id:          id ?? this.id,
      name:        name ?? this.name,
      email:       email ?? this.email,
      phone:       phone ?? this.phone,
      role:        role ?? this.role,
      merchantId:  merchantId ?? this.merchantId,
      branchId:    branchId ?? this.branchId,
      isActive:    isActive ?? this.isActive,
      createdAt:   createdAt ?? this.createdAt,
      updatedAt:   updatedAt ?? this.updatedAt,
      companyCode: companyCode ?? this.companyCode,
      companyName: companyName ?? this.companyName,
    );
  }

  bool get isOwner      => role == 'owner';
  bool get isManager    => role == 'manager';
  bool get isCashier    => role == 'cashier';
  bool get isSuperAdmin => role == 'super_admin';
}
