<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Password Baru - {{ $storeName }}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            background: #f4f5f7;
            color: #333;
        }
        .wrapper {
            max-width: 520px;
            margin: 40px auto;
            background: #fff;
            border-radius: 16px;
            overflow: hidden;
            box-shadow: 0 4px 24px rgba(0,0,0,0.08);
        }
        .header {
            background: linear-gradient(135deg, #FF6B35, #FF8C42);
            padding: 32px 24px;
            text-align: center;
        }
        .header .icon {
            width: 64px;
            height: 64px;
            background: rgba(255,255,255,0.2);
            border-radius: 50%;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 12px;
            font-size: 28px;
        }
        .header h1 {
            color: #fff;
            font-size: 20px;
            font-weight: 700;
        }
        .header p {
            color: rgba(255,255,255,0.85);
            font-size: 13px;
            margin-top: 4px;
        }
        .body {
            padding: 32px 28px;
        }
        .greeting {
            font-size: 15px;
            color: #444;
            margin-bottom: 16px;
        }
        .info-text {
            font-size: 14px;
            color: #666;
            line-height: 1.6;
            margin-bottom: 24px;
        }
        .password-box {
            background: #fff8f5;
            border: 2px dashed #FF6B35;
            border-radius: 12px;
            padding: 20px;
            text-align: center;
            margin-bottom: 24px;
        }
        .password-label {
            font-size: 12px;
            color: #999;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 8px;
        }
        .password-value {
            font-size: 28px;
            font-weight: 800;
            color: #FF6B35;
            letter-spacing: 4px;
            font-family: 'Courier New', monospace;
        }
        .note-box {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            border-radius: 0 8px 8px 0;
            padding: 14px 16px;
            margin-bottom: 24px;
        }
        .note-box p {
            font-size: 13px;
            color: #856404;
            line-height: 1.5;
        }
        .account-info {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 16px;
            margin-bottom: 24px;
        }
        .account-info p {
            font-size: 13px;
            color: #666;
            margin-bottom: 4px;
        }
        .account-info span {
            font-weight: 600;
            color: #333;
        }
        .footer {
            background: #1a1d26;
            padding: 20px 24px;
            text-align: center;
        }
        .footer p {
            font-size: 12px;
            color: rgba(255,255,255,0.4);
            line-height: 1.6;
        }
        .footer .brand {
            color: #FF6B35;
            font-weight: 700;
            font-size: 14px;
            margin-bottom: 6px;
        }
    </style>
</head>
<body>
<div class="wrapper">
    <!-- Header -->
    <div class="header">
        <div class="icon">🔑</div>
        <h1>Password Baru Anda</h1>
        <p>{{ $storeName }} · PAYZEN POS</p>
    </div>

    <!-- Body -->
    <div class="body">
        <p class="greeting">Halo, <strong>{{ $name }}</strong>!</p>
        <p class="info-text">
            Kami menerima permintaan reset password untuk akun Anda.
            Berikut adalah password baru yang dapat Anda gunakan untuk masuk ke aplikasi PAYZEN POS:
        </p>

        <!-- Password Box -->
        <div class="password-box">
            <div class="password-label">Password Baru</div>
            <div class="password-value">{{ $newPassword }}</div>
        </div>

        <!-- Account Info -->
        <div class="account-info">
            <p>Email: <span>{{ $email }}</span></p>
            <p>Perusahaan: <span>{{ $storeName }}</span></p>
        </div>

        <!-- Warning -->
        <div class="note-box">
            <p>⚠️ <strong>Penting:</strong> Segera ganti password ini setelah berhasil masuk. Gunakan menu <em>Pengaturan → Ubah Password</em> di aplikasi.</p>
        </div>

        <p class="info-text">
            Jika Anda tidak merasa meminta reset password, abaikan email ini.
            Password lama Anda tidak aktif lagi — gunakan password di atas untuk masuk.
        </p>
    </div>

    <!-- Footer -->
    <div class="footer">
        <p class="brand">PAYZEN POS</p>
        <p>Email ini dikirim otomatis, mohon tidak membalas.<br>
        © {{ date('Y') }} PAYZEN. All rights reserved.</p>
    </div>
</div>
</body>
</html>
