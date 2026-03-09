<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dokumentasi — Payzen POS</title>
    <meta name="description" content="Panduan lengkap penggunaan Payzen POS untuk kasir, pemilik bisnis, dan admin.">
    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        :root {
            --primary: #FF6B35;
            --primary-dark: #e55a24;
            --dark: #1A1D26;
            --dark2: #2D3154;
            --bg: #F4F5F7;
            --bg2: #ECEEF2;
            --text: #3d4152;
            --text-light: #6b7280;
            --border: #e2e4ea;
            --sidebar-w: 280px;
            --nav-h: 64px;
        }

        html { scroll-behavior: smooth; }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            color: var(--text);
            background: var(--bg);
            line-height: 1.6;
        }

        /* ── NAVBAR ── */
        nav {
            position: fixed;
            top: 0; left: 0; right: 0;
            height: var(--nav-h);
            background: var(--dark);
            z-index: 100;
            display: flex;
            align-items: center;
            padding: 0 24px;
            border-bottom: 1px solid rgba(255,255,255,0.08);
        }

        .nav-inner {
            width: 100%;
            display: flex;
            align-items: center;
            gap: 24px;
        }

        .nav-logo {
            display: flex;
            align-items: center;
            gap: 10px;
            text-decoration: none;
            color: #fff;
            font-size: 1.15rem;
            font-weight: 700;
            flex-shrink: 0;
        }

        .logo-icon {
            width: 32px; height: 32px;
            background: var(--primary);
            border-radius: 8px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 800;
            font-size: .9rem;
        }

        .nav-back {
            color: rgba(255,255,255,0.6);
            text-decoration: none;
            font-size: .875rem;
            display: flex;
            align-items: center;
            gap: 6px;
            transition: color .2s;
        }

        .nav-back:hover { color: #fff; }

        .nav-divider {
            width: 1px; height: 20px;
            background: rgba(255,255,255,0.15);
            flex-shrink: 0;
        }

        .nav-title {
            color: rgba(255,255,255,0.8);
            font-size: .875rem;
            font-weight: 500;
        }

        .nav-search {
            margin-left: auto;
            position: relative;
        }

        .nav-search input {
            background: rgba(255,255,255,0.08);
            border: 1px solid rgba(255,255,255,0.12);
            border-radius: 8px;
            padding: 7px 14px 7px 36px;
            color: #fff;
            font-size: .875rem;
            width: 220px;
            outline: none;
            transition: border-color .2s, background .2s;
        }

        .nav-search input::placeholder { color: rgba(255,255,255,0.4); }
        .nav-search input:focus {
            border-color: var(--primary);
            background: rgba(255,255,255,0.12);
        }

        .nav-search svg {
            position: absolute;
            left: 10px;
            top: 50%;
            transform: translateY(-50%);
            color: rgba(255,255,255,0.4);
            pointer-events: none;
        }

        /* ── LAYOUT ── */
        .layout {
            display: flex;
            min-height: 100vh;
            padding-top: var(--nav-h);
        }

        /* ── SIDEBAR ── */
        .sidebar {
            width: var(--sidebar-w);
            flex-shrink: 0;
            background: #fff;
            border-right: 1px solid var(--border);
            position: fixed;
            top: var(--nav-h);
            left: 0;
            bottom: 0;
            overflow-y: auto;
            padding: 24px 0 40px;
        }

        .sidebar::-webkit-scrollbar { width: 4px; }
        .sidebar::-webkit-scrollbar-thumb { background: var(--border); border-radius: 4px; }

        .sidebar-section {
            margin-bottom: 8px;
        }

        .sidebar-heading {
            font-size: .7rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: .08em;
            color: var(--text-light);
            padding: 12px 20px 4px;
        }

        .sidebar a {
            display: flex;
            align-items: center;
            gap: 10px;
            padding: 8px 20px;
            color: var(--text);
            text-decoration: none;
            font-size: .875rem;
            border-left: 3px solid transparent;
            transition: background .15s, color .15s, border-color .15s;
        }

        .sidebar a:hover {
            background: var(--bg);
            color: var(--dark);
        }

        .sidebar a.active {
            background: #fff4ef;
            color: var(--primary);
            border-left-color: var(--primary);
            font-weight: 600;
        }

        .sidebar a .icon {
            font-size: 1rem;
            width: 20px;
            text-align: center;
            flex-shrink: 0;
        }

        /* ── MAIN CONTENT ── */
        .main {
            margin-left: var(--sidebar-w);
            flex: 1;
            min-width: 0;
        }

        .content {
            max-width: 860px;
            padding: 48px 48px 80px;
        }

        /* ── SECTION ── */
        .doc-section {
            display: none;
        }

        .doc-section.visible {
            display: block;
        }

        /* Breadcrumb */
        .breadcrumb {
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: .8rem;
            color: var(--text-light);
            margin-bottom: 24px;
        }

        .breadcrumb a { color: var(--primary); text-decoration: none; }
        .breadcrumb a:hover { text-decoration: underline; }

        /* Page header */
        .page-header {
            margin-bottom: 40px;
            padding-bottom: 24px;
            border-bottom: 2px solid var(--border);
        }

        .page-badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            background: #fff4ef;
            color: var(--primary);
            font-size: .75rem;
            font-weight: 600;
            padding: 4px 12px;
            border-radius: 20px;
            margin-bottom: 12px;
            text-transform: uppercase;
            letter-spacing: .05em;
        }

        .page-header h1 {
            font-size: 2rem;
            font-weight: 800;
            color: var(--dark);
            line-height: 1.2;
            margin-bottom: 8px;
        }

        .page-header p {
            font-size: 1.05rem;
            color: var(--text-light);
        }

        /* Typography */
        .content h2 {
            font-size: 1.35rem;
            font-weight: 700;
            color: var(--dark);
            margin: 36px 0 12px;
            padding-bottom: 8px;
            border-bottom: 1px solid var(--border);
        }

        .content h3 {
            font-size: 1.05rem;
            font-weight: 700;
            color: var(--dark);
            margin: 24px 0 8px;
        }

        .content p {
            margin-bottom: 14px;
            color: var(--text);
        }

        .content ul, .content ol {
            margin: 10px 0 14px 20px;
        }

        .content li {
            margin-bottom: 6px;
        }

        /* Step cards */
        .steps {
            display: flex;
            flex-direction: column;
            gap: 16px;
            margin: 20px 0;
        }

        .step-card {
            display: flex;
            gap: 16px;
            background: #fff;
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 20px;
            transition: border-color .2s, box-shadow .2s;
        }

        .step-card:hover {
            border-color: var(--primary);
            box-shadow: 0 4px 16px rgba(255,107,53,.08);
        }

        .step-num {
            width: 36px; height: 36px;
            background: var(--primary);
            color: #fff;
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 800;
            font-size: .95rem;
            flex-shrink: 0;
        }

        .step-body h4 {
            font-size: .95rem;
            font-weight: 700;
            color: var(--dark);
            margin-bottom: 4px;
        }

        .step-body p {
            font-size: .875rem;
            color: var(--text-light);
            margin: 0;
        }

        /* Info boxes */
        .callout {
            display: flex;
            gap: 12px;
            border-radius: 10px;
            padding: 16px 18px;
            margin: 20px 0;
            font-size: .9rem;
        }

        .callout.info {
            background: #eff6ff;
            border-left: 4px solid #3b82f6;
            color: #1e40af;
        }

        .callout.tip {
            background: #f0fdf4;
            border-left: 4px solid #22c55e;
            color: #166534;
        }

        .callout.warning {
            background: #fffbeb;
            border-left: 4px solid #f59e0b;
            color: #92400e;
        }

        .callout-icon { font-size: 1.1rem; flex-shrink: 0; margin-top: 2px; }

        /* Feature grid */
        .feature-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 14px;
            margin: 20px 0;
        }

        .feature-card {
            background: #fff;
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 18px;
            text-align: center;
            transition: border-color .2s, box-shadow .2s;
            cursor: default;
        }

        .feature-card:hover {
            border-color: var(--primary);
            box-shadow: 0 4px 16px rgba(255,107,53,.08);
        }

        .feature-card .emoji { font-size: 1.8rem; margin-bottom: 8px; }
        .feature-card h4 { font-size: .875rem; font-weight: 700; color: var(--dark); margin-bottom: 4px; }
        .feature-card p { font-size: .78rem; color: var(--text-light); margin: 0; }

        /* Quick card links */
        .quick-links {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
            gap: 14px;
            margin: 24px 0;
        }

        .quick-link {
            display: flex;
            align-items: center;
            gap: 14px;
            background: #fff;
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 16px 18px;
            text-decoration: none;
            color: var(--text);
            transition: border-color .2s, box-shadow .2s, transform .15s;
        }

        .quick-link:hover {
            border-color: var(--primary);
            box-shadow: 0 4px 16px rgba(255,107,53,.1);
            transform: translateY(-1px);
        }

        .quick-link .ql-icon {
            width: 40px; height: 40px;
            border-radius: 10px;
            background: #fff4ef;
            display: flex; align-items: center; justify-content: center;
            font-size: 1.2rem;
            flex-shrink: 0;
        }

        .quick-link .ql-body h4 {
            font-size: .875rem;
            font-weight: 700;
            color: var(--dark);
            margin-bottom: 2px;
        }

        .quick-link .ql-body p {
            font-size: .78rem;
            color: var(--text-light);
            margin: 0;
        }

        /* Table */
        .doc-table {
            width: 100%;
            border-collapse: collapse;
            margin: 16px 0;
            font-size: .875rem;
            background: #fff;
            border-radius: 10px;
            overflow: hidden;
            border: 1px solid var(--border);
        }

        .doc-table th {
            background: var(--bg);
            font-weight: 700;
            color: var(--dark);
            text-align: left;
            padding: 10px 16px;
            border-bottom: 1px solid var(--border);
        }

        .doc-table td {
            padding: 10px 16px;
            border-bottom: 1px solid var(--border);
        }

        .doc-table tr:last-child td { border-bottom: none; }
        .doc-table tr:hover td { background: var(--bg); }

        /* Badge */
        .badge {
            display: inline-block;
            font-size: .7rem;
            font-weight: 700;
            padding: 2px 8px;
            border-radius: 20px;
        }
        .badge.green { background: #dcfce7; color: #166534; }
        .badge.blue  { background: #dbeafe; color: #1e40af; }
        .badge.gray  { background: #f1f5f9; color: #475569; }
        .badge.orange { background: #fff4ef; color: var(--primary); }

        /* Code block */
        .code-block {
            background: var(--dark);
            color: #e2e8f0;
            border-radius: 10px;
            padding: 16px 20px;
            font-family: 'SFMono-Regular', Consolas, monospace;
            font-size: .85rem;
            margin: 16px 0;
            overflow-x: auto;
        }

        /* ── WELCOME SECTION ── */
        .welcome-hero {
            background: linear-gradient(135deg, var(--dark) 0%, var(--dark2) 100%);
            border-radius: 16px;
            padding: 40px;
            color: #fff;
            margin-bottom: 36px;
            position: relative;
            overflow: hidden;
        }

        .welcome-hero::after {
            content: '';
            position: absolute;
            right: -20px; top: -20px;
            width: 200px; height: 200px;
            background: radial-gradient(circle, rgba(255,107,53,.25) 0%, transparent 70%);
            border-radius: 50%;
        }

        .welcome-hero h1 {
            font-size: 1.8rem;
            font-weight: 800;
            margin-bottom: 10px;
        }

        .welcome-hero p {
            color: rgba(255,255,255,.7);
            font-size: 1rem;
            max-width: 500px;
        }

        /* ── RESPONSIVE ── */
        @media (max-width: 900px) {
            :root { --sidebar-w: 0px; }
            .sidebar { display: none; }
            .main { margin-left: 0; }
            .content { padding: 32px 24px 60px; }
        }

        @media (max-width: 480px) {
            .content { padding: 24px 16px 60px; }
            .page-header h1 { font-size: 1.5rem; }
            .quick-links { grid-template-columns: 1fr; }
        }

        /* Hide scrollbar but keep functionality */
        .sidebar { scrollbar-width: thin; scrollbar-color: var(--border) transparent; }
    </style>
</head>
<body>

<!-- ── NAVBAR ── -->
<nav>
    <div class="nav-inner">
        <a href="/" class="nav-logo">
            <div class="logo-icon">P</div>
            <span>Payzen</span>
        </a>

        <div class="nav-divider"></div>
        <span class="nav-title">Dokumentasi</span>

        <a href="/" class="nav-back" style="margin-left: 16px;">
            <svg width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M15 18l-6-6 6-6"/></svg>
            Kembali ke Home
        </a>

        <div class="nav-search">
            <svg width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                <circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/>
            </svg>
            <input type="text" placeholder="Cari dokumentasi..." id="searchInput" oninput="searchDocs(this.value)">
        </div>
    </div>
</nav>

<!-- ── LAYOUT ── -->
<div class="layout">

    <!-- ── SIDEBAR ── -->
    <aside class="sidebar">

        <div class="sidebar-section">
            <div class="sidebar-heading">Mulai di Sini</div>
            <a href="#" onclick="showSection('overview')" class="active" id="nav-overview">
                <span class="icon">🏠</span> Pengenalan
            </a>
            <a href="#" onclick="showSection('quickstart')" id="nav-quickstart">
                <span class="icon">⚡</span> Mulai Cepat
            </a>
        </div>

        <div class="sidebar-section">
            <div class="sidebar-heading">Penggunaan Dasar</div>
            <a href="#" onclick="showSection('login')" id="nav-login">
                <span class="icon">🔑</span> Login & Akun
            </a>
            <a href="#" onclick="showSection('products')" id="nav-products">
                <span class="icon">📦</span> Manajemen Produk
            </a>
            <a href="#" onclick="showSection('transactions')" id="nav-transactions">
                <span class="icon">🛒</span> Transaksi Penjualan
            </a>
            <a href="#" onclick="showSection('payment')" id="nav-payment">
                <span class="icon">💳</span> Metode Pembayaran
            </a>
        </div>

        <div class="sidebar-section">
            <div class="sidebar-heading">Fitur Lanjutan</div>
            <a href="#" onclick="showSection('discount')" id="nav-discount">
                <span class="icon">🏷️</span> Diskon & Promo
            </a>
            <a href="#" onclick="showSection('hold')" id="nav-hold">
                <span class="icon">⏸️</span> Tahan Transaksi
            </a>
            <a href="#" onclick="showSection('loyalty')" id="nav-loyalty">
                <span class="icon">⭐</span> Loyalty Points
            </a>
            <a href="#" onclick="showSection('shift')" id="nav-shift">
                <span class="icon">🏪</span> Shift Kasir
            </a>
            <a href="#" onclick="showSection('barcode')" id="nav-barcode">
                <span class="icon">📱</span> Barcode Scanner
            </a>
            <a href="#" onclick="showSection('printer')" id="nav-printer">
                <span class="icon">🖨️</span> Printer Struk
            </a>
            <a href="#" onclick="showSection('display')" id="nav-display">
                <span class="icon">🖥️</span> Customer Display
            </a>
        </div>

        <div class="sidebar-section">
            <div class="sidebar-heading">Laporan & Data</div>
            <a href="#" onclick="showSection('reports')" id="nav-reports">
                <span class="icon">📊</span> Laporan Penjualan
            </a>
            <a href="#" onclick="showSection('stock')" id="nav-stock">
                <span class="icon">🗃️</span> Manajemen Stok
            </a>
        </div>

        <div class="sidebar-section">
            <div class="sidebar-heading">Bantuan</div>
            <a href="#" onclick="showSection('faq')" id="nav-faq">
                <span class="icon">❓</span> FAQ
            </a>
            <a href="mailto:support@payzen.id" target="_blank">
                <span class="icon">📧</span> Hubungi Support
            </a>
        </div>

    </aside>

    <!-- ── MAIN ── -->
    <main class="main">
        <div class="content">

            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: OVERVIEW -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section visible" id="section-overview">

                <div class="welcome-hero">
                    <h1>👋 Selamat datang di Dokumentasi Payzen</h1>
                    <p>Panduan lengkap cara menggunakan Payzen POS — dari setup awal hingga fitur lanjutan.</p>
                </div>

                <div class="page-header">
                    <div class="page-badge">📘 Pengenalan</div>
                    <h1>Apa itu Payzen POS?</h1>
                    <p>Payzen adalah aplikasi kasir modern berbasis Android yang bekerja secara offline, cocok untuk warung, kafe, toko retail, apotek, dan berbagai usaha lainnya.</p>
                </div>

                <h2>Fitur Unggulan</h2>
                <div class="feature-grid">
                    <div class="feature-card">
                        <div class="emoji">📶</div>
                        <h4>Mode Offline</h4>
                        <p>Tetap berjalan tanpa internet. Data tersinkron otomatis saat online.</p>
                    </div>
                    <div class="feature-card">
                        <div class="emoji">💳</div>
                        <h4>Multi-Payment</h4>
                        <p>Tunai, transfer, QRIS, dan kombinasi dalam 1 transaksi.</p>
                    </div>
                    <div class="feature-card">
                        <div class="emoji">⭐</div>
                        <h4>Loyalty Points</h4>
                        <p>Program poin otomatis untuk meningkatkan retensi pelanggan.</p>
                    </div>
                    <div class="feature-card">
                        <div class="emoji">🖨️</div>
                        <h4>Cetak Struk</h4>
                        <p>Bluetooth thermal printer & PDF share.</p>
                    </div>
                    <div class="feature-card">
                        <div class="emoji">📊</div>
                        <h4>Laporan Lengkap</h4>
                        <p>Laporan harian, produk terlaris, dan ekspor data.</p>
                    </div>
                    <div class="feature-card">
                        <div class="emoji">📦</div>
                        <h4>Manajemen Stok</h4>
                        <p>Notifikasi stok rendah dan histori perubahan.</p>
                    </div>
                    <div class="feature-card">
                        <div class="emoji">📱</div>
                        <h4>Barcode Scanner</h4>
                        <p>Scan produk via kamera atau scanner eksternal.</p>
                    </div>
                    <div class="feature-card">
                        <div class="emoji">🖥️</div>
                        <h4>Customer Display</h4>
                        <p>Tampilkan keranjang ke layar customer secara real-time.</p>
                    </div>
                    <div class="feature-card">
                        <div class="emoji">🏪</div>
                        <h4>Shift Kasir</h4>
                        <p>Kelola shift buka/tutup dengan rekap kas otomatis.</p>
                    </div>
                </div>

                <h2>Navigasi Dokumentasi</h2>
                <div class="quick-links">
                    <a href="#" onclick="showSection('quickstart')" class="quick-link">
                        <div class="ql-icon">⚡</div>
                        <div class="ql-body">
                            <h4>Mulai Cepat</h4>
                            <p>Setup dari nol dalam 5 menit</p>
                        </div>
                    </a>
                    <a href="#" onclick="showSection('transactions')" class="quick-link">
                        <div class="ql-icon">🛒</div>
                        <div class="ql-body">
                            <h4>Cara Bertransaksi</h4>
                            <p>Panduan buat transaksi pertama</p>
                        </div>
                    </a>
                    <a href="#" onclick="showSection('loyalty')" class="quick-link">
                        <div class="ql-icon">⭐</div>
                        <div class="ql-body">
                            <h4>Loyalty Points</h4>
                            <p>Program poin untuk pelanggan</p>
                        </div>
                    </a>
                    <a href="#" onclick="showSection('reports')" class="quick-link">
                        <div class="ql-icon">📊</div>
                        <div class="ql-body">
                            <h4>Laporan</h4>
                            <p>Pantau omzet dan penjualan</p>
                        </div>
                    </a>
                    <a href="#" onclick="showSection('printer')" class="quick-link">
                        <div class="ql-icon">🖨️</div>
                        <div class="ql-body">
                            <h4>Setup Printer</h4>
                            <p>Koneksi thermal printer Bluetooth</p>
                        </div>
                    </a>
                    <a href="#" onclick="showSection('faq')" class="quick-link">
                        <div class="ql-icon">❓</div>
                        <div class="ql-body">
                            <h4>FAQ</h4>
                            <p>Pertanyaan yang sering ditanyakan</p>
                        </div>
                    </a>
                </div>
            </div>


            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: QUICKSTART -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section" id="section-quickstart">
                <div class="breadcrumb">
                    <a href="#" onclick="showSection('overview')">Dokumentasi</a> / Mulai Cepat
                </div>
                <div class="page-header">
                    <div class="page-badge">⚡ Mulai Cepat</div>
                    <h1>Setup Payzen dalam 5 Menit</h1>
                    <p>Ikuti langkah-langkah berikut untuk mulai berjualan dengan Payzen POS.</p>
                </div>

                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Daftar Akun</h4>
                            <p>Klik tombol <strong>Coba Gratis</strong> di halaman utama. Masukkan nama bisnis, email, dan password. Akun langsung aktif tanpa perlu verifikasi kartu kredit.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Download & Install Aplikasi Android</h4>
                            <p>Install file APK Payzen di perangkat Android (minimum Android 7.0). Izinkan instalasi dari sumber tidak dikenal jika diminta.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Login ke Aplikasi</h4>
                            <p>Buka aplikasi, masukkan email dan password yang sudah didaftarkan. Aplikasi akan mengunduh data produk dan pengaturan bisnis Anda secara otomatis.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">4</div>
                        <div class="step-body">
                            <h4>Tambah Produk</h4>
                            <p>Buka menu <strong>Produk</strong> → ketuk tombol <strong>+ Tambah</strong>. Masukkan nama, harga, kategori, dan stok. Atau import sekaligus via file CSV.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">5</div>
                        <div class="step-body">
                            <h4>Buka Shift & Mulai Berjualan</h4>
                            <p>Saat login pertama, aplikasi akan meminta Anda membuka shift kasir. Masukkan modal awal kas, lalu Anda siap bertransaksi!</p>
                        </div>
                    </div>
                </div>

                <div class="callout tip">
                    <span class="callout-icon">💡</span>
                    <div><strong>Tips:</strong> Gunakan fitur import CSV untuk menambahkan banyak produk sekaligus. Unduh template CSV dari menu Produk → Import.</div>
                </div>
            </div>


            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: LOGIN -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section" id="section-login">
                <div class="breadcrumb">
                    <a href="#" onclick="showSection('overview')">Dokumentasi</a> / Login & Akun
                </div>
                <div class="page-header">
                    <div class="page-badge">🔑 Login & Akun</div>
                    <h1>Manajemen Akun</h1>
                    <p>Panduan login, pengaturan profil bisnis, dan kelola akun Payzen Anda.</p>
                </div>

                <h2>Cara Login</h2>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Buka Aplikasi Payzen</h4>
                            <p>Tampilan pertama adalah layar login. Masukkan email dan password yang terdaftar.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Sinkronisasi Data</h4>
                            <p>Setelah login berhasil, aplikasi akan menyinkronkan produk, pengaturan, dan data shift dari server. Proses ini membutuhkan koneksi internet hanya di awal.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Mode Offline</h4>
                            <p>Setelah data tersinkron, Anda bisa menggunakan aplikasi sepenuhnya tanpa internet. Transaksi disimpan di SQLite lokal dan disinkronkan saat online.</p>
                        </div>
                    </div>
                </div>

                <h2>Tier Akun & Fitur</h2>
                <table class="doc-table">
                    <thead>
                        <tr>
                            <th>Fitur</th>
                            <th>Free Trial</th>
                            <th>Starter</th>
                            <th>Business</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr><td>Kasir per cabang</td><td>1</td><td>2</td><td>Tidak terbatas</td></tr>
                        <tr><td>Jumlah produk</td><td>100</td><td>Tidak terbatas</td><td>Tidak terbatas</td></tr>
                        <tr><td>Loyalty Points</td><td>❌</td><td>✅</td><td>✅</td></tr>
                        <tr><td>Customer Display</td><td>❌</td><td>❌</td><td>✅</td></tr>
                        <tr><td>Multi-cabang</td><td>❌</td><td>❌</td><td>✅</td></tr>
                        <tr><td>Ekspor laporan</td><td>❌</td><td>✅</td><td>✅</td></tr>
                        <tr><td>API Access</td><td>❌</td><td>❌</td><td>✅</td></tr>
                    </tbody>
                </table>

                <div class="callout info">
                    <span class="callout-icon">ℹ️</span>
                    <div>Untuk upgrade akun, hubungi tim Payzen via WhatsApp atau email <strong>support@payzen.id</strong>.</div>
                </div>
            </div>


            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: PRODUCTS -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section" id="section-products">
                <div class="breadcrumb">
                    <a href="#" onclick="showSection('overview')">Dokumentasi</a> / Manajemen Produk
                </div>
                <div class="page-header">
                    <div class="page-badge">📦 Produk</div>
                    <h1>Manajemen Produk</h1>
                    <p>Cara menambah, mengedit, dan mengorganisir produk di Payzen POS.</p>
                </div>

                <h2>Tambah Produk Manual</h2>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Buka Menu Produk</h4>
                            <p>Dari sidebar utama, ketuk ikon <strong>📦 Produk</strong> atau navigasi lewat menu.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Ketuk Tombol + Tambah</h4>
                            <p>Isi form produk: nama, harga jual, kategori, stok awal, dan opsional barcode / harga modal.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Simpan Produk</h4>
                            <p>Ketuk <strong>Simpan</strong>. Produk langsung muncul di daftar POS dan bisa langsung dijual.</p>
                        </div>
                    </div>
                </div>

                <h2>Import Produk via CSV</h2>
                <p>Untuk menambah banyak produk sekaligus, gunakan fitur import CSV.</p>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Download Template CSV</h4>
                            <p>Menu Produk → ketuk <strong>Import</strong> → unduh template. Buka dengan Excel atau Google Sheets.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Isi Data Produk</h4>
                            <p>Kolom wajib: <code>name</code>, <code>price</code>. Opsional: <code>category</code>, <code>stock</code>, <code>barcode</code>, <code>cost_price</code>.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Upload File CSV</h4>
                            <p>Kembali ke aplikasi → Import → pilih file CSV → konfirmasi import.</p>
                        </div>
                    </div>
                </div>

                <h2>Notifikasi Stok Rendah</h2>
                <p>Payzen secara otomatis menampilkan notifikasi stok rendah di sidebar POS saat stok produk mencapai batas minimum yang Anda tentukan.</p>

                <div class="callout tip">
                    <span class="callout-icon">💡</span>
                    <div><strong>Tips:</strong> Atur batas stok minimum di pengaturan setiap produk agar notifikasi stok rendah muncul tepat waktu.</div>
                </div>
            </div>


            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: TRANSACTIONS -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section" id="section-transactions">
                <div class="breadcrumb">
                    <a href="#" onclick="showSection('overview')">Dokumentasi</a> / Transaksi Penjualan
                </div>
                <div class="page-header">
                    <div class="page-badge">🛒 Transaksi</div>
                    <h1>Membuat Transaksi Penjualan</h1>
                    <p>Panduan lengkap proses penjualan dari memilih produk hingga checkout.</p>
                </div>

                <h2>Alur Transaksi Dasar</h2>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Pilih Produk</h4>
                            <p>Ketuk produk dari grid di layar POS. Produk otomatis masuk ke keranjang di sisi kanan. Anda bisa mencari produk via kolom pencarian atau scan barcode.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Atur Jumlah</h4>
                            <p>Di keranjang, ketuk <strong>+</strong> / <strong>−</strong> untuk mengubah jumlah, atau ketuk angka untuk input manual.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Terapkan Diskon (Opsional)</h4>
                            <p>Ketuk ikon diskon pada item untuk memberi diskon per produk, atau terapkan diskon keseluruhan di halaman checkout.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">4</div>
                        <div class="step-body">
                            <h4>Checkout</h4>
                            <p>Ketuk tombol <strong>Bayar</strong>. Pilih metode pembayaran, masukkan nominal, konfirmasi.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">5</div>
                        <div class="step-body">
                            <h4>Cetak atau Share Struk</h4>
                            <p>Setelah transaksi berhasil, pilih cetak via Bluetooth thermal printer atau share PDF struk.</p>
                        </div>
                    </div>
                </div>

                <div class="callout info">
                    <span class="callout-icon">ℹ️</span>
                    <div>Setiap transaksi tersimpan di database lokal secara real-time. Data tidak akan hilang meskipun aplikasi ditutup paksa.</div>
                </div>
            </div>


            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: PAYMENT -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section" id="section-payment">
                <div class="breadcrumb">
                    <a href="#" onclick="showSection('overview')">Dokumentasi</a> / Metode Pembayaran
                </div>
                <div class="page-header">
                    <div class="page-badge">💳 Pembayaran</div>
                    <h1>Metode Pembayaran</h1>
                    <p>Payzen mendukung berbagai metode pembayaran termasuk split payment.</p>
                </div>

                <h2>Jenis Pembayaran yang Didukung</h2>
                <table class="doc-table">
                    <thead>
                        <tr><th>Metode</th><th>Keterangan</th><th>Kembalian Otomatis</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>💵 Tunai</td><td>Bayar dengan uang tunai</td><td>✅ Ya</td></tr>
                        <tr><td>💳 Kartu / Transfer</td><td>Debit, kredit, atau transfer bank</td><td>❌ Tidak</td></tr>
                        <tr><td>📲 QRIS / E-Wallet</td><td>GoPay, OVO, Dana, QRIS, dll</td><td>❌ Tidak</td></tr>
                        <tr><td>🔀 Split Payment</td><td>Kombinasi 2+ metode dalam 1 transaksi</td><td>✅ (untuk bagian tunai)</td></tr>
                    </tbody>
                </table>

                <h2>Split Payment (Bayar Pecah)</h2>
                <p>Fitur split payment memungkinkan pelanggan membayar dengan lebih dari satu metode dalam satu transaksi.</p>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Buka Halaman Checkout</h4>
                            <p>Setelah memilih semua produk, ketuk tombol <strong>Bayar</strong>.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Ketuk "+ Tambah Pembayaran"</h4>
                            <p>Tombol ini muncul di halaman checkout untuk menambah metode pembayaran kedua.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Isi Nominal Tiap Metode</h4>
                            <p>Masukkan jumlah untuk setiap metode. Total seluruh pembayaran harus ≥ total transaksi.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">4</div>
                        <div class="step-body">
                            <h4>Konfirmasi Pembayaran</h4>
                            <p>Ketuk <strong>Konfirmasi</strong>. Kembalian (jika ada) ditampilkan otomatis.</p>
                        </div>
                    </div>
                </div>
            </div>


            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: DISCOUNT -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section" id="section-discount">
                <div class="breadcrumb">
                    <a href="#" onclick="showSection('overview')">Dokumentasi</a> / Diskon & Promo
                </div>
                <div class="page-header">
                    <div class="page-badge">🏷️ Diskon</div>
                    <h1>Diskon & Promo</h1>
                    <p>Cara memberi diskon per item maupun diskon keseluruhan transaksi.</p>
                </div>

                <h2>Diskon Per Item</h2>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Ketuk Ikon Diskon pada Item</h4>
                            <p>Di keranjang belanja, setiap item memiliki ikon tag diskon. Ketuk untuk membuka panel diskon.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Pilih Tipe Diskon</h4>
                            <p>Toggle antara <strong>Nominal (Rp)</strong> atau <strong>Persen (%)</strong>. Gunakan tombol cepat: 5%, 10%, 15%, 20%, 25%, 50%.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Konfirmasi</h4>
                            <p>Ketuk <strong>Terapkan</strong>. Harga item di keranjang langsung ter-update dengan coret harga asli.</p>
                        </div>
                    </div>
                </div>

                <h2>Diskon Keseluruhan Transaksi</h2>
                <p>Diskon bisa juga diterapkan untuk seluruh transaksi di halaman checkout. Pilih tipe persen atau nominal, masukkan nilai, dan total akan ter-update otomatis.</p>

                <div class="callout tip">
                    <span class="callout-icon">💡</span>
                    <div><strong>Tips:</strong> Gunakan diskon persen untuk promo seperti "Diskon 10% weekend" dan nominal untuk promo khusus seperti "Potongan Rp5.000 untuk member".</div>
                </div>
            </div>


            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: HOLD -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section" id="section-hold">
                <div class="breadcrumb">
                    <a href="#" onclick="showSection('overview')">Dokumentasi</a> / Tahan Transaksi
                </div>
                <div class="page-header">
                    <div class="page-badge">⏸️ Hold</div>
                    <h1>Tahan & Lanjutkan Transaksi</h1>
                    <p>Parkir transaksi sementara untuk melayani pelanggan lain, lalu lanjutkan kembali.</p>
                </div>

                <h2>Menahan Transaksi (Hold)</h2>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Isi Keranjang</h4>
                            <p>Pilih produk-produk yang dipesan pelanggan ke dalam keranjang seperti biasa.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Ketuk Tombol Hold</h4>
                            <p>Ketuk ikon <strong>⏸ Hold</strong> di toolbar POS. Opsional: beri nama/label untuk transaksi yang ditahan (misal: "Meja 5").</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Keranjang Bersih</h4>
                            <p>Transaksi tersimpan, keranjang otomatis bersih. Anda bisa langsung melayani pelanggan berikutnya.</p>
                        </div>
                    </div>
                </div>

                <h2>Melanjutkan Transaksi (Resume)</h2>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Buka Daftar Hold</h4>
                            <p>Ketuk ikon <strong>📋 Hold List</strong> di sidebar POS. Daftar semua transaksi yang ditahan akan muncul.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Pilih & Resume</h4>
                            <p>Ketuk transaksi yang ingin dilanjutkan → <strong>Resume</strong>. Keranjang akan terisi kembali persis seperti sebelumnya.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Selesaikan Transaksi</h4>
                            <p>Lanjutkan proses checkout seperti biasa.</p>
                        </div>
                    </div>
                </div>
            </div>


            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: LOYALTY -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section" id="section-loyalty">
                <div class="breadcrumb">
                    <a href="#" onclick="showSection('overview')">Dokumentasi</a> / Loyalty Points
                </div>
                <div class="page-header">
                    <div class="page-badge">⭐ Loyalty</div>
                    <h1>Program Loyalty Points</h1>
                    <p>Tingkatkan retensi pelanggan dengan sistem poin otomatis Payzen.</p>
                </div>

                <h2>Cara Kerja Poin</h2>
                <table class="doc-table">
                    <thead>
                        <tr><th>Ketentuan</th><th>Nilai</th></tr>
                    </thead>
                    <tbody>
                        <tr><td>Akumulasi poin</td><td>1 poin per Rp 1.000 belanja</td></tr>
                        <tr><td>Nilai redeem</td><td>1 poin = Rp 100 diskon</td></tr>
                        <tr><td>Tier Bronze</td><td>0 – 999 poin</td></tr>
                        <tr><td>Tier Silver</td><td>1.000 – 4.999 poin</td></tr>
                        <tr><td>Tier Gold</td><td>≥ 5.000 poin</td></tr>
                    </tbody>
                </table>

                <h2>Daftarkan Member Baru</h2>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Buka Menu Loyalty</h4>
                            <p>Dari sidebar, ketuk <strong>⭐ Loyalty</strong> atau akses lewat menu pengaturan.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Tambah Member</h4>
                            <p>Ketuk <strong>+ Tambah Member</strong>. Isi nama dan nomor HP pelanggan.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Poin Otomatis Terakumulasi</h4>
                            <p>Di checkout, pilih member → poin dari transaksi otomatis ditambahkan setelah pembayaran berhasil.</p>
                        </div>
                    </div>
                </div>

                <h2>Cara Redeem Poin</h2>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Pilih Member di Checkout</h4>
                            <p>Di halaman checkout, ketuk bagian <strong>Member</strong> → cari dan pilih pelanggan.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Masukkan Jumlah Poin Redeem</h4>
                            <p>Input jumlah poin yang ingin digunakan. Nilai diskon akan ter-kalkulasi otomatis (poin × Rp 100).</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Konfirmasi</h4>
                            <p>Diskon poin teraplikasi ke total. Poin dikurangi otomatis setelah transaksi selesai.</p>
                        </div>
                    </div>
                </div>
            </div>


            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: SHIFT -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section" id="section-shift">
                <div class="breadcrumb">
                    <a href="#" onclick="showSection('overview')">Dokumentasi</a> / Shift Kasir
                </div>
                <div class="page-header">
                    <div class="page-badge">🏪 Shift</div>
                    <h1>Manajemen Shift Kasir</h1>
                    <p>Kelola shift kasir harian dengan rekap kas otomatis.</p>
                </div>

                <h2>Buka Shift</h2>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Prompt Otomatis Saat Login</h4>
                            <p>Jika belum ada shift aktif, aplikasi akan meminta Anda membuka shift baru saat login.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Input Modal Kas Awal</h4>
                            <p>Masukkan jumlah uang kas yang ada di laci pada awal shift. Ini digunakan untuk rekap akhir shift.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Shift Aktif</h4>
                            <p>Status shift ditampilkan di halaman Pengaturan dan dashboard. Semua transaksi otomatis terhubung ke shift ini.</p>
                        </div>
                    </div>
                </div>

                <h2>Tutup Shift</h2>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Buka Menu Pengaturan</h4>
                            <p>Dari sidebar, ketuk <strong>⚙️ Pengaturan</strong>. Temukan kartu <strong>Shift Kasir</strong>.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Ketuk "Tutup Shift"</h4>
                            <p>Review ringkasan: total penjualan, jumlah transaksi, dan selisih kas (jika ada).</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Simpan & Cetak Laporan Shift</h4>
                            <p>Shift tersimpan ke histori. Anda bisa mencetak laporan shift sebagai arsip.</p>
                        </div>
                    </div>
                </div>

                <div class="callout info">
                    <span class="callout-icon">ℹ️</span>
                    <div>Histori semua shift bisa dilihat di <strong>Pengaturan → Riwayat Shift</strong>.</div>
                </div>
            </div>


            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: BARCODE -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section" id="section-barcode">
                <div class="breadcrumb">
                    <a href="#" onclick="showSection('overview')">Dokumentasi</a> / Barcode Scanner
                </div>
                <div class="page-header">
                    <div class="page-badge">📱 Barcode</div>
                    <h1>Barcode Scanner</h1>
                    <p>Scan produk lebih cepat menggunakan kamera atau scanner eksternal.</p>
                </div>

                <h2>Metode Scan yang Didukung</h2>
                <div class="feature-grid">
                    <div class="feature-card">
                        <div class="emoji">📷</div>
                        <h4>Kamera HP</h4>
                        <p>Scan barcode menggunakan kamera belakang perangkat Android.</p>
                    </div>
                    <div class="feature-card">
                        <div class="emoji">⌨️</div>
                        <h4>Scanner Eksternal</h4>
                        <p>Barcode scanner USB/Bluetooth yang menginput via keyboard.</p>
                    </div>
                </div>

                <h2>Cara Scan via Kamera</h2>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Ketuk Ikon Kamera di POS</h4>
                            <p>Tombol scan kamera ada di toolbar layar POS, di samping kolom pencarian.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Arahkan ke Barcode</h4>
                            <p>Kamera terbuka otomatis. Arahkan ke barcode produk hingga terdeteksi.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Produk Masuk Keranjang</h4>
                            <p>Jika barcode terdaftar, produk langsung masuk keranjang. Jika tidak, akan muncul opsi tambah produk baru.</p>
                        </div>
                    </div>
                </div>

                <h2>Daftarkan Barcode ke Produk</h2>
                <p>Saat menambah atau mengedit produk, ada field <strong>Barcode</strong>. Isi dengan kode barcode produk (dapat di-scan langsung dari field input).</p>
            </div>


            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: PRINTER -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section" id="section-printer">
                <div class="breadcrumb">
                    <a href="#" onclick="showSection('overview')">Dokumentasi</a> / Printer Struk
                </div>
                <div class="page-header">
                    <div class="page-badge">🖨️ Printer</div>
                    <h1>Setup Printer Struk</h1>
                    <p>Payzen mendukung thermal printer Bluetooth dan share struk PDF.</p>
                </div>

                <h2>Printer yang Didukung</h2>
                <table class="doc-table">
                    <thead>
                        <tr><th>Tipe</th><th>Koneksi</th><th>Keterangan</th></tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td>Thermal Printer 58mm / 80mm</td>
                            <td>Bluetooth</td>
                            <td><span class="badge green">Direkomendasikan</span></td>
                        </tr>
                        <tr>
                            <td>PDF Share</td>
                            <td>—</td>
                            <td>Share via WhatsApp, email, dll</td>
                        </tr>
                    </tbody>
                </table>

                <h2>Cara Koneksi Printer Bluetooth</h2>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Aktifkan Bluetooth</h4>
                            <p>Pastikan Bluetooth di HP menyala dan printer dalam mode pairing (biasanya tahan tombol power).</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Pair Printer di Pengaturan HP</h4>
                            <p>Buka Pengaturan Android → Bluetooth → Scan → pilih printer Anda (biasanya bernama "PTP-..." atau "Bluetherm-..."). Masukkan PIN jika diminta (biasanya: 0000 atau 1234).</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Pilih Printer di Payzen</h4>
                            <p>Buka <strong>Pengaturan → Printer</strong>. Ketuk <strong>Cari Printer</strong> → pilih printer yang sudah di-pair. Ketuk <strong>Test Print</strong> untuk konfirmasi.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">4</div>
                        <div class="step-body">
                            <h4>Printer Siap</h4>
                            <p>Setelah setiap transaksi selesai, Payzen akan otomatis mencetak struk via printer yang tersimpan.</p>
                        </div>
                    </div>
                </div>

                <div class="callout warning">
                    <span class="callout-icon">⚠️</span>
                    <div>Jika printer tidak terdeteksi, pastikan printer sudah di-pair via Pengaturan Bluetooth Android terlebih dahulu sebelum membuka aplikasi Payzen.</div>
                </div>
            </div>


            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: DISPLAY -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section" id="section-display">
                <div class="breadcrumb">
                    <a href="#" onclick="showSection('overview')">Dokumentasi</a> / Customer Display
                </div>
                <div class="page-header">
                    <div class="page-badge">🖥️ Display</div>
                    <h1>Customer Display</h1>
                    <p>Tampilkan keranjang belanja real-time ke layar kedua menghadap pelanggan. Tersedia untuk paket Business.</p>
                </div>

                <div class="callout info">
                    <span class="callout-icon">ℹ️</span>
                    <div>Fitur Customer Display memerlukan paket <span class="badge orange">Business</span> dan koneksi internet di perangkat kasir.</div>
                </div>

                <h2>Cara Setup Customer Display</h2>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Siapkan Layar Kedua</h4>
                            <p>Gunakan tablet, monitor, atau layar apapun yang terhubung ke browser. Bisa juga menggunakan HP kedua.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Buka URL Display di Browser</h4>
                            <p>Di layar kedua, buka browser dan akses URL display cabang Anda. URL tersedia di aplikasi Payzen: <strong>Pengaturan → Customer Display → Lihat QR</strong>.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Display Otomatis Aktif</h4>
                            <p>Layar display akan menampilkan keranjang pelanggan secara real-time setiap kali kasir menambah produk. Refresh otomatis setiap 2 detik.</p>
                        </div>
                    </div>
                </div>

                <h2>Scan QR dari Aplikasi</h2>
                <p>Cara tercepat: Di aplikasi Payzen, ketuk ikon QR di sidebar POS → Tampilkan QR ke layar kedua → Scan → URL langsung terbuka di browser.</p>
            </div>


            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: REPORTS -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section" id="section-reports">
                <div class="breadcrumb">
                    <a href="#" onclick="showSection('overview')">Dokumentasi</a> / Laporan
                </div>
                <div class="page-header">
                    <div class="page-badge">📊 Laporan</div>
                    <h1>Laporan Penjualan</h1>
                    <p>Pantau performa bisnis Anda melalui laporan lengkap Payzen.</p>
                </div>

                <h2>Jenis Laporan</h2>
                <div class="feature-grid">
                    <div class="feature-card">
                        <div class="emoji">📅</div>
                        <h4>Laporan Harian</h4>
                        <p>Omzet, jumlah transaksi, dan rata-rata per transaksi hari ini.</p>
                    </div>
                    <div class="feature-card">
                        <div class="emoji">📦</div>
                        <h4>Produk Terlaris</h4>
                        <p>Peringkat produk berdasarkan jumlah terjual dan omzet.</p>
                    </div>
                    <div class="feature-card">
                        <div class="emoji">🗓️</div>
                        <h4>Riwayat Transaksi</h4>
                        <p>Detail semua transaksi lengkap dengan filter tanggal dan metode bayar.</p>
                    </div>
                    <div class="feature-card">
                        <div class="emoji">🏪</div>
                        <h4>Laporan Shift</h4>
                        <p>Rekap per shift: kas awal, kas akhir, total penjualan.</p>
                    </div>
                </div>

                <h2>Cara Akses Laporan</h2>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Buka Menu Riwayat / Laporan</h4>
                            <p>Dari sidebar, ketuk <strong>📊 Laporan</strong> atau <strong>📋 Riwayat</strong>.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Filter Periode</h4>
                            <p>Pilih rentang tanggal menggunakan date picker. Tersedia shortcut: Hari ini, 7 Hari, 30 Hari, Bulan ini.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Export (Paket Starter & Business)</h4>
                            <p>Ketuk tombol <strong>Export</strong> untuk mengunduh laporan dalam format CSV/Excel. Bisa langsung dikirim via WhatsApp atau email.</p>
                        </div>
                    </div>
                </div>
            </div>


            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: STOCK -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section" id="section-stock">
                <div class="breadcrumb">
                    <a href="#" onclick="showSection('overview')">Dokumentasi</a> / Manajemen Stok
                </div>
                <div class="page-header">
                    <div class="page-badge">🗃️ Stok</div>
                    <h1>Manajemen Stok</h1>
                    <p>Pantau dan kelola stok produk Anda secara akurat.</p>
                </div>

                <h2>Pengurangan Stok Otomatis</h2>
                <p>Setiap transaksi penjualan yang berhasil akan otomatis mengurangi stok produk yang terjual. Tidak perlu input manual.</p>

                <h2>Penyesuaian Stok Manual</h2>
                <div class="steps">
                    <div class="step-card">
                        <div class="step-num">1</div>
                        <div class="step-body">
                            <h4>Buka Detail Produk</h4>
                            <p>Menu Produk → ketuk produk → pilih <strong>Edit</strong>.</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">2</div>
                        <div class="step-body">
                            <h4>Ubah Stok</h4>
                            <p>Edit field <strong>Stok</strong>. Catat alasan penyesuaian di field keterangan (opsional).</p>
                        </div>
                    </div>
                    <div class="step-card">
                        <div class="step-num">3</div>
                        <div class="step-body">
                            <h4>Simpan</h4>
                            <p>Perubahan tersimpan dan langsung berlaku di POS.</p>
                        </div>
                    </div>
                </div>

                <h2>Notifikasi Stok Rendah</h2>
                <p>Saat stok produk mencapai atau di bawah batas minimum, badge merah muncul di ikon sidebar POS. Ketuk badge untuk melihat daftar produk yang perlu direstok.</p>

                <div class="callout tip">
                    <span class="callout-icon">💡</span>
                    <div><strong>Tips:</strong> Atur batas stok minimum berbeda untuk setiap produk sesuai frekuensi penjualan. Produk fast-moving sebaiknya memiliki batas lebih tinggi.</div>
                </div>
            </div>


            <!-- ══════════════════════════════════════ -->
            <!-- SECTION: FAQ -->
            <!-- ══════════════════════════════════════ -->
            <div class="doc-section" id="section-faq">
                <div class="breadcrumb">
                    <a href="#" onclick="showSection('overview')">Dokumentasi</a> / FAQ
                </div>
                <div class="page-header">
                    <div class="page-badge">❓ FAQ</div>
                    <h1>Pertanyaan yang Sering Diajukan</h1>
                    <p>Jawaban cepat untuk pertanyaan umum seputar Payzen POS.</p>
                </div>

                <div class="faq-list">

                    <h2>Umum</h2>

                    <h3>Apakah Payzen bisa digunakan tanpa internet?</h3>
                    <p>Ya! Payzen dirancang untuk bekerja penuh secara offline. Data transaksi disimpan di perangkat Android dan akan disinkronkan ke server secara otomatis saat koneksi internet tersedia.</p>

                    <h3>Di mana data transaksi disimpan?</h3>
                    <p>Data disimpan di dua tempat: database SQLite lokal di perangkat (untuk operasi offline) dan server cloud Payzen (sinkronisasi otomatis saat online).</p>

                    <h3>Berapa banyak kasir yang bisa menggunakan 1 akun?</h3>
                    <p>Tergantung paket: Free Trial (1 kasir), Starter (2 kasir/cabang), Business (tidak terbatas).</p>

                    <h2>Teknis</h2>

                    <h3>Aplikasi tidak bisa login, apa yang harus dilakukan?</h3>
                    <p>Pastikan email dan password benar. Cek koneksi internet saat pertama kali login. Jika masalah berlanjut, coba hapus cache aplikasi atau hubungi support.</p>

                    <h3>Printer Bluetooth tidak terdeteksi?</h3>
                    <p>Pastikan: (1) Printer sudah di-pair via Pengaturan Bluetooth Android, bukan hanya dari aplikasi. (2) Printer dalam kondisi menyala dan tidak terhubung ke perangkat lain. (3) Izin Bluetooth sudah diberikan ke aplikasi Payzen di Pengaturan Aplikasi Android.</p>

                    <h3>Bagaimana cara backup data?</h3>
                    <p>Data tersinkronisasi otomatis ke server Payzen selama ada koneksi internet. Untuk backup manual, gunakan fitur export laporan ke CSV dari menu Laporan.</p>

                    <h3>Apakah bisa menggunakan Payzen di iOS/iPhone?</h3>
                    <p>Saat ini Payzen hanya tersedia untuk Android. Versi iOS sedang dalam pengembangan.</p>

                    <h2>Billing & Langganan</h2>

                    <h3>Apa yang terjadi setelah masa free trial habis?</h3>
                    <p>Setelah trial berakhir, akun akan terbatas hanya untuk melihat data. Transaksi baru tidak bisa dibuat. Upgrade ke paket Starter atau Business untuk melanjutkan penggunaan.</p>

                    <h3>Bagaimana cara upgrade paket?</h3>
                    <p>Hubungi tim Payzen via WhatsApp di nomor yang tertera di halaman Harga, atau email ke <strong>support@payzen.id</strong>. Tim kami akan membantu proses upgrade.</p>

                </div>

                <div class="callout info" style="margin-top: 32px;">
                    <span class="callout-icon">📧</span>
                    <div>Tidak menemukan jawaban yang dicari? Hubungi kami di <strong>support@payzen.id</strong> atau via WhatsApp. Tim support tersedia Senin–Sabtu, 08.00–17.00 WIB.</div>
                </div>
            </div>

        </div><!-- /content -->
    </main>
</div><!-- /layout -->

<script>
    // Active section state
    let currentSection = 'overview';

    function showSection(id) {
        // Hide current
        const prev = document.getElementById('section-' + currentSection);
        if (prev) prev.classList.remove('visible');

        // Deactivate nav
        const prevNav = document.getElementById('nav-' + currentSection);
        if (prevNav) prevNav.classList.remove('active');

        // Show new
        const next = document.getElementById('section-' + id);
        if (next) next.classList.add('visible');

        // Activate nav
        const nextNav = document.getElementById('nav-' + id);
        if (nextNav) nextNav.classList.add('active');

        currentSection = id;

        // Scroll to top of content
        window.scrollTo({ top: 0, behavior: 'smooth' });

        return false;
    }

    // Search functionality
    function searchDocs(query) {
        if (!query || query.length < 2) return;
        query = query.toLowerCase();

        const sectionMap = {
            'login': ['login', 'akun', 'masuk', 'password', 'daftar'],
            'products': ['produk', 'barang', 'csv', 'import', 'stok', 'harga'],
            'transactions': ['transaksi', 'jual', 'checkout', 'beli', 'keranjang'],
            'payment': ['bayar', 'tunai', 'qris', 'transfer', 'kartu', 'split', 'kembalian'],
            'discount': ['diskon', 'promo', 'potongan', 'persen'],
            'hold': ['hold', 'tahan', 'parkir', 'resume', 'lanjut'],
            'loyalty': ['poin', 'loyalty', 'member', 'redeem', 'tier'],
            'shift': ['shift', 'kasir', 'buka', 'tutup', 'kas'],
            'barcode': ['barcode', 'scan', 'kamera'],
            'printer': ['printer', 'struk', 'cetak', 'bluetooth', 'thermal'],
            'display': ['display', 'customer', 'layar', 'qr'],
            'reports': ['laporan', 'report', 'omzet', 'export', 'riwayat'],
            'stock': ['stok', 'inventory', 'persediaan'],
            'faq': ['faq', 'pertanyaan', 'bantuan']
        };

        for (const [section, keywords] of Object.entries(sectionMap)) {
            if (keywords.some(k => k.includes(query) || query.includes(k))) {
                showSection(section);
                return;
            }
        }
    }

    // Handle browser back/forward
    window.addEventListener('popstate', function (e) {
        if (e.state && e.state.section) {
            showSection(e.state.section);
        }
    });

    // Check URL hash on load
    const hash = window.location.hash.replace('#', '');
    if (hash && document.getElementById('section-' + hash)) {
        showSection(hash);
    }

    // Active section from server
    @if(isset($activeSection) && $activeSection)
        showSection('{{ $activeSection }}');
    @endif
</script>

</body>
</html>
