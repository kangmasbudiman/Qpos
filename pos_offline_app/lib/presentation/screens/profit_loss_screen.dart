import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../services/report/profit_loss_service.dart';
import '../../services/auth/auth_service.dart';
import '../widgets/branch_filter_bar.dart';

class ProfitLossScreen extends StatefulWidget {
  const ProfitLossScreen({Key? key}) : super(key: key);

  @override
  State<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
  late ProfitLossService _svc;

  final _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _pct      = NumberFormat('0.##');

  // Warna
  static const _dark    = Color(0xFF1A1D26);
  static const _accent  = Color(0xFFFF6B35);
  static const _green   = Color(0xFF22C55E);
  static const _red     = Color(0xFFEF4444);
  static const _blue    = Color(0xFF3B82F6);
  static const _purple  = Color(0xFF8B5CF6);
  static const _bgGray  = Color(0xFFF4F5F7);

  // Filter periode
  String _selectedPeriod = 'Bulan ini';
  final List<String> _periods = ['Hari ini', 'Minggu ini', 'Bulan ini', 'Bulan lalu', 'Tahun ini', 'Kustom'];

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ProfitLossService>()) {
      Get.put(ProfitLossService());
    }
    _svc = Get.find<ProfitLossService>();
    _svc.loadReport();
  }

  void _applyPeriod(String period) {
    final now = DateTime.now();
    DateTime from, to;
    switch (period) {
      case 'Hari ini':
        from = DateTime(now.year, now.month, now.day);
        to   = now;
        break;
      case 'Minggu ini':
        from = now.subtract(Duration(days: now.weekday - 1));
        to   = now;
        break;
      case 'Bulan lalu':
        final first = DateTime(now.year, now.month - 1, 1);
        from = first;
        to   = DateTime(now.year, now.month, 0);
        break;
      case 'Tahun ini':
        from = DateTime(now.year, 1, 1);
        to   = now;
        break;
      case 'Kustom':
        _pickCustomRange();
        return;
      default: // Bulan ini
        from = DateTime(now.year, now.month, 1);
        to   = now;
    }
    setState(() => _selectedPeriod = period);
    _svc.setDateRange(from, to);
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _svc.dateFrom, end: _svc.dateTo),
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: _accent),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() => _selectedPeriod = 'Kustom');
      _svc.setDateRange(range.start, range.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGray,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildPeriodFilter(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: BranchFilterBar(onChanged: () => _svc.loadReport()),
            ),
            Expanded(
              child: Obx(() {
                if (_svc.isLoading && _svc.summary == null) {
                  return const Center(child: CircularProgressIndicator(color: _accent));
                }
                if (_svc.summary == null) {
                  return _buildEmpty();
                }
                return _buildContent(_svc.summary!);
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final branch = Get.find<AuthService>().selectedBranch;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E2235), Color(0xFF2D3154)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Laporan Laba Rugi',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                if (branch != null)
                  Row(children: [
                    const Icon(Icons.storefront_rounded, color: Colors.white54, size: 11),
                    const SizedBox(width: 4),
                    Text(branch.name, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ]),
              ],
            ),
          ),
          Obx(() => _svc.isLoading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: _svc.loadReport,
                )),
        ],
      ),
    );
  }

  // ── Period Filter ────────────────────────────────────────────────────────

  Widget _buildPeriodFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _periods.map((p) {
            final selected = _selectedPeriod == p;
            return GestureDetector(
              onTap: () => _applyPeriod(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? _accent : _bgGray,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(p,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? Colors.white : Colors.grey.shade600,
                  )),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Content ───────────────────────────────────────────────────────────────

  Widget _buildContent(ProfitLossSummary s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildProfitCard(s),
        const SizedBox(height: 12),
        _buildIncomeSection(s),
        const SizedBox(height: 12),
        _buildCogsSection(s),
        const SizedBox(height: 12),
        _buildProfitSection(s),
        const SizedBox(height: 12),
        if (s.topProducts.isNotEmpty) ...[
          _buildTopProducts(s.topProducts),
          const SizedBox(height: 12),
        ],
        if (s.paymentBreakdown.isNotEmpty) ...[
          _buildPaymentBreakdown(s.paymentBreakdown, s.netSales),
          const SizedBox(height: 12),
        ],
        if (s.dailyRevenue.isNotEmpty) ...[
          _buildDailyChart(s.dailyRevenue),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  // ── Profit Summary Card ───────────────────────────────────────────────────

  Widget _buildProfitCard(ProfitLossSummary s) {
    final isProfit = s.netProfit >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isProfit
              ? [const Color(0xFF16A34A), const Color(0xFF22C55E)]
              : [const Color(0xFFDC2626), const Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isProfit ? _green : _red).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isProfit ? 'LABA BERSIH' : 'RUGI BERSIH',
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(_currency.format(s.netProfit.abs()),
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: Colors.white, size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _profitStat('Margin', '${_pct.format(s.netMargin)}%'),
              _profitStat('Transaksi', s.totalTransactions.toString()),
              _profitStat('Penjualan', _shortCurrency(s.netSales)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profitStat(String label, String value) => Column(
    children: [
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
    ],
  );

  // ── Income Section ────────────────────────────────────────────────────────

  Widget _buildIncomeSection(ProfitLossSummary s) {
    return _sectionCard(
      icon: Icons.arrow_upward_rounded,
      iconColor: _green,
      title: 'Pendapatan',
      children: [
        _row('Penjualan Bruto', s.grossSales, color: _dark),
        _row('(-) Diskon', s.totalDiscount, color: _red, prefix: '-'),
        _row('(+) Pajak', s.totalTax, color: _blue, prefix: '+'),
        const Divider(height: 20),
        _row('Penjualan Bersih', s.netSales, color: _green, bold: true),
      ],
    );
  }

  // ── COGS Section ──────────────────────────────────────────────────────────

  Widget _buildCogsSection(ProfitLossSummary s) {
    return _sectionCard(
      icon: Icons.inventory_2_rounded,
      iconColor: _purple,
      title: 'Harga Pokok Penjualan (HPP)',
      children: [
        _row('HPP (qty × harga beli)', s.hpp, color: _red, prefix: '-'),
        const Divider(height: 20),
        _row('Laba Kotor', s.grossProfit, color: s.grossProfit >= 0 ? _green : _red, bold: true),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Margin Kotor: ${_pct.format(s.grossMargin)}%',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ),
      ],
    );
  }

  // ── Net Profit Section ────────────────────────────────────────────────────

  Widget _buildProfitSection(ProfitLossSummary s) {
    return _sectionCard(
      icon: Icons.account_balance_rounded,
      iconColor: _accent,
      title: 'Ringkasan Laba Rugi',
      children: [
        _row('Laba Kotor', s.grossProfit, color: s.grossProfit >= 0 ? _green : _red),
        const Divider(height: 20),
        _row(s.netProfit >= 0 ? 'LABA BERSIH' : 'RUGI BERSIH',
            s.netProfit.abs(),
            color: s.netProfit >= 0 ? _green : _red,
            bold: true),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Net Margin: ${_pct.format(s.netMargin)}%  •  Berbasis HPP barang terjual',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ),
        if (s.totalPurchases > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _blue.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 13, color: _blue),
                    const SizedBox(width: 6),
                    Text('Informasi Pembelian Stok',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _blue)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Pembelian (${s.totalPurchaseCount}x)',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    Text(_currency.format(s.totalPurchases),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _blue)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Pembelian stok dicatat sebagai penambahan aset, bukan pengurang laba. '
                  'Laba dihitung berdasarkan HPP barang yang sudah terjual.',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Top Products ──────────────────────────────────────────────────────────

  Widget _buildTopProducts(List<TopProductItem> items) {
    final maxRev = items.fold(0.0, (m, i) => i.revenue > m ? i.revenue : m);
    return _sectionCard(
      icon: Icons.star_rounded,
      iconColor: const Color(0xFFF59E0B),
      title: '5 Produk Terlaris',
      children: items.asMap().entries.map((e) {
        final idx  = e.key;
        final item = e.value;
        final ratio = maxRev > 0 ? item.revenue / maxRev : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 22, height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: idx == 0 ? const Color(0xFFF59E0B) : _bgGray,
                      shape: BoxShape.circle,
                    ),
                    child: Text('${idx + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: idx == 0 ? Colors.white : Colors.grey.shade600,
                        )),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.productName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_currency.format(item.revenue),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _green)),
                      Text('${item.qty} pcs', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: _bgGray,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    idx == 0 ? const Color(0xFFF59E0B) : _blue,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Payment Breakdown ─────────────────────────────────────────────────────

  Widget _buildPaymentBreakdown(List<PaymentBreakdownItem> items, double total) {
    final colors = [_blue, _green, _purple, _accent, const Color(0xFF06B6D4)];
    return _sectionCard(
      icon: Icons.payments_rounded,
      iconColor: _blue,
      title: 'Metode Pembayaran',
      children: items.asMap().entries.map((e) {
        final idx   = e.key;
        final item  = e.value;
        final pct   = total > 0 ? item.total / total : 0.0;
        final color = colors[idx % colors.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Container(width: 10, height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_paymentLabel(item.method),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        Text(_currency.format(item.total),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 4,
                        backgroundColor: _bgGray,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    Text('${(pct * 100).toStringAsFixed(1)}%  •  ${item.count} transaksi',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Daily Chart ───────────────────────────────────────────────────────────

  Widget _buildDailyChart(List<DailyRevenueItem> items) {
    final maxRev = items.fold(0.0, (m, i) => i.revenue > m ? i.revenue : m);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return _sectionCard(
      icon: Icons.bar_chart_rounded,
      iconColor: _accent,
      title: 'Pendapatan Harian',
      children: [
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: items.map((item) {
              final ratio   = maxRev > 0 ? item.revenue / maxRev : 0.0;
              final barH    = item.revenue > 0 ? (ratio * 100).clamp(4.0, 100.0) : 0.0;
              final isToday = item.date == todayStr;
              final dayLabel = _shortDayLabel(item.date);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 16,
                        child: item.revenue > 0
                            ? Text(_shortCurrency(item.revenue),
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 7, fontWeight: FontWeight.w600,
                                    color: isToday ? _accent : _blue))
                            : const SizedBox.shrink(),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: barH,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isToday
                                ? [_accent, const Color(0xFFEA580C)]
                                : [const Color(0xFF64B5F6), const Color(0xFF1565C0)],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 24,
                        child: Text(dayLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 8, height: 1.2,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? _accent : Colors.grey.shade500,
                            )),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Empty ─────────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_chart_outlined_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Tidak ada data', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Pilih periode lain atau sync data terlebih dahulu',
              style: TextStyle(color: Colors.grey.shade300, fontSize: 11)),
        ],
      ),
    );
  }

  // ── Helpers / Widgets ─────────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _dark)),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, double amount, {Color? color, bool bold = false, String prefix = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: bold ? _dark : Colors.grey.shade600,
              )),
          Text('$prefix${_currency.format(amount)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color ?? _dark,
              )),
        ],
      ),
    );
  }

  String _shortCurrency(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}jt';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}rb';
    return v.toStringAsFixed(0);
  }

  String _shortDayLabel(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final dayNames = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
      return '${dayNames[dt.weekday % 7]}\n${dt.day}';
    } catch (_) {
      return dateStr.length >= 5 ? dateStr.substring(5) : dateStr;
    }
  }

  String _paymentLabel(String method) {
    const labels = {
      'cash': 'Tunai', 'card': 'Kartu', 'transfer': 'Transfer',
      'ewallet': 'E-Wallet', 'debit': 'Debit', 'credit': 'Kredit',
      'qris': 'QRIS', 'mixed': 'Campuran',
    };
    return labels[method] ?? method;
  }
}
