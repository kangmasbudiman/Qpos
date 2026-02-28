<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{ $storeName }} - Customer Display</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            background: #0f1117;
            color: #f0f0f0;
            font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }

        /* ── Header ── */
        .header {
            background: linear-gradient(135deg, #1E2235, #2D3154);
            padding: 20px 32px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 2px solid #FF6B35;
        }
        .header-logo {
            display: flex;
            align-items: center;
            gap: 12px;
        }
        .logo-icon {
            width: 44px;
            height: 44px;
            background: #FF6B35;
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 22px;
        }
        .store-name {
            font-size: 22px;
            font-weight: 700;
            color: #fff;
            letter-spacing: 1px;
        }
        .store-sub {
            font-size: 12px;
            color: rgba(255,255,255,0.5);
        }
        .header-time {
            font-size: 28px;
            font-weight: 700;
            color: #FF6B35;
            font-variant-numeric: tabular-nums;
        }

        /* ── Main content ── */
        .main {
            flex: 1;
            display: flex;
            flex-direction: column;
            padding: 24px 32px;
            gap: 20px;
            max-width: 900px;
            margin: 0 auto;
            width: 100%;
        }

        /* ── Section title ── */
        .section-title {
            font-size: 13px;
            font-weight: 600;
            color: rgba(255,255,255,0.4);
            text-transform: uppercase;
            letter-spacing: 2px;
            margin-bottom: 10px;
        }

        /* ── Item list ── */
        .items-card {
            background: #1a1d26;
            border-radius: 16px;
            overflow: hidden;
            flex: 1;
        }
        .items-header {
            display: grid;
            grid-template-columns: 1fr 80px 120px;
            padding: 12px 20px;
            background: rgba(255,107,53,0.1);
            border-bottom: 1px solid rgba(255,255,255,0.05);
        }
        .items-header span {
            font-size: 12px;
            font-weight: 600;
            color: rgba(255,255,255,0.4);
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        .items-header .right { text-align: right; }

        .item-row {
            display: grid;
            grid-template-columns: 1fr 80px 120px;
            padding: 14px 20px;
            border-bottom: 1px solid rgba(255,255,255,0.04);
            transition: background 0.2s;
            animation: slideIn 0.3s ease;
        }
        .item-row:last-child { border-bottom: none; }
        .item-row:hover { background: rgba(255,255,255,0.03); }

        .item-name {
            font-size: 15px;
            font-weight: 500;
            color: #f0f0f0;
        }
        .item-discount {
            font-size: 11px;
            color: #4CAF50;
            margin-top: 2px;
        }
        .item-qty {
            font-size: 15px;
            color: rgba(255,255,255,0.6);
            text-align: center;
        }
        .item-subtotal {
            font-size: 15px;
            font-weight: 600;
            color: #f0f0f0;
            text-align: right;
        }

        /* ── Empty state ── */
        .empty-state {
            flex: 1;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 60px 20px;
            color: rgba(255,255,255,0.3);
            gap: 12px;
        }
        .empty-icon {
            font-size: 64px;
            opacity: 0.3;
        }
        .empty-text {
            font-size: 18px;
            font-weight: 500;
        }
        .empty-sub {
            font-size: 13px;
            opacity: 0.6;
        }

        /* ── Total bar ── */
        .total-bar {
            background: #1a1d26;
            border-radius: 16px;
            padding: 20px 24px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border: 1px solid rgba(255,107,53,0.3);
        }
        .total-label {
            font-size: 16px;
            color: rgba(255,255,255,0.6);
        }
        .total-amount {
            font-size: 36px;
            font-weight: 800;
            color: #FF6B35;
            font-variant-numeric: tabular-nums;
        }
        .total-items-count {
            font-size: 13px;
            color: rgba(255,255,255,0.4);
            margin-top: 2px;
        }

        /* ── Footer ── */
        .footer {
            padding: 12px 32px;
            background: #0d0f18;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-top: 1px solid rgba(255,255,255,0.05);
        }
        .footer-brand {
            font-size: 12px;
            color: rgba(255,255,255,0.25);
        }
        .footer-status {
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: 12px;
            color: rgba(255,255,255,0.3);
        }
        .dot {
            width: 7px;
            height: 7px;
            border-radius: 50%;
            background: #4CAF50;
            animation: pulse 2s infinite;
        }
        .dot.idle { background: rgba(255,255,255,0.2); animation: none; }

        /* ── Animations ── */
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.3; }
        }
        @keyframes slideIn {
            from { opacity: 0; transform: translateX(-8px); }
            to { opacity: 1; transform: translateX(0); }
        }
    </style>
