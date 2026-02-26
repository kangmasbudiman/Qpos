<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pendaftaran Merchant Disetujui</title>
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
        /* Code box */
        .code-box {
            background: #f0fdf4;
            border: 2px solid #4CAF50;
            border-radius: 12px;
            padding: 24px;
            text-align: center;
            margin-bottom: 24px;
        }
        .code-label {
            font-size: 11px;
            color: #888;
            font-weight: 600;
            letter-spacing: 1.5px;
            text-transform: uppercase;
            margin-bottom: 10px;
        }
        .code-value {
            font-size: 36px;
            font-weight: 800;
            color: #4CAF50;
            letter-spacing: 8px;
            font-family: 'Courier New', monospace;
        }
        .code-hint {
            font-size: 12px;
            color: #888;
            margin-top: 10px;
        }
        /* Info list */
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
        /* Steps */
        .steps {
            margin-bottom: 24px;
        }
        .steps h3 {
            font-size: 13px;
            font-weight: 700;
            color: #1A1D26;
            margin-bottom: 12px;
        }
        .step {
            display: flex;
            align-items: flex-start;
            margin-bottom: 10px;
            font-size: 13px;
            color: #555;
        }
        .step-num {
            width: 24px;
            height: 24px;
            background: #FF6B35;
            color: #fff;
            border-radius: 50%;
            font-size: 12px;
            font-weight: 700;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
            margin-right: 10px;
            margin-top: 1px;
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
        .badge-approved {
            display: inline-block;
            background: #e8f5e9;
            color: #4CAF50;
            font-size: 12px;
            font-weight: 600;
            padding: 4px 12px;
            border-radius: 20px;
            border: 1px solid #c8e6c9;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
<div class="wrapper">
    <!-- Header -->
    <div class="header">
        <div class="header-icon">
            <!-- checkmark SVG -->
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                      stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
        </div>
        <h1>Pendaftaran Disetujui!</h1>
        <p>POS Offline System &mdash; Notifikasi Merchant</p>
    </div>

    <!-- Body -->
    <div class="body">
        <span class="badge-approved">✓ Status: Disetujui</span>

        <p class="greeting">Halo, <strong>{{ $merchant->owner?->name ?? $merchant->name }}</strong>!</p>
        <p class="message">
            Selamat! Pendaftaran merchant <strong>{{ $merchant->name }}</strong> Anda telah
            <strong>disetujui</strong> oleh tim kami. Anda kini dapat mulai menggunakan
            aplikasi POS Offline dengan kode perusahaan di bawah ini.
        </p>

        <!-- Company Code -->
        <div class="code-box">
            <p class="code-label">Kode Perusahaan Anda</p>
            <p class="code-value">{{ $companyCode }}</p>
            <p class="code-hint">Simpan kode ini dengan aman. Digunakan untuk login ke aplikasi.</p>
        </div>

        <!-- Info Merchant -->
        <div class="info-box">
            <h3>Informasi Akun</h3>
            <div class="info-row">
                <span class="label">Nama Usaha</span>
                <span>: {{ $merchant->name }}</span>
            </div>
            <div class="info-row">
                <span class="label">Email Login</span>
                <span>: {{ $merchant->owner?->email ?? $merchant->email }}</span>
            </div>
            <div class="info-row">
                <span class="label">Kode Perusahaan</span>
                <span>: <strong>{{ $companyCode }}</strong></span>
            </div>
            <div class="info-row">
                <span class="label">Tanggal Disetujui</span>
                <span>: {{ now()->setTimezone('Asia/Jakarta')->format('d M Y, H:i') }} WIB</span>
            </div>
        </div>

        <!-- Langkah login -->
        <div class="steps">
            <h3>Cara Login ke Aplikasi</h3>
            <div class="step">
                <span class="step-num">1</span>
                <span>Buka aplikasi <strong>POS Offline</strong> di perangkat Anda</span>
            </div>
            <div class="step">
                <span class="step-num">2</span>
                <span>Masukkan <strong>Kode Perusahaan</strong>: <code style="background:#f0f0f0;padding:2px 6px;border-radius:4px;font-size:13px;">{{ $companyCode }}</code></span>
            </div>
            <div class="step">
                <span class="step-num">3</span>
                <span>Masukkan <strong>Email</strong> dan <strong>Password</strong> yang sudah Anda daftarkan</span>
            </div>
            <div class="step">
                <span class="step-num">4</span>
                <span>Mulai gunakan sistem POS untuk mengelola usaha Anda</span>
            </div>
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
