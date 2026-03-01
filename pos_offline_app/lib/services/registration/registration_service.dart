import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../auth/auth_service.dart';

// ── Data Models ────────────────────────────────────────────────────────────

/// Info subscription satu merchant (dari GET /subscriptions)
class MerchantSubInfo {
  final int    id;
  final String name;
  final String companyCode;
  final String email;
  final String? phone;
  final String subStatus;   // trial | active | expired | suspended
  final int    daysRemaining;
  final String? trialEndsAt;
  final String? subEndsAt;
  final String? planType;
  final String? subscriptionTier;  // 'starter' | 'business'
  final bool   canAccess;
  final String? approvedAt;

  const MerchantSubInfo({
    required this.id,
    required this.name,
    required this.companyCode,
    required this.email,
    this.phone,
    required this.subStatus,
    required this.daysRemaining,
    this.trialEndsAt,
    this.subEndsAt,
    this.planType,
    this.subscriptionTier,
    required this.canAccess,
    this.approvedAt,
  });

  factory MerchantSubInfo.fromJson(Map<String, dynamic> json) {
    final sub = json['subscription'] as Map<String, dynamic>? ?? {};
    return MerchantSubInfo(
      id:                (json['id'] as num).toInt(),
      name:              json['name'] as String? ?? '',
      companyCode:       json['company_code'] as String? ?? '',
      email:             json['email'] as String? ?? '',
      phone:             json['phone'] as String?,
      subStatus:         sub['status'] as String? ?? 'expired',
      daysRemaining:     (sub['days_remaining'] as num?)?.toInt() ?? 0,
      trialEndsAt:       sub['trial_ends_at'] as String?,
      subEndsAt:         sub['sub_ends_at'] as String?,
      planType:          sub['plan_type'] as String?,
      subscriptionTier:  sub['tier'] as String?,
      canAccess:         sub['can_access'] as bool? ?? false,
      approvedAt:        json['approved_at'] as String?,
    );
  }
}

class RegistrationStats {
  final int total;
  final int pending;
  final int approved;
  final int rejected;

  const RegistrationStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  factory RegistrationStats.fromJson(Map<String, dynamic> json) =>
      RegistrationStats(
        total:    (json['total']    as num?)?.toInt() ?? 0,
        pending:  (json['pending']  as num?)?.toInt() ?? 0,
        approved: (json['approved'] as num?)?.toInt() ?? 0,
        rejected: (json['rejected'] as num?)?.toInt() ?? 0,
      );
}

class MerchantRegistration {
  final int    id;
  final String merchantName;
  final String ownerName;
  final String email;
  final String? phone;
  final String? businessType;
  final String? address;
  final String  status;
  final String? rejectionReason;
  final String? companyCode;
  final String? approvedAt;
  final String? rejectedAt;
  final String  registeredAt;

  const MerchantRegistration({
    required this.id,
    required this.merchantName,
    required this.ownerName,
    required this.email,
    this.phone,
    this.businessType,
    this.address,
    required this.status,
    this.rejectionReason,
    this.companyCode,
    this.approvedAt,
    this.rejectedAt,
    required this.registeredAt,
  });

  factory MerchantRegistration.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'] as Map<String, dynamic>?;
    return MerchantRegistration(
      id:              (json['id'] as num).toInt(),
      merchantName:    json['merchant_name'] as String? ?? '',
      ownerName:       owner?['name'] as String? ?? json['owner_name'] as String? ?? '',
      email:           json['email'] as String? ?? owner?['email'] as String? ?? '',
      phone:           json['phone'] as String?,
      businessType:    json['business_type'] as String?,
      address:         json['address'] as String?,
      status:          json['registration_status'] as String? ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      companyCode:     json['company_code'] as String?,
      approvedAt:      json['approved_at'] as String?,
      rejectedAt:      json['rejected_at'] as String?,
      registeredAt:    json['registered_at'] as String? ?? json['created_at'] as String? ?? '',
    );
  }
}

// ── Service ────────────────────────────────────────────────────────────────

