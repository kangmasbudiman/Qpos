import 'package:json_annotation/json_annotation.dart';

part 'customer_model.g.dart';

@JsonSerializable()
class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;
  final String createdAt;
  final String? updatedAt;
  final bool isSynced;
  final String? syncedAt;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.syncedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => _$CustomerFromJson(json);
  Map<String, dynamic> toJson() => _$CustomerToJson(this);

  /// Convert from database format
  factory Customer.fromDatabase(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      syncedAt: map['synced_at'] as String?,
    );
  }

  /// Convert to database format
  Map<String, dynamic> toDatabase() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (notes != null) 'notes': notes,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
      if (syncedAt != null) 'synced_at': syncedAt,
    };
  }

  /// Convert to API format for backend sync
  Map<String, dynamic> toApiJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (notes != null) 'notes': notes,
      'is_active': isActive,
    };
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? notes,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
    bool? isSynced,
    String? syncedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
