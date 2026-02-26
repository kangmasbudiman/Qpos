<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Status Pendaftaran Merchant</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            background-color: #F4F5F7;
            color: #1A1D26;
        }
        .wrapper {
            max-width: 560px;
            margin: 32px auto;
            background: #ffffff;
            border-radius: 16px;
            overflow: hidden;
            box-shadow: 0 4px 20px rgba(0,0,0,0.08);
        }
        /* Header */
        .header {
            background: linear-gradient(135deg, #1E2235 0%, #2D3154 100%);
            padding: 32px 32px 28px;
            text-align: center;
        }
        .header-icon {
            width: 64px;
            height: 64px;
            background: rgba(255,255,255,0.12);
            border-radius: 50%;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 16px;
        }
        .header h1 {
            color: #ffffff;
            font-size: 22px;
            font-weight: 700;
            margin-bottom: 6px;
        }
        .header p {
            color: rgba(255,255,255,0.7);
            font-size: 14px;
        }
        /* Body */
        .body {
            padding: 32px;
        }
        .greeting {
            font-size: 15px;
            color: #1A1D26;
            margin-bottom: 12px;
        }
        .message {
            font-size: 14px;
            color: #555;
            line-height: 1.7;
            margin-bottom: 24px;
        }
        /* Reason box */
        .reason-box {
            background: #fff5f5;
            border: 1.5px solid #F44336;
            border-radius: 12px;
            padding: 20px 22px;
            margin-bottom: 24px;
        }
        .reason-label {
            font-size: 11px;
            color: #F44336;
            font-weight: 600;
            letter-spacing: 1.2px;
            text-transform: uppercase;
            margin-bottom: 8px;
        }
        .reason-text {
            font-size: 14px;
            color: #1A1D26;
            line-height: 1.65;
        }
        /* Info box */
        .info-box {
            background: #F8F9FA;
            border-radius: 10px;
            padding: 18px 20px;
            margin-bottom: 24px;
        }
        .info-box h3 {
            font-size: 13px;
            font-weight: 700;
            color: #1A1D26;
            margin-bottom: 12px;
        }
        .info-row {
            display: flex;
            font-size: 13px;
            color: #555;
            margin-bottom: 6px;
        }
        .info-row .label {
            width: 130px;
            flex-shrink: 0;
            color: #888;
        }
        /* Reapply note */
        .reapply {
            background: #FFF8E1;
            border-left: 4px solid #FF6B35;
            border-radius: 0 8px 8px 0;
            padding: 14px 16px;
            font-size: 13px;
            color: #555;
            line-height: 1.65;
            margin-bottom: 8px;
        }
        /* Footer */
        .footer {
            background: #F4F5F7;
            padding: 20px 32px;
            text-align: center;
            border-top: 1px solid #eee;
        }
        .footer p {
            font-size: 12px;
            color: #aaa;
            line-height: 1.6;
        }
        .badge-rejected {
            display: inline-block;
            background: #ffeaea;
            color: #F44336;
            font-size: 12px;
            font-weight: 600;
            padding: 4px 12px;
            border-radius: 20px;
            border: 1px solid #ffcdd2;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
<div class="wrapper">
    <!-- Header -->
    <div class="header">
        <div class="header-icon">
            <!-- info SVG -->
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M12 9v3.75m0 3.75h.008v.008H12v-.008zM21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                      stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
        </div>
        <h1>Informasi Pendaftaran</h1>
        <p>POS Offline System &mdash; Notifikasi Merchant</p>
    </div>

    <!-- Body -->
    <div class="body">
        <span class="badge-rejected">✕ Status: Tidak Disetujui</span>

        <p class="greeting">Halo, <strong>{{ $merchant->owner?->name ?? $merchant->name }}</strong></p>
        <p class="message">
            Terima kasih telah mendaftarkan usaha <strong>{{ $merchant->name }}</strong> ke platform POS Offline System.
            Setelah ditinjau oleh tim kami, pendaftaran Anda <strong>belum dapat disetujui</strong> saat ini
            dengan alasan sebagai berikut:
        </p>

        <!-- Alasan penolakan -->
        <div class="reason-box">
            <p class="reason-label">Alasan Penolakan</p>
            <p class="reason-text">{{ $rejectionReason }}</p>
        </div>

        <!-- Info -->
        <div class="info-box">
            <h3>Detail Pendaftaran</h3>
            <div class="info-row">
                <span class="label">Nama Usaha</span>
                <span>: {{ $merchant->name }}</span>
            </div>
            <div class="info-row">
                <span class="label">Email</span>
                <span>: {{ $merchant->owner?->email ?? $merchant->email }}</span>
            </div>
            <div class="info-row">
                <span class="label">Tanggal Ditolak</span>
                <span>: {{ now()->setTimezone('Asia/Jakarta')->format('d M Y, H:i') }} WIB</span>
            </div>
        </div>

        <!-- Ajukan ulang -->
        <div class="reapply">
            <strong>Ingin mendaftar ulang?</strong><br>
            Anda dapat memperbaiki data sesuai alasan di atas dan mengajukan pendaftaran baru
            melalui aplikasi POS Offline. Pilih menu <em>"Daftar Sekarang"</em> pada halaman login.
        </div>
    </div>

    <!-- Footer -->
    <div class="footer">
        <p>
            Email ini dikirim secara otomatis oleh sistem.<br>
            Jika Anda tidak merasa mendaftar, abaikan email ini.<br><br>
            &copy; {{ date('Y') }} POS Offline System. All rights reserved.
        </p>
    </div>
</div>
</body>
</html>
