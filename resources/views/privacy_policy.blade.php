<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kebijakan Privasi - PAYZEN</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f4f5f7;
            color: #333;
            line-height: 1.7;
        }
        header {
            background: linear-gradient(135deg, #1E2235, #2D3154);
            color: white;
            padding: 40px 20px;
            text-align: center;
        }
        header h1 { font-size: 28px; font-weight: 700; letter-spacing: 1px; }
        header p { margin-top: 8px; opacity: 0.8; font-size: 14px; }
        .container {
            max-width: 800px;
            margin: 40px auto;
            padding: 0 20px 60px;
        }
        .card {
            background: white;
            border-radius: 12px;
            padding: 32px;
            margin-bottom: 24px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.06);
        }
        h2 {
            font-size: 18px;
            color: #1E2235;
            margin-bottom: 12px;
            padding-bottom: 8px;
            border-bottom: 2px solid #FF6B35;
            display: inline-block;
        }
        p { margin-bottom: 10px; font-size: 15px; color: #555; }
        ul { padding-left: 20px; margin-bottom: 10px; }
        ul li { margin-bottom: 6px; font-size: 15px; color: #555; }
        .badge {
            display: inline-block;
            background: #FF6B35;
            color: white;
            font-size: 12px;
            padding: 2px 10px;
            border-radius: 20px;
            margin-left: 8px;
            vertical-align: middle;
        }
        .contact-box {
            background: #1E2235;
            color: white;
            border-radius: 10px;
            padding: 20px 24px;
            margin-top: 10px;
        }
        .contact-box a { color: #FF6B35; text-decoration: none; }
        footer {
            text-align: center;
            font-size: 13px;
            color: #999;
            margin-top: 20px;
        }
    </style>
</head>
<body>

<header>
    <h1>PAYZEN</h1>
    <p>Point of Sale — Kebijakan Privasi</p>
</header>

<div class="container">

    <div class="card">
        <h2>Terakhir Diperbarui</h2>
        <p>Kebijakan privasi ini berlaku sejak <strong>{{ date('d F Y') }}</strong> dan dapat diperbarui sewaktu-waktu. Perubahan akan diberitahukan melalui pembaruan aplikasi.</p>
    </div>

    <div class="card">
        <h2>Tentang Aplikasi</h2>
        <p><strong>PAYZEN</strong> adalah aplikasi Point of Sale (POS) offline yang dirancang untuk membantu pemilik usaha dalam mengelola transaksi penjualan, inventaris produk, laporan keuangan, dan manajemen pelanggan.</p>
        <p>Aplikasi ini dapat digunakan secara <em>offline</em> dan <em>online</em>, dengan sinkronisasi data ke server ketika koneksi internet tersedia.</p>
    </div>

    <div class="card">
        <h2>Data yang Kami Kumpulkan</h2>
        <p>Kami mengumpulkan data berikut untuk menjalankan layanan aplikasi:</p>
        <ul>
            <li><strong>Data Akun:</strong> Nama, email, dan password (terenkripsi) untuk login.</li>
            <li><strong>Data Bisnis:</strong> Nama toko, cabang, produk, harga, dan kategori yang Anda input.</li>
            <li><strong>Data Transaksi:</strong> Riwayat penjualan, pembayaran, diskon, dan metode pembayaran.</li>
            <li><strong>Data Pelanggan:</strong> Nama dan nomor telepon pelanggan untuk program loyalitas (jika diaktifkan).</li>
            <li><strong>Data Perangkat:</strong> Informasi teknis perangkat untuk keperluan debugging dan keamanan.</li>
        </ul>
    </div>

    <div class="card">
        <h2>Izin Aplikasi <span class="badge">Android</span></h2>
        <p>Aplikasi meminta izin berikut:</p>
        <ul>
            <li><strong>INTERNET</strong> — Sinkronisasi data ke server dan update produk.</li>
            <li><strong>CAMERA</strong> — Memindai barcode produk dan foto produk.</li>
            <li><strong>READ_EXTERNAL_STORAGE / READ_MEDIA_IMAGES</strong> — Memilih foto produk dari galeri.</li>
            <li><strong>BLUETOOTH / BLUETOOTH_CONNECT</strong> — Koneksi ke printer thermal Bluetooth.</li>
            <li><strong>ACCESS_NETWORK_STATE</strong> — Mendeteksi status koneksi internet.</li>
        </ul>
        <p>Semua izin hanya digunakan untuk fungsi yang disebutkan di atas dan <strong>tidak dibagikan ke pihak ketiga</strong>.</p>
    </div>

    <div class="card">
        <h2>Bagaimana Kami Menggunakan Data</h2>
        <ul>
            <li>Menyediakan fitur POS (transaksi, laporan, inventaris).</li>
            <li>Menyimpan riwayat transaksi untuk keperluan laporan bisnis Anda.</li>
            <li>Mengelola program loyalitas pelanggan.</li>
            <li>Meningkatkan performa dan keandalan aplikasi.</li>
            <li>Mengirimkan notifikasi penting terkait layanan (jika diaktifkan).</li>
        </ul>
        <p>Kami <strong>tidak menjual</strong> data Anda kepada pihak ketiga manapun.</p>
    </div>

    <div class="card">
        <h2>Penyimpanan & Keamanan Data</h2>
        <ul>
            <li>Data lokal disimpan di perangkat menggunakan <strong>SQLite</strong> yang terenkripsi.</li>
            <li>Data sensitif (password, token) disimpan menggunakan <strong>Secure Storage</strong>.</li>
            <li>Data yang disinkronisasi ke server dilindungi dengan <strong>HTTPS</strong> dan autentikasi token.</li>
            <li>Server menggunakan proteksi standar industri untuk mencegah akses tidak sah.</li>
        </ul>
    </div>

    <div class="card">
        <h2>Retensi Data</h2>
        <p>Data Anda disimpan selama akun aktif. Jika Anda menghapus akun atau berhenti berlangganan, data akan dihapus dari server dalam <strong>30 hari</strong> setelah permintaan penghapusan diterima.</p>
        <p>Data lokal di perangkat akan terhapus saat aplikasi di-uninstall.</p>
    </div>

    <div class="card">
        <h2>Hak Pengguna</h2>
        <p>Anda berhak untuk:</p>
        <ul>
            <li>Mengakses data pribadi Anda yang tersimpan.</li>
            <li>Meminta koreksi data yang tidak akurat.</li>
            <li>Meminta penghapusan data (right to be forgotten).</li>
            <li>Mengekspor data transaksi Anda dalam format laporan.</li>
        </ul>
        <p>Untuk menggunakan hak-hak ini, hubungi kami melalui informasi kontak di bawah.</p>
    </div>

    <div class="card">
        <h2>Layanan Pihak Ketiga</h2>
        <p>Aplikasi ini tidak mengintegrasikan layanan analitik pihak ketiga (seperti Google Analytics atau Firebase). Data Anda hanya diproses oleh server PAYZEN.</p>
    </div>

    <div class="card">
        <h2>Hubungi Kami</h2>
        <div class="contact-box">
            <p>Jika ada pertanyaan mengenai kebijakan privasi ini, silakan hubungi:</p>
            <br>
            <p><strong>PAYZEN Support</strong></p>
            <p>Email: <a href="mailto:support@payzen.id">support@payzen.id</a></p>
            <p>Atau melalui fitur <strong>Bantuan</strong> di dalam aplikasi.</p>
        </div>
    </div>

    <footer>
        &copy; {{ date('Y') }} PAYZEN. Semua hak dilindungi.
    </footer>

</div>

</body>
</html>
