class Branch {
  final int id;
  final int merchantId;
  final String name;
  final String? code;
  final String? address;
  final String? phone;
  final String? city;
  final bool isActive;

  const Branch({
    required this.id,
    required this.merchantId,
    required this.name,
    this.code,
    this.address,
    this.phone,
    this.city,
    this.isActive = true,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id:         json['id'] as int,
      merchantId: json['merchant_id'] as int,
      name:       json['name'] as String,
      code:       json['code'] as String?,
      address:    json['address'] as String?,
      phone:      json['phone'] as String?,
      city:       json['city'] as String?,
      isActive:   (json['is_active'] as bool?) ?? true,
    );
  }

  factory Branch.fromDatabase(Map<String, dynamic> map) {
    return Branch(
      id:         map['id'] as int,
      merchantId: map['merchant_id'] as int,
      name:       map['name'] as String,
      code:       map['code'] as String?,
      address:    map['address'] as String?,
      phone:      map['phone'] as String?,
      city:       map['city'] as String?,
      isActive:   (map['is_active'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'id':          id,
      'merchant_id': merchantId,
      'name':        name,
      if (code != null) 'code': code,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (city != null) 'city': city,
      'is_active':   isActive ? 1 : 0,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id':          id,
      'merchant_id': merchantId,
      'name':        name,
      'code':        code,
      'address':     address,
      'phone':       phone,
      'city':        city,
      'is_active':   isActive,
    };
  }

  /// Label untuk ditampilkan di UI
  String get displayName {
    if (city != null && city!.isNotEmpty) {
      return '$name - $city';
    }
    return name;
  }
}
