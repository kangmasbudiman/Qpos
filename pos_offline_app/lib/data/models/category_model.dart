class Category {
  final int id;
  final int? merchantId;
  final int? branchId;
  final String? branchName; // dari relasi branch:id,name,code
  final String name;
  final String? description;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  const Category({
    required this.id,
    this.merchantId,
    this.branchId,
    this.branchName,
    required this.name,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  /// null branchId = kategori berlaku untuk semua branch (merchant-level)
  bool get isMerchantLevel => branchId == null;

  factory Category.fromJson(Map<String, dynamic> json) {
    final branch = json['branch'] as Map<String, dynamic>?;
    return Category(
      id:          json['id'] as int,
      merchantId:  json['merchant_id'] as int?,
      branchId:    json['branch_id'] as int?,
      branchName:  branch?['name'] as String?,
      name:        json['name'] as String,
      description: json['description'] as String?,
      isActive:    (json['is_active'] as bool?) ?? true,
      createdAt:   json['created_at'] as String?,
      updatedAt:   json['updated_at'] as String?,
    );
  }

  factory Category.fromDatabase(Map<String, dynamic> map) {
    return Category(
      id:          map['id'] as int,
      merchantId:  map['merchant_id'] as int?,
      branchId:    map['branch_id'] as int?,
      branchName:  map['branch_name'] as String?,
      name:        map['name'] as String,
      description: map['description'] as String?,
      isActive:    (map['is_active'] as int? ?? 1) == 1,
      createdAt:   map['created_at'] as String?,
      updatedAt:   map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id':                                         id,
      if (merchantId != null) 'merchant_id':        merchantId,
      if (branchId != null)   'branch_id':          branchId,
      if (branchName != null) 'branch_name':        branchName,
      'name':                                       name,
      if (description != null) 'description':       description,
      'is_active':                                  isActive ? 1 : 0,
      if (createdAt != null) 'created_at':          createdAt,
      if (updatedAt != null) 'updated_at':          updatedAt,
    };
  }

  Map<String, dynamic> toApiPayload() {
    return {
      if (branchId != null) 'branch_id': branchId,
      'name':                             name,
      if (description != null) 'description': description,
      'is_active':                        isActive,
    };
  }

  // Sentinel agar copyWith bisa set field nullable ke null
  static const _unset = Object();

  Category copyWith({
    int?    id,
    Object? merchantId  = _unset,
    Object? branchId    = _unset,
    Object? branchName  = _unset,
    String? name,
    Object? description = _unset,
    bool?   isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return Category(
      id:          id          ?? this.id,
      merchantId:  identical(merchantId,  _unset) ? this.merchantId  : merchantId  as int?,
      branchId:    identical(branchId,    _unset) ? this.branchId    : branchId    as int?,
      branchName:  identical(branchName,  _unset) ? this.branchName  : branchName  as String?,
      name:        name        ?? this.name,
      description: identical(description, _unset) ? this.description : description as String?,
      isActive:    isActive    ?? this.isActive,
      createdAt:   createdAt   ?? this.createdAt,
      updatedAt:   updatedAt   ?? this.updatedAt,
    );
  }
}
