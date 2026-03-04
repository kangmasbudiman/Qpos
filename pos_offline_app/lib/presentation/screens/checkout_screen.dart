import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/pos_controller.dart';
import '../widgets/connectivity_indicator.dart';
import '../../services/auth/auth_service.dart';
import '../../services/loyalty/loyalty_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({Key? key}) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final POSController _controller;
  late final TextEditingController _notesController;
  late final TextEditingController _cashController;
  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // Loyalty state
  LoyaltyService? _loyaltySvc;
  Map<String, dynamic>? _memberInfo;
  final _redeemPointsCtrl = TextEditingController();
  final RxInt _redeemPoints = 0.obs;
  final RxDouble _redeemDiscount = 0.0.obs;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<POSController>();
    _notesController = TextEditingController();
    _cashController = TextEditingController();
    try { _loyaltySvc = Get.find<LoyaltyService>(); } catch (_) {}
  }

  @override
  void dispose() {
    _notesController.dispose();
    _cashController.dispose();
    _redeemPointsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMemberInfo() async {
    final customer = _controller.selectedCustomer;
    if (customer == null || _loyaltySvc == null) {
      setState(() { _memberInfo = null; _redeemPoints.value = 0; _redeemDiscount.value = 0; });
      return;
    }
    final info = await _loyaltySvc!.getMemberInfo(customer.id!);
    if (mounted) setState(() { _memberInfo = info; _redeemPoints.value = 0; _redeemDiscount.value = 0; _redeemPointsCtrl.clear(); });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Obx(() {
        if (_controller.cartItems.isEmpty) {
          return _buildEmptyCart();
        }
        if (isTablet) {
          return _buildTabletLayout();
        }
        return _buildPhoneLayout();
      }),
    );
  }

  Widget _buildPhoneLayout() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCartItemsSection(),
              const SizedBox(height: 12),
              _buildPaymentMethodSection(),
              const SizedBox(height: 12),
              _buildCustomerSection(),
              const SizedBox(height: 12),
              _buildLoyaltySection(),
              const SizedBox(height: 12),
              _buildNotesSection(),
              const SizedBox(height: 12),
              _buildOrderSummary(),
              const SizedBox(height: 100),
            ],
          ),
        ),
        _buildCheckoutButton(),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Column(
      children: [
        _buildHeader(isTablet: true),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Cart Items
              Expanded(
                flex: 3,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildCartItemsSection(),
                    const SizedBox(height: 16),
                    _buildCustomerSection(),
                    const SizedBox(height: 16),
                    _buildLoyaltySection(),
                    const SizedBox(height: 16),
                    _buildNotesSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // Divider
              Container(width: 1, color: const Color(0xFFE8E9EF)),
              // Right: Payment + Summary + Button
              SizedBox(
                width: 340,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          _buildPaymentMethodSection(),
                          const SizedBox(height: 16),
                          _buildOrderSummary(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: _buildCheckoutButton(fullWidth: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader({bool isTablet = false}) {
    final h = isTablet ? 24.0 : 16.0;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: h,
        right: h,
        bottom: 12,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1D26), size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Checkout',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1D26),
            ),
          ),
          const Spacer(),
          const ConnectivityDot(),
        ],
      ),
    );
  }

  // ── EMPTY CART ────────────────────────────────────────────────────────────
  Widget _buildEmptyCart() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.shopping_cart_outlined, size: 40, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 16),
                  Text('Keranjang kosong',
                      style: TextStyle(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text('Tambahkan produk terlebih dahulu',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Kembali ke Kasir',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CART ITEMS ────────────────────────────────────────────────────────────
  Widget _buildCartItemsSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE0D0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFFF6B35), size: 16),
              ),
              const SizedBox(width: 8),
              Obx(() => Text(
                'Item Pesanan (${_controller.cartItems.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1D26),
                ),
              )),
            ],
          ),
          const SizedBox(height: 14),
          Obx(() => Column(
            children: _controller.cartItems
                .map((item) => _buildCartItemRow(item))
                .toList(),
          )),
        ],
      ),
    );
  }

  Widget _buildCartItemRow(CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar produk
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE0D0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    item.product.name[0].toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFFFF6B35), fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1A1D26))),
                    Text(
                      _currency.format(item.product.price),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Text(
                _currency.format(item.subtotal),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1D26)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Qty controls
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    _qtyBtn(Icons.remove_rounded,
                        () => _controller.updateCartItemQuantity(item.product.id!, item.quantity - 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('${item.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    _qtyBtn(Icons.add_rounded,
                        () => _controller.updateCartItemQuantity(item.product.id!, item.quantity + 1),
                        filled: true),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Diskon
              Expanded(
                child: GestureDetector(
                  onTap: () => _showDiscountDialog(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: item.discount > 0
                          ? const Color(0xFFFFE0D0)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: item.discount > 0
                            ? const Color(0xFFFF6B35)
                            : Colors.grey[200]!,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_offer_outlined,
                            size: 13,
                            color: item.discount > 0
                                ? const Color(0xFFFF6B35)
                                : Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          item.discount > 0
                              ? item.discountIsPercent
                                  ? '${item.discount.toStringAsFixed(0)}%  (-${_currency.format(item.totalDiscount)})'
                                  : '- ${_currency.format(item.discount)}'
                              : 'Diskon',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: item.discount > 0
                                ? const Color(0xFFFF6B35)
                                : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Hapus
              GestureDetector(
                onTap: () => _controller.removeFromCart(item.product.id!),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete_outline_rounded, color: Colors.red[400], size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, {bool filled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF1A1D26) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 14, color: filled ? Colors.white : const Color(0xFF1A1D26)),
      ),
    );
  }

  // ── PAYMENT METHOD (Multi-Payment) ────────────────────────────────────────
  final TextEditingController _multiPayAmountCtrl = TextEditingController();
  String _multiPaySelectedMethod = 'cash';

  Widget _buildPaymentMethodSection() {
    final sub = Get.find<AuthService>().subscription;
    final hasMultiPayment = sub?.hasFeature('multi_payment') ?? true;
    final methods = [
      {'id': 'cash',   'label': 'Tunai',  'icon': Icons.payments_outlined},
      {'id': 'debit',  'label': 'Debit',  'icon': Icons.credit_card_outlined},
      {'id': 'credit', 'label': 'Kredit', 'icon': Icons.credit_card_outlined},
      {'id': 'qris',   'label': 'QRIS',   'icon': Icons.qr_code_2_rounded},
    ];

    return _buildCard(
      child: StatefulBuilder(
        builder: (ctx, setS) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0E8FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payment_rounded, color: Color(0xFF2196F3), size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text('Metode Pembayaran',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1D26))),
                  const Spacer(),
                  // Toggle split payment hint
                  Obx(() => _controller.paymentEntries.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD0E8FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Split ${_controller.paymentEntries.length}x',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF2196F3), fontWeight: FontWeight.w600),
                          ),
                        )
                      : const SizedBox.shrink()),
                ],
              ),
              const SizedBox(height: 14),

              // Payment method tabs (untuk menambah entry)
              Row(
                children: methods.map((m) {
                  final isSelected = _multiPaySelectedMethod == m['id'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setS(() => _multiPaySelectedMethod = m['id'] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1A1D26) : const Color(0xFFF4F5F7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              m['icon'] as IconData,
                              size: 16,
                              color: isSelected ? const Color(0xFFFF6B35) : Colors.grey[500],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              m['label'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Jumlah input + tombol tambah (Business only — multi-payment)
              if (!hasMultiPayment) ...[
                // Starter: pesan upgrade
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 14, color: Color(0xFFE65100)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Multi-payment hanya tersedia di tier Business.',
                          style: TextStyle(fontSize: 11, color: Color(0xFFE65100)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5F7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: TextField(
                        controller: _multiPayAmountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Jumlah bayar',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400], fontWeight: FontWeight.normal),
                          prefixText: 'Rp ',
                          prefixStyle: const TextStyle(fontSize: 13, color: Color(0xFF1A1D26)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final amount = double.tryParse(_multiPayAmountCtrl.text) ?? 0;
                      if (amount <= 0) return;
                      _controller.addPaymentEntry(_multiPaySelectedMethod, amount);
                      _multiPayAmountCtrl.clear();
                    },
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text('Tambah', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Tampilkan payment entries
              Obx(() {
                if (_controller.paymentEntries.isEmpty) return const SizedBox.shrink();
                final methodLabel = {'cash': 'Tunai', 'debit': 'Debit', 'credit': 'Kredit', 'qris': 'QRIS'};
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F8FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFB3D9FF)),
                      ),
                      child: Column(
                        children: [
                          ..._controller.paymentEntries.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final e = entry.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      methodLabel[e['method']] ?? e['method'].toString(),
                                      style: const TextStyle(
                                          fontSize: 11, color: Color(0xFF2196F3), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _currency.format(e['amount'] as num),
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1D26)),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => _controller.removePaymentEntry(idx),
                                    child: Icon(Icons.close_rounded, size: 16, color: Colors.red[400]),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 12, thickness: 1, color: Color(0xFFB3D9FF)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Bayar',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                              Text(_currency.format(_controller.totalPaid),
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2196F3))),
                            ],
                          ),
                          if (_controller.remainingAmount > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Sisa', style: TextStyle(fontSize: 12, color: Colors.red[600])),
                                Text(
                                  _currency.format(_controller.remainingAmount),
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red[600]),
                                ),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Kembalian', style: TextStyle(fontSize: 12, color: Colors.green[700])),
                                Text(
                                  _currency.format(_controller.totalPaid - _controller.totalAmount),
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green[700]),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }),

              // Quick pay: tombol "Bayar Semua" (single method)
              Obx(() {
                if (_controller.paymentEntries.isNotEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text('Atau bayar langsung:',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () {
                        _controller.addPaymentEntry(_multiPaySelectedMethod, _controller.totalAmount);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F5F7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFFF6B35)),
                            const SizedBox(width: 6),
                            Text(
                              'Bayar Penuh  ${_currency.format(_controller.totalAmount)}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1D26)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
              ], // end else hasMultiPayment
            ],
          );
        },
      ),
    );
  }

  // ── CUSTOMER ──────────────────────────────────────────────────────────────
  Widget _buildCustomerSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD0F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_outline_rounded, color: Color(0xFF9C27B0), size: 16),
              ),
              const SizedBox(width: 8),
              const Text('Pelanggan',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1D26))),
              const Spacer(),
              Obx(() => _controller.selectedCustomer != null
                  ? GestureDetector(
                      onTap: () { _controller.clearCustomer(); _loadMemberInfo(); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Hapus',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[400],
                                fontWeight: FontWeight.w600)),
                      ),
                    )
                  : const SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            final customer = _controller.selectedCustomer;

            // ── Customer terpilih ──
            if (customer != null) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE040FB), Color(0xFF9C27B0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(customer.name[0].toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF1A1D26))),
                          if (customer.phone != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.phone_outlined, size: 11, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(customer.phone!,
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _showCustomerPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD0F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Ganti',
                            style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9C27B0),
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              );
            }

            // ── Belum pilih customer ──
            return Column(
              children: [
                // Info walk-in
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFD9B8)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 15, color: Color(0xFFFF6B35)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tanpa pelanggan, transaksi dicatat sebagai Walk-in Customer',
                          style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Tombol pilih / tambah
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _showCustomerPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F5F7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_rounded, color: Colors.grey[500], size: 16),
                              const SizedBox(width: 6),
                              Text('Cari Pelanggan',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showAddCustomerSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE040FB), Color(0xFF9C27B0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9C27B0).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.person_add_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text('Tambah Baru',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _showCustomerPicker() {
    // Controller search lokal untuk filter dalam bottom sheet
    final searchCtrl = TextEditingController();
    final filteredObs = _controller.customers.obs;

    void doFilter(String q) {
      final all = _controller.customers;
      filteredObs.value = q.isEmpty
          ? all
          : all
              .where((c) =>
                  c.name.toLowerCase().contains(q.toLowerCase()) ||
                  (c.phone?.contains(q) ?? false))
              .toList();
    }

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setBS) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),

              // Title + tombol tambah
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text('Pilih Pelanggan',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Get.back(); // tutup picker
                        _showAddCustomerSheet();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE040FB), Color(0xFF9C27B0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('Tambah',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F5F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: TextField(
                    controller: searchCtrl,
                    onChanged: (v) {
                      doFilter(v);
                    },
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau nomor HP...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Divider
              Container(height: 1, color: Colors.grey[100]),

              // List
              Expanded(
                child: Obx(() {
                  final filteredList = filteredObs.toList();
                  final customers = filteredList.isEmpty && searchCtrl.text.isEmpty
                      ? _controller.customers
                      : filteredList;

                  if (_controller.customers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Belum ada pelanggan',
                              style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500)),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () {
                              Get.back();
                              _showAddCustomerSheet();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9C27B0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('Tambah Pelanggan Pertama',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (customers.isEmpty) {
                    return Center(
                      child: Text('Tidak ditemukan',
                          style: TextStyle(color: Colors.grey[400])),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: customers.length,
                    separatorBuilder: (_, __) => Container(
                      height: 1, margin: const EdgeInsets.symmetric(horizontal: 20),
                      color: Colors.grey[100],
                    ),
                    itemBuilder: (_, i) {
                      final c = customers[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE040FB), Color(0xFF9C27B0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(c.name[0].toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                          ),
                        ),
                        title: Text(c.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: c.phone != null
                            ? Row(
                                children: [
                                  Icon(Icons.phone_outlined, size: 11, color: Colors.grey[400]),
                                  const SizedBox(width: 4),
                                  Text(c.phone!,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                ],
                              )
                            : null,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F5F7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Pilih',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF9C27B0))),
                        ),
                        onTap: () {
                          _controller.setCustomer(c);
                          Get.back();
                          _loadMemberInfo();
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  // ── FORM TAMBAH CUSTOMER CEPAT ──────────────────────────────────────────
  void _showAddCustomerSheet() {
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey   = GlobalKey<FormState>();
    var   isLoading = false; // di luar builder agar tidak di-reset saat rebuild

    Get.bottomSheet(
      StatefulBuilder(
        builder: (ctx, setBS) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE040FB), Color(0xFF9C27B0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Text('Tambah Pelanggan Baru',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Nama *
                    _addCustField(
                      controller: nameCtrl,
                      label: 'Nama Pelanggan',
                      hint: 'Contoh: Budi Santoso',
                      icon: Icons.person_outline_rounded,
                      required: true,
                    ),
                    const SizedBox(height: 12),

                    // No HP
                    _addCustField(
                      controller: phoneCtrl,
                      label: 'Nomor HP',
                      hint: '08xxxxxxxxxx',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 12),

                    // Email
                    _addCustField(
                      controller: emailCtrl,
                      label: 'Email',
                      hint: 'email@contoh.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),

                    // Tombol simpan
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (!(formKey.currentState?.validate() ?? false)) return;
                                setBS(() => isLoading = true);
                                final ok = await _controller.addCustomer(
                                  name:  nameCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                                  email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                                );
                                if (ok) {
                                  Navigator.of(ctx).pop();
                                } else {
                                  setBS(() => isLoading = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9C27B0),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                              )
                            : const Text('Simpan & Pilih',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _addCustField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1D26))),
            if (required)
              const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: const TextStyle(fontSize: 14),
            validator: required
                ? (v) => (v == null || v.trim().isEmpty) ? '$label wajib diisi' : null
                : null,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              prefixIcon: Icon(icon, size: 18, color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              errorStyle: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  // ── LOYALTY POINTS ────────────────────────────────────────────────────────
  Widget _buildLoyaltySection() {
    // Hanya Business tier yang punya fitur loyalty
    final sub = Get.find<AuthService>().subscription;
    if (!(sub?.hasFeature('loyalty') ?? true)) return const SizedBox.shrink();
    if (_loyaltySvc == null) return const SizedBox.shrink();

    // Jika belum pilih customer → tampilkan hint
    if (_controller.selectedCustomer == null) {
      return _buildCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.stars_rounded, color: Color(0xFFFF9800), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Loyalty Points',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1D26))),
                  Text('Pilih pelanggan untuk gunakan poin',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Customer terpilih tapi data belum dimuat
    if (_memberInfo == null) {
      return _buildCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.stars_rounded, color: Color(0xFFFF9800), size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Memuat data poin...', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const Spacer(),
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF9800))),
          ],
        ),
      );
    }

    final balance    = _memberInfo!['points_balance'] as int? ?? 0;
    final tier       = _memberInfo!['tier'] as String? ?? 'bronze';
    final tierEmoji  = tier == 'gold' ? '🥇' : (tier == 'silver' ? '🥈' : '🥉');
    final tierColor  = tier == 'gold'
        ? const Color(0xFFFFD700)
        : (tier == 'silver' ? const Color(0xFF9E9E9E) : const Color(0xFFCD7F32));

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.stars_rounded, color: Color(0xFFFF9800), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Loyalty Points',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1D26))),
                    Row(
                      children: [
                        Text(tierEmoji, style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 3),
                        Text(tier.toUpperCase(),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tierColor)),
                        const SizedBox(width: 8),
                        Text('Saldo: ',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        Text('$balance poin',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF9800))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (balance > 0) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.grey[100]),
            const SizedBox(height: 12),

            // Redeem input
            Text('Tukarkan Poin (maks $balance poin = ${_currency.format(_loyaltySvc!.pointsToRupiah(balance))})',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: TextField(
                      controller: _redeemPointsCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        suffixText: 'poin',
                        suffixStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                      onChanged: (v) {
                        final pts = int.tryParse(v) ?? 0;
                        final clamped = pts.clamp(0, balance);
                        _redeemPoints.value = clamped;
                        _redeemDiscount.value = _loyaltySvc!.pointsToRupiah(clamped);
                        if (pts > balance) {
                          _redeemPointsCtrl.text = '$balance';
                          _redeemPointsCtrl.selection = TextSelection.collapsed(offset: '$balance'.length);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Obx(() => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _redeemDiscount.value > 0
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                        : const Color(0xFFF4F5F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _redeemDiscount.value > 0
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                          : Colors.grey[200]!,
                    ),
                  ),
                  child: Text(
                    _redeemDiscount.value > 0
                        ? '- ${_currency.format(_redeemDiscount.value)}'
                        : 'Rp 0',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _redeemDiscount.value > 0
                          ? const Color(0xFF4CAF50)
                          : Colors.grey[400],
                    ),
                  ),
                )),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text('Belum ada poin. Poin akan diperoleh setelah transaksi.',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ],
        ],
      ),
    );
  }

  // ── NOTES ─────────────────────────────────────────────────────────────────
  Widget _buildNotesSection() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.notes_rounded, color: Colors.grey[500], size: 16),
              ),
              const SizedBox(width: 8),
              const Text('Catatan',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1D26))),
              const SizedBox(width: 6),
              Text('(opsional)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: TextField(
              controller: _notesController,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Tambahkan catatan untuk transaksi ini...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ORDER SUMMARY ─────────────────────────────────────────────────────────
  Widget _buildOrderSummary() {
    return _buildCard(
      child: Obx(() {
        final subtotal        = _controller.totalAmount + _controller.totalDiscount;
        final discount        = _controller.totalDiscount;
        final loyaltyDiscount = _redeemDiscount.value;
        final total           = (_controller.totalAmount - loyaltyDiscount).clamp(0.0, double.infinity);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ringkasan Pesanan',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1D26))),
            const SizedBox(height: 14),
            _sumRow('Subtotal', _currency.format(subtotal)),
            if (discount > 0)
              _sumRow('Diskon Item', '- ${_currency.format(discount)}', valueColor: Colors.red[600]),
            if (loyaltyDiscount > 0)
              _sumRow('Diskon Poin', '- ${_currency.format(loyaltyDiscount)}',
                  valueColor: const Color(0xFF4CAF50)),
            const SizedBox(height: 8),
            Container(height: 1, color: Colors.grey[200]),
            const SizedBox(height: 8),
            _sumRow('Total', _currency.format(total), bold: true, fontSize: 17),
            if (_controller.selectedPaymentMethod == 'cash' && _controller.cashAmount > 0) ...[
              const SizedBox(height: 4),
              _sumRow('Tunai', _currency.format(_controller.cashAmount),
                  valueColor: const Color(0xFF4CAF50)),
              if (_controller.cashAmount > total)
                _sumRow('Kembalian', _currency.format(_controller.cashAmount - total),
                    valueColor: const Color(0xFF4CAF50)),
            ],
          ],
        );
      }),
    );
  }

  Widget _sumRow(String label, String value,
      {bool bold = false, double fontSize = 13, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: fontSize,
                color: bold ? const Color(0xFF1A1D26) : Colors.grey[500],
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              )),
          Text(value,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? const Color(0xFF1A1D26),
              )),
        ],
      ),
    );
  }

  // ── CHECKOUT BUTTON ───────────────────────────────────────────────────────
  Widget _buildCheckoutButton({bool fullWidth = false}) {
    final bottomPad = fullWidth ? 0.0 : MediaQuery.of(context).padding.bottom + 12;
    return Container(
      padding: EdgeInsets.fromLTRB(fullWidth ? 0 : 16, fullWidth ? 0 : 12, fullWidth ? 0 : 16, bottomPad),
      decoration: fullWidth ? null : const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -4)),
        ],
      ),
      child: Obx(() {
        final isProcessing = _controller.isProcessingTransaction;
        final hasPaymentEntries = _controller.paymentEntries.isNotEmpty;
        final loyaltyDiscount = _redeemDiscount.value;
        final effectiveTotal = (_controller.totalAmount - loyaltyDiscount).clamp(0.0, double.infinity);

        // Starter tier: tidak ada multi-payment, cukup pilih metode → bayar penuh
        final sub = Get.find<AuthService>().subscription;
        final hasMultiPayment = sub?.hasFeature('multi_payment') ?? true;
        final isStarterSinglePay = !hasMultiPayment && !hasPaymentEntries;
        final canPay = isStarterSinglePay ? true : _controller.canProcessPayment;

        String btnLabel;
        if (!canPay) {
          btnLabel = hasPaymentEntries
              ? 'Kurang ${_currency.format(_controller.remainingAmount)}'
              : 'Tambah pembayaran';
        } else {
          btnLabel = 'Proses Pembayaran  •  ${_currency.format(effectiveTotal)}';
        }

        return SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isProcessing || !canPay
                ? null
                : () => _processCheckout(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: isProcessing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(btnLabel,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
          ),
        );
      }),
    );
  }

  // ── DIALOG DISKON (Enhanced) ───────────────────────────────────────────────
  void _showDiscountDialog(CartItem item) {
    // Diskon per item hanya untuk Business tier
    final sub = Get.find<AuthService>().subscription;
    if (!(sub?.hasFeature('item_discount') ?? true)) {
      Get.snackbar(
        'Fitur Terkunci',
        'Diskon per item hanya tersedia di tier Business.',
        backgroundColor: const Color(0xFF1A1D2E),
        colorText: Colors.white,
        icon: const Icon(Icons.lock_rounded, color: Colors.white),
        duration: const Duration(seconds: 3),
      );
      return;
    }
    bool isPercent = item.discountIsPercent;
    final discountCtrl = TextEditingController(
        text: item.discount > 0 ? item.discount.toStringAsFixed(0) : '');
    final gross = item.product.price * item.quantity;
    final quickPercents = [5, 10, 15, 20, 25, 50];

    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setS) {
          final rawVal = double.tryParse(discountCtrl.text) ?? 0;
          final discountNominal = isPercent ? gross * rawVal / 100 : rawVal;
          final finalPrice = gross - discountNominal;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE0D0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_offer_outlined, color: Color(0xFFFF6B35), size: 16),
                ),
                const SizedBox(width: 10),
                const Text('Diskon Item',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1D26))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product info
                Text(item.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('${item.quantity}× ${_currency.format(item.product.price)} = ${_currency.format(gross)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 14),

                // Toggle nominal/persen
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F5F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setS(() { isPercent = false; discountCtrl.clear(); }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: !isPercent ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: !isPercent
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 4)]
                                  : [],
                            ),
                            child: Center(
                              child: Text('Nominal (Rp)',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: !isPercent ? const Color(0xFF1A1D26) : Colors.grey[400])),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setS(() { isPercent = true; discountCtrl.clear(); }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isPercent ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: isPercent
                                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 4)]
                                  : [],
                            ),
                            child: Center(
                              child: Text('Persen (%)',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isPercent ? const Color(0xFF1A1D26) : Colors.grey[400])),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Input field
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F5F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.3)),
                  ),
                  child: TextField(
                    controller: discountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1D26)),
                    decoration: InputDecoration(
                      hintText: '0',
                      prefixText: isPercent ? '' : 'Rp ',
                      suffixText: isPercent ? '%' : '',
                      prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1D26)),
                      suffixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF6B35)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      hintStyle: TextStyle(color: Colors.grey[300], fontWeight: FontWeight.normal),
                    ),
                    onChanged: (_) => setS(() {}),
                  ),
                ),

                // Quick persen buttons (hanya saat mode persen)
                if (isPercent) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: quickPercents.map((p) {
                      return GestureDetector(
                        onTap: () {
                          discountCtrl.text = p.toString();
                          setS(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: discountCtrl.text == p.toString()
                                ? const Color(0xFFFF6B35)
                                : const Color(0xFFF4F5F7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: discountCtrl.text == p.toString()
                                  ? const Color(0xFFFF6B35)
                                  : Colors.grey[200]!,
                            ),
                          ),
                          child: Text('$p%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: discountCtrl.text == p.toString()
                                    ? Colors.white
                                    : Colors.grey[600],
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Preview harga setelah diskon
                if (rawVal > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: finalPrice >= 0 ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: finalPrice >= 0 ? Colors.green[200]! : Colors.red[200]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Diskon: -${_currency.format(discountNominal)}',
                            style: TextStyle(fontSize: 12, color: Colors.green[700])),
                        Text(
                          finalPrice >= 0 ? _currency.format(finalPrice) : 'Melebihi harga!',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: finalPrice >= 0 ? const Color(0xFF1A1D26) : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
              ),
              if (item.discount > 0)
                TextButton(
                  onPressed: () {
                    _controller.updateCartItemDiscount(item.product.id!, 0, isPercent: false);
                    Get.back();
                  },
                  child: Text('Hapus Diskon', style: TextStyle(color: Colors.red[400], fontSize: 12)),
                ),
              ElevatedButton(
                onPressed: () {
                  final rawDiscount = double.tryParse(discountCtrl.text) ?? 0;
                  final discNominal = isPercent ? gross * rawDiscount / 100 : rawDiscount;
                  if (discNominal > gross) {
                    Get.snackbar('Tidak Valid', 'Diskon tidak boleh melebihi harga',
                        backgroundColor: Colors.red, colorText: Colors.white);
                    return;
                  }
                  _controller.updateCartItemDiscount(item.product.id!, rawDiscount,
                      isPercent: isPercent);
                  Get.back();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Terapkan'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── KONFIRMASI & PROSES ───────────────────────────────────────────────────
  Future<void> _processCheckout() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Pembayaran',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1D26))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _dialogRow('Total',
                      _currency.format(_controller.totalAmount),
                      bold: true, valueColor: const Color(0xFFFF6B35)),
                  if (_controller.paymentEntries.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ..._controller.paymentEntries.map((e) {
                      const ml = {'cash': 'Tunai', 'debit': 'Debit', 'credit': 'Kredit', 'qris': 'QRIS'};
                      return _dialogRow(
                        ml[e['method']] ?? e['method'].toString(),
                        _currency.format(e['amount'] as num),
                      );
                    }),
                    _dialogRow('Kembalian',
                        _currency.format(_controller.totalPaid - _controller.totalAmount),
                        valueColor: const Color(0xFF4CAF50)),
                  ] else ...[
                    _dialogRow('Metode',
                        _controller.selectedPaymentMethod.toUpperCase()),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Starter tier: auto-set cashAmount = totalAmount sebelum proses
      final sub = Get.find<AuthService>().subscription;
      final hasMultiPayment = sub?.hasFeature('multi_payment') ?? true;
      if (!hasMultiPayment && _controller.paymentEntries.isEmpty) {
        _controller.updateCashAmount(_controller.totalAmount);
      }

      final customer       = _controller.selectedCustomer;
      final redeemPts      = _redeemPoints.value;
      final redeemDisc     = _redeemDiscount.value;
      final effectiveTotal = (_controller.totalAmount - redeemDisc).clamp(0.0, double.infinity);

      final success = await _controller.processPayment(
          notes: _notesController.text.isNotEmpty ? _notesController.text : null);
      if (success) {
        if (_loyaltySvc != null && customer != null) {
          try {
            // Redeem poin (setelah transaksi berhasil, aman untuk deduct)
            if (redeemPts > 0) {
              await _loyaltySvc!.redeemPoints(customer.id!, redeemPts);
            }
            // Earn poin dari total efektif
            final earned = await _loyaltySvc!.earnPoints(customer.id!, 0, effectiveTotal);
            if (earned > 0) {
              Get.snackbar(
                'Poin Loyalty',
                '+$earned poin untuk ${customer.name}!',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: const Color(0xFFFF9800),
                colorText: Colors.white,
                duration: const Duration(seconds: 3),
                icon: const Icon(Icons.stars_rounded, color: Colors.white),
              );
            }
          } catch (_) {}
        }
        Get.back();
      }
    }
  }

  Widget _dialogRow(String label, String value, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          Text(value,
              style: TextStyle(
                fontSize: bold ? 16 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? const Color(0xFF1A1D26),
              )),
        ],
      ),
    );
  }

  // ── HELPER ────────────────────────────────────────────────────────────────
  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}