class RegistrationService extends GetxService {
  AuthService get _auth => Get.find<AuthService>();

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept':       'application/json',
    'Authorization': 'Bearer ${_auth.authToken}',
  };

  /// GET /registrations/stats
  Future<RegistrationStats> fetchStats() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/registrations/stats'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) {
      return RegistrationStats.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? 'Gagal memuat statistik');
  }

  /// GET /registrations?status=...&page=1&per_page=20
  Future<Map<String, dynamic>> fetchRegistrations({
    String status  = 'all',
    int    page    = 1,
    int    perPage = 20,
  }) async {
    final uri = Uri.parse(
        '${AppConstants.baseUrl}/registrations?status=$status&page=$page&per_page=$perPage');
    final response = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) {
      // data['data'] is a Laravel pagination object or the meta is separate
      final meta = data['meta'] as Map<String, dynamic>?;
      final rawItems = data['data'];
      final List items = rawItems is List ? rawItems : (rawItems['data'] as List? ?? []);
      final int total = meta != null
          ? (meta['total'] as num?)?.toInt() ?? items.length
          : (rawItems is Map ? (rawItems['total'] as num?)?.toInt() ?? items.length : items.length);

      return {
        'items':     items.map((e) => MerchantRegistration.fromJson(e as Map<String, dynamic>)).toList(),
        'total':     total,
        'lastPage':  meta != null ? (meta['last_page'] as num?)?.toInt() ?? 1 : 1,
      };
    }
    throw Exception(data['message'] ?? 'Gagal memuat daftar pendaftaran');
  }

  /// GET /registrations/{id}
  Future<MerchantRegistration> fetchDetail(int id) async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/registrations/$id'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) {
      return MerchantRegistration.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw Exception(data['message'] ?? 'Gagal memuat detail pendaftaran');
  }

  /// POST /registrations/{id}/approve
  Future<Map<String, dynamic>> approve(int id) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/registrations/$id/approve'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] as Map<String, dynamic>? ?? {};
    }
    throw Exception(data['message'] ?? 'Gagal menyetujui pendaftaran');
  }

  /// POST /registrations/{id}/reject
  Future<void> reject(int id, String reason) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/registrations/$id/reject'),
      headers: _headers,
      body: jsonEncode({'rejection_reason': reason}),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) return;
    throw Exception(data['message'] ?? 'Gagal menolak pendaftaran');
  }

  /// POST /registrations/{id}/resend-code
  Future<String> resendCode(int id) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/registrations/$id/resend-code'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) {
      return (data['data'] as Map<String, dynamic>)['email_to'] as String? ?? '';
    }
    throw Exception(data['message'] ?? 'Gagal mengirim ulang kode');
  }

  // ── Subscription Management (Super Admin) ─────────────────────────────────

  /// GET /subscriptions — list semua merchant + status subscription
  Future<List<MerchantSubInfo>> fetchMerchantSubscriptions() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/subscriptions'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) {
      final list = data['data'] as List;
      return list.map((e) => MerchantSubInfo.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception(data['message'] ?? 'Gagal memuat data subscription');
  }

  /// POST /subscriptions/{id}/activate — aktifkan langganan berbayar
  Future<void> activateSubscription(int merchantId, String planType, double amount, {String tier = 'starter'}) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/subscriptions/$merchantId/activate'),
      headers: _headers,
      body: jsonEncode({'plan_type': planType, 'amount': amount, 'tier': tier}),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) return;
    throw Exception(data['message'] ?? 'Gagal mengaktifkan langganan');
  }

  /// POST /subscriptions/{id}/extend — perpanjang langganan
  Future<void> extendSubscription(int merchantId, String planType, double amount, {String tier = 'starter'}) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/subscriptions/$merchantId/extend'),
      headers: _headers,
      body: jsonEncode({'plan_type': planType, 'amount': amount, 'tier': tier}),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) return;
    throw Exception(data['message'] ?? 'Gagal memperpanjang langganan');
  }

  /// POST /subscriptions/{id}/suspend — suspend merchant
  Future<void> suspendMerchant(int merchantId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/subscriptions/$merchantId/suspend'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) return;
    throw Exception(data['message'] ?? 'Gagal men-suspend merchant');
  }

  /// POST /subscriptions/{id}/reset-trial — reset trial 7 hari
  Future<void> resetTrial(int merchantId) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/subscriptions/$merchantId/reset-trial'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) return;
    throw Exception(data['message'] ?? 'Gagal mereset trial');
  }

  // ── App Settings (Super Admin) ────────────────────────────────────────────

  /// GET /settings — ambil semua settings
  Future<Map<String, String>> fetchSettings() async {
    final response = await http.get(
      Uri.parse('${AppConstants.baseUrl}/settings'),
      headers: _headers,
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) {
      final list = data['data'] as List;
      return { for (final item in list) item['key'] as String : item['value'] as String? ?? '' };
    }
    throw Exception(data['message'] ?? 'Gagal memuat pengaturan');
  }

  /// PUT /settings — simpan settings
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final response = await http.put(
      Uri.parse('${AppConstants.baseUrl}/settings'),
      headers: _headers,
      body: jsonEncode({'settings': settings}),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true) return;
    throw Exception(data['message'] ?? 'Gagal menyimpan pengaturan');
  }
}