</head>
<body>

    <!-- Header -->
    <div class="header">
        <div class="header-logo">
            <div class="logo-icon">🛒</div>
            <div>
                <div class="store-name" id="storeName">{{ $storeName }}</div>
                <div class="store-sub">Customer Display</div>
            </div>
        </div>
        <div class="header-time" id="clock">--:--:--</div>
    </div>

    <!-- Main -->
    <div class="main">

        <!-- Items section -->
        <div>
            <div class="section-title">Daftar Belanja</div>
            <div class="items-card">
                <div class="items-header">
                    <span>Produk</span>
                    <span style="text-align:center">Qty</span>
                    <span class="right">Subtotal</span>
                </div>
                <div id="itemsContainer">
                    <!-- Diisi oleh JS -->
                    @if(count($items) > 0)
                        @foreach($items as $item)
                        <div class="item-row">
                            <div>
                                <div class="item-name">{{ $item['product_name'] ?? $item['name'] ?? '-' }}</div>
                                @if(($item['discount'] ?? 0) > 0)
                                <div class="item-discount">Diskon: -Rp {{ number_format($item['discount'], 0, ',', '.') }}</div>
                                @endif
                            </div>
                            <div class="item-qty">{{ $item['quantity'] ?? 1 }}</div>
                            <div class="item-subtotal">Rp {{ number_format($item['subtotal'] ?? 0, 0, ',', '.') }}</div>
                        </div>
                        @endforeach
                    @else
                    <div class="empty-state">
                        <div class="empty-icon">🛍️</div>
                        <div class="empty-text">Belum ada item</div>
                        <div class="empty-sub">Menunggu kasir menambahkan produk...</div>
                    </div>
                    @endif
                </div>
            </div>
        </div>

        <!-- Total -->
        <div class="total-bar">
            <div>
                <div class="total-label">Total Belanja</div>
                <div class="total-items-count" id="itemsCount">
                    {{ count($items) }} item
                </div>
            </div>
            <div class="total-amount" id="totalAmount">
                Rp {{ number_format($total, 0, ',', '.') }}
            </div>
        </div>
    </div>

    <!-- Footer -->
    <div class="footer">
        <div class="footer-brand">Powered by PAYZEN POS</div>
        <div class="footer-status">
            <div class="dot" id="statusDot"></div>
            <span id="statusText">Terhubung</span>
        </div>
    </div>

    <script>
        const BRANCH_ID = {{ $branchId }};
        const POLL_URL  = '/api/display/' + BRANCH_ID;
        const INTERVAL  = 800; // 0.8 detik

        // ── Clock ──────────────────────────────────────────────
        function updateClock() {
            const now = new Date();
            const h = String(now.getHours()).padStart(2, '0');
            const m = String(now.getMinutes()).padStart(2, '0');
            const s = String(now.getSeconds()).padStart(2, '0');
            document.getElementById('clock').textContent = h + ':' + m + ':' + s;
        }
        setInterval(updateClock, 1000);
        updateClock();

        // ── Format currency ────────────────────────────────────
        function formatRp(val) {
            const n = parseFloat(val) || 0;
            return 'Rp ' + n.toLocaleString('id-ID', { maximumFractionDigits: 0 });
        }

        // ── Render items ───────────────────────────────────────
        function renderItems(items, total) {
            const container = document.getElementById('itemsContainer');
            const totalEl   = document.getElementById('totalAmount');
            const countEl   = document.getElementById('itemsCount');

            if (!items || items.length === 0) {
                container.innerHTML = `
                    <div class="empty-state">
                        <div class="empty-icon">🛍️</div>
                        <div class="empty-text">Belum ada item</div>
                        <div class="empty-sub">Menunggu kasir menambahkan produk...</div>
                    </div>`;
                totalEl.textContent = 'Rp 0';
                countEl.textContent = '0 item';
                return;
            }

            let html = '';
            items.forEach(item => {
                const name     = item.product_name || item.name || '-';
                const qty      = item.quantity || 1;
                const subtotal = item.subtotal || 0;
                const discount = item.discount || 0;
                const discHtml = discount > 0
                    ? `<div class="item-discount">Diskon: -${formatRp(discount)}</div>`
                    : '';
                html += `
                    <div class="item-row">
                        <div>
                            <div class="item-name">${escHtml(name)}</div>
                            ${discHtml}
                        </div>
                        <div class="item-qty">${qty}</div>
                        <div class="item-subtotal">${formatRp(subtotal)}</div>
                    </div>`;
            });
            container.innerHTML = html;

            totalEl.textContent = formatRp(total);
            countEl.textContent = items.length + ' item';
        }

        function escHtml(str) {
            return String(str)
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;');
        }

        // ── Polling ────────────────────────────────────────────
        let lastUpdatedAt = null;
        let errorCount    = 0;

        async function poll() {
            try {
                const res  = await fetch(POLL_URL, { cache: 'no-store' });
                if (!res.ok) throw new Error('HTTP ' + res.status);

                const data = await res.json();
                errorCount = 0;

                // Update store name jika berubah
                if (data.store_name) {
                    document.getElementById('storeName').textContent = data.store_name;
                }

                // Hanya re-render jika data berubah
                if (data.updated_at !== lastUpdatedAt) {
                    lastUpdatedAt = data.updated_at;
                    renderItems(data.items || [], data.total || 0);
                }

                setStatus(true);
            } catch (e) {
                errorCount++;
                if (errorCount >= 3) setStatus(false);
            }
        }

        function setStatus(online) {
            const dot  = document.getElementById('statusDot');
            const text = document.getElementById('statusText');
            if (online) {
                dot.className  = 'dot';
                text.textContent = 'Terhubung';
            } else {
                dot.className  = 'dot idle';
                text.textContent = 'Menghubungkan...';
            }
        }

        // Mulai polling
        poll();
        setInterval(poll, INTERVAL);
    </script>
</body>
</html>
