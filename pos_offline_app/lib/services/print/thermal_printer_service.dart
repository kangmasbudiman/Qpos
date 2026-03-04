import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/models/sale_model.dart';
import '../../services/auth/auth_service.dart';

/// Service untuk cetak struk menggunakan PDF (via package `printing`).
/// Mendukung print ke printer WiFi, USB, dan PDF viewer.
///
/// Catatan: Bluetooth thermal printer belum didukung secara langsung
/// karena package bluetooth (blue_thermal_printer / flutter_bluetooth_serial)
/// belum kompatibel dengan AGP 8.7+.
/// Sebagai workaround, gunakan fitur share PDF ke printer Bluetooth
/// via sistem operasi Android.
class ThermalPrinterService extends GetxService {
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  // ─── Main print method ────────────────────────────────────────────────────

  Future<void> printReceipt(Sale sale,
      {List<Map<String, dynamic>>? paymentEntries}) async {
    await _printViaPdf(sale, paymentEntries: paymentEntries);
  }

  // ─── PDF Print ────────────────────────────────────────────────────────────

  Future<void> _printViaPdf(Sale sale,
      {List<Map<String, dynamic>>? paymentEntries}) async {
    try {
      // Ambil info toko dari AuthService
      final auth       = Get.find<AuthService>();
      final storeName  = auth.currentUser?.companyName ?? 'Toko Kami';
      final branchName = auth.selectedBranch?.name;

      final methodLabel = {
        'cash': 'Tunai',
        'debit': 'Debit',
        'credit': 'Kredit',
        'qris': 'QRIS',
      };

      // Load logo Payzen dari assets
      pw.MemoryImage? logoImage;
      try {
        final ByteData data = await rootBundle.load('assets/animations/payzen.png');
        logoImage = pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {}

      final pdf = pw.Document();

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Logo Payzen
              if (logoImage != null) ...[
                pw.Center(
                  child: pw.Image(logoImage, width: 50, height: 50, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(height: 4),
              ],

              // Nama toko
              pw.Center(
                child: pw.Text(storeName.toUpperCase(),
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 13)),
              ),
              if (branchName != null)
                pw.Center(
                  child: pw.Text(branchName,
                      style: const pw.TextStyle(fontSize: 9)),
                ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text('STRUK PENJUALAN',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ),
              pw.SizedBox(height: 6),
              pw.Text('No: ${sale.invoiceNumber}',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Text(
                  'Tgl: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(sale.createdAt))}',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Kasir: ${sale.cashierName ?? '-'}',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(),

              // Items
              ...?(sale.items?.map((item) => pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                                '${item.productName} ×${item.quantity}',
                                style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Text(currency.format(item.subtotal),
                              style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                      if (item.discount > 0)
                        pw.Text('  Diskon: -${currency.format(item.discount)}',
                            style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ))),

              pw.Divider(),

              if (sale.discount > 0)
                _pdfRow('Diskon', '-${currency.format(sale.discount)}'),
              _pdfRow('TOTAL', currency.format(sale.total), bold: true),

              pw.Divider(),

              // Payment info
              if (paymentEntries != null && paymentEntries.isNotEmpty) ...[
                ...paymentEntries.map((e) => _pdfRow(
                    methodLabel[e['method']] ?? e['method'].toString(),
                    currency.format(e['amount'] as num))),
                _pdfRow(
                  'Kembalian',
                  currency.format(paymentEntries.fold<double>(
                          0.0, (s, e) => s + (e['amount'] as num).toDouble()) -
                      sale.total),
                ),
              ] else if (sale.paymentMethod == 'cash') ...[
                _pdfRow('Tunai', currency.format(sale.cash)),
                _pdfRow('Kembalian', currency.format(sale.change)),
              ] else
                _pdfRow('Pembayaran', sale.paymentMethod.toUpperCase()),

              pw.Divider(),
              pw.Center(
                child: pw.Text('Terima Kasih!',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ),
            ],
          );
        },
      ));

      final Uint8List bytes = await pdf.save();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      Get.snackbar('Error Cetak', 'Gagal membuat PDF struk: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    final style = bold
        ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)
        : const pw.TextStyle(fontSize: 9);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}
