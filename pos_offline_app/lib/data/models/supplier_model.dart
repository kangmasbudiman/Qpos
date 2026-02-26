class Supplier {
  final int id;
  final int? merchantId;
  final String name;
  final String? companyName;
  final String? phone;
  final String? email;
  final String? address;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  const Supplier({
    required this.id,
    this.merchantId,
    required this.name,
    this.companyName,
    this.phone,
    this.email,
    this.address,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id:          json['id'] as int,
      merchantId:  json['merchant_id'] as int?,
      name:        json['name'] as String,
      companyName: json['company_name'] as String?,
      phone:       json['phone'] as String?,
      email:       json['email'] as String?,
      address:     json['address'] as String?,
      isActive:    (json['is_active'] == true || json['is_active'] == 1),
      createdAt:   json['created_at'] as String?,
      updatedAt:   json['updated_at'] as String?,
    );
  }

  factory Supplier.fromDatabase(Map<String, dynamic> map) {
    return Supplier(
      id:          map['id'] as int,
      merchantId:  map['merchant_id'] as int?,
      name:        map['name'] as String,
      companyName: map['company_name'] as String?,
      phone:       map['phone'] as String?,
      email:       map['email'] as String?,
      address:     map['address'] as String?,
      isActive:    (map['is_active'] as int? ?? 1) == 1,
      createdAt:   map['created_at'] as String?,
      updatedAt:   map['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id':           id,
      if (merchantId != null) 'merchant_id': merchantId,
      'name':         name,
      if (companyName != null) 'company_name': companyName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      'is_active':    isActive ? 1 : 0,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  /// Label yang ditampilkan di dropdown
  String get displayName =>
      companyName != null && companyName!.isNotEmpty ? companyName! : name;
}
