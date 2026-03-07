@php
    use App\Models\AppSetting;
    $trialDays         = AppSetting::trialDays();
    $starterMonthly    = AppSetting::priceStarterMonthly();
    $starterYearly     = AppSetting::priceStarterYearly();
    $businessMonthly   = AppSetting::priceBusinessMonthly();
    $businessYearly    = AppSetting::priceBusinessYearly();

    // Format: 99000 → "99K", 199000 → "199K", 1990000 → "1,99 Jt"
    $fmt = fn(int $n) => $n >= 1_000_000
        ? number_format($n / 1_000_000, 2, ',', '.') . ' Jt'
        : round($n / 1000) . 'K';

    $starterYearlySave   = round((($starterMonthly * 12) - $starterYearly) / $starterMonthly);
    $businessYearlySave  = round((($businessMonthly * 12) - $businessYearly) / $businessMonthly);
@endphp
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Payzen POS — Kasir Modern untuk Bisnis Anda</title>
    <meta name="description" content="Payzen POS adalah aplikasi kasir offline modern dengan fitur multi-payment, loyalty points, laporan penjualan, dan customer display. Coba gratis sekarang.">

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">

    <style>
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

        :root {
            --primary:   #FF6B35;
            --primary-d: #e85a24;
            --dark:      #1A1D26;
            --dark2:     #2D3154;
            --bg:        #F4F5F7;
            --white:     #ffffff;
            --text:      #3d4152;
            --muted:     #7c8291;
            --border:    #e4e6ed;
            --gradient:  linear-gradient(135deg, #1A1D26 0%, #2D3154 100%);
        }

        html { scroll-behavior: smooth; }

        body {
            font-family: 'Plus Jakarta Sans', sans-serif;
            background: var(--white);
            color: var(--text);
            line-height: 1.6;
            overflow-x: hidden;
        }

        /* ── UTILS ── */
        .container { max-width: 1140px; margin: 0 auto; padding: 0 24px; }
        .btn {
            display: inline-flex; align-items: center; gap: 8px;
            padding: 14px 28px; border-radius: 12px; font-weight: 700;
            font-size: 15px; text-decoration: none; border: none; cursor: pointer;
            transition: all .2s ease;
        }
        .btn-primary { background: var(--primary); color: #fff; }
        .btn-primary:hover { background: var(--primary-d); transform: translateY(-2px); box-shadow: 0 8px 24px rgba(255,107,53,.35); }
        .btn-outline { background: transparent; color: var(--white); border: 2px solid rgba(255,255,255,.3); }
        .btn-outline:hover { border-color: var(--white); background: rgba(255,255,255,.08); }
        .btn-dark { background: var(--dark); color: #fff; }
        .btn-dark:hover { background: var(--dark2); transform: translateY(-2px); box-shadow: 0 8px 24px rgba(26,29,38,.3); }

        /* ── NAVBAR ── */
        nav {
            position: fixed; top: 0; left: 0; right: 0; z-index: 100;
            padding: 18px 0;
            background: rgba(26,29,38,.95);
            backdrop-filter: blur(16px);
            border-bottom: 1px solid rgba(255,255,255,.06);
            transition: box-shadow .3s;
        }
        nav .nav-inner {
            display: flex; align-items: center; justify-content: space-between;
        }
        .nav-logo {
            display: flex; align-items: center; gap: 10px;
            text-decoration: none;
        }
        .nav-logo .logo-icon {
            width: 38px; height: 38px; border-radius: 10px;
            background: var(--primary);
            display: flex; align-items: center; justify-content: center;
            font-size: 20px; font-weight: 800; color: #fff;
        }
        .nav-logo span { font-size: 20px; font-weight: 800; color: #fff; letter-spacing: -.3px; }
        .nav-links { display: flex; align-items: center; gap: 32px; }
        .nav-links a { color: rgba(255,255,255,.7); text-decoration: none; font-size: 14px; font-weight: 500; transition: color .2s; }
        .nav-links a:hover { color: #fff; }
        .nav-cta { display: flex; align-items: center; gap: 12px; }
        .nav-cta a.login { color: rgba(255,255,255,.7); text-decoration: none; font-size: 14px; font-weight: 500; transition: color .2s; }
        .nav-cta a.login:hover { color: #fff; }
        .nav-cta .btn { padding: 10px 20px; font-size: 14px; border-radius: 8px; }

        /* ── HERO ── */
        .hero {
            min-height: 100vh;
            display: flex; align-items: center;
            padding: 120px 0 80px;
            position: relative; overflow: hidden;
            background: var(--dark);
        }
        /* Background foto */
        .hero-bg {
            position: absolute; inset: 0;
            background-image: url('https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=1920&q=80&fit=crop');
            background-size: cover;
            background-position: center;
            opacity: .18;
            z-index: 0;
        }
        /* Dark gradient overlay */
        .hero::before {
            content: '';
            position: absolute; inset: 0;
            background: linear-gradient(135deg, rgba(26,29,38,.97) 0%, rgba(45,49,84,.88) 60%, rgba(26,29,38,.75) 100%);
            z-index: 1;
            pointer-events: none;
        }
        /* Orange glow aksen */
        .hero::after {
            content: '';
            position: absolute; top: -200px; right: -100px;
            width: 600px; height: 600px;
            background: radial-gradient(circle, rgba(255,107,53,.15) 0%, transparent 70%);
            z-index: 1;
            pointer-events: none;
        }
        .hero > .container { position: relative; z-index: 2; }
        .hero-grid {
            display: grid; grid-template-columns: 1fr 1fr;
            gap: 60px; align-items: center;
        }
        .hero-badge {
            display: inline-flex; align-items: center; gap: 8px;
            background: rgba(255,107,53,.15); border: 1px solid rgba(255,107,53,.3);
            color: #FF9E7A; padding: 6px 14px; border-radius: 100px;
            font-size: 13px; font-weight: 600; margin-bottom: 24px;
        }
        .hero-badge span { width: 6px; height: 6px; background: var(--primary); border-radius: 50%; animation: pulse 1.5s infinite; }
        @keyframes pulse { 0%,100%{opacity:1;transform:scale(1)} 50%{opacity:.5;transform:scale(1.3)} }

        .hero h1 {
            font-size: 54px; font-weight: 800; line-height: 1.12;
            color: #fff; letter-spacing: -.8px; margin-bottom: 20px;
        }
        .hero h1 em { font-style: normal; color: var(--primary); }
        .hero p {
            font-size: 17px; color: rgba(255,255,255,.65); line-height: 1.7;
            margin-bottom: 36px; max-width: 460px;
        }
        .hero-actions { display: flex; gap: 14px; flex-wrap: wrap; }
        .hero-stats {
            display: flex; gap: 32px; margin-top: 48px;
            padding-top: 36px; border-top: 1px solid rgba(255,255,255,.1);
        }
        .hero-stat .num { font-size: 26px; font-weight: 800; color: #fff; }
        .hero-stat .lbl { font-size: 13px; color: rgba(255,255,255,.5); margin-top: 2px; }

        /* ── HERO VISUAL: Tablet Dashboard Mockup ── */
        @keyframes float { 0%,100%{transform:translateY(0)} 50%{transform:translateY(-14px)} }
        @keyframes floatSm { 0%,100%{transform:translateY(0)} 50%{transform:translateY(-8px)} }

        .hero-visual { position: relative; display: flex; justify-content: center; align-items: center; }

        /* Glow behind tablet */
        .hero-visual::before {
            content: '';
            position: absolute; width: 340px; height: 340px;
            background: radial-gradient(circle, rgba(255,107,53,.25) 0%, transparent 70%);
            top: 50%; left: 50%; transform: translate(-50%,-50%);
            pointer-events: none;
        }

        /* Tablet frame */
        .tablet-wrap {
            position: relative;
            animation: float 5s ease-in-out infinite;
        }
        .tablet-frame {
            width: 460px;
            background: #1e2030;
            border-radius: 20px;
            padding: 10px;
            box-shadow: 0 50px 100px rgba(0,0,0,.6), 0 0 0 1px rgba(255,255,255,.08);
        }
        .tablet-screen {
            background: #f4f5f7;
            border-radius: 12px;
            overflow: hidden;
            min-height: 300px;
        }

        /* Sidebar */
        .ts-layout { display: flex; height: 300px; }
        .ts-sidebar {
            width: 52px; background: var(--gradient); display: flex;
            flex-direction: column; align-items: center; padding: 12px 0; gap: 14px;
        }
        .ts-sidebar .si-logo {
            width: 30px; height: 30px; background: var(--primary); border-radius: 8px;
            display: flex; align-items: center; justify-content: center;
            font-size: 13px; font-weight: 800; color: #fff; margin-bottom: 4px;
        }
        .ts-sidebar .si-icon {
            width: 32px; height: 32px; border-radius: 8px;
            display: flex; align-items: center; justify-content: center;
            font-size: 15px; color: rgba(255,255,255,.45); cursor: pointer;
        }
        .ts-sidebar .si-icon.active { background: rgba(255,255,255,.12); color: #fff; }

        /* Main content */
        .ts-main { flex: 1; display: flex; overflow: hidden; }

        /* Product grid */
        .ts-products { flex: 1; padding: 10px; display: flex; flex-direction: column; gap: 8px; }
        .ts-topbar {
            display: flex; align-items: center; gap: 6px;
            background: #fff; border-radius: 8px; padding: 7px 10px;
        }
        .ts-topbar .tb-title { font-size: 11px; font-weight: 700; color: var(--dark); flex: 1; }
        .ts-topbar .tb-search {
            background: var(--bg); border-radius: 6px; padding: 4px 8px;
            font-size: 10px; color: var(--muted); display: flex; align-items: center; gap: 4px;
        }
        .prod-grid { display: grid; grid-template-columns: repeat(3,1fr); gap: 6px; }
        .prod-item {
            background: #fff; border-radius: 8px; padding: 8px 6px;
            text-align: center; cursor: pointer;
            box-shadow: 0 1px 3px rgba(0,0,0,.06);
            transition: transform .15s;
        }
        .prod-item:hover { transform: scale(1.03); }
        .prod-item.active { border: 2px solid var(--primary); }
        .prod-item .pi-emoji { font-size: 18px; margin-bottom: 3px; }
        .prod-item .pi-name { font-size: 9px; font-weight: 600; color: var(--dark); line-height: 1.3; }
        .prod-item .pi-price { font-size: 9px; color: var(--primary); font-weight: 700; margin-top: 2px; }

        /* Cart panel */
        .ts-cart { width: 140px; background: #fff; display: flex; flex-direction: column; padding: 10px; gap: 6px; }
        .cart-title { font-size: 10px; font-weight: 700; color: var(--dark); }
        .cart-items { flex: 1; display: flex; flex-direction: column; gap: 5px; overflow: hidden; }
        .cart-item { display: flex; align-items: center; gap: 5px; }
        .cart-item .ci-dot { width: 5px; height: 5px; background: var(--primary); border-radius: 50%; flex-shrink: 0; }
        .cart-item .ci-name { font-size: 9px; color: var(--text); flex: 1; line-height: 1.2; }
        .cart-item .ci-price { font-size: 9px; font-weight: 700; color: var(--dark); white-space: nowrap; }
        .cart-divider { height: 1px; background: var(--border); }
        .cart-total-row { display: flex; justify-content: space-between; align-items: center; }
        .cart-total-row .ct-label { font-size: 9px; color: var(--muted); }
        .cart-total-row .ct-value { font-size: 11px; font-weight: 800; color: var(--dark); }
        .cart-pay-btn {
            background: var(--primary); color: #fff;
            border-radius: 7px; padding: 7px;
            text-align: center; font-size: 10px; font-weight: 700;
        }

        /* Stats bar at bottom */
        .ts-statsbar {
            background: #fff; border-top: 1px solid var(--border);
            display: flex; padding: 8px 12px; gap: 0;
        }
        .ts-stat { flex: 1; text-align: center; }
        .ts-stat:not(:last-child) { border-right: 1px solid var(--border); }
        .ts-stat .s-val { font-size: 11px; font-weight: 800; color: var(--dark); }
        .ts-stat .s-lbl { font-size: 9px; color: var(--muted); margin-top: 1px; }

        /* Camera indicator */
        .tablet-camera {
            position: absolute; top: 4px; left: 50%; transform: translateX(-50%);
            width: 6px; height: 6px; background: #3a3d50; border-radius: 50%;
        }

        /* Floating cards */
        .float-card {
            position: absolute;
            background: #fff; border-radius: 14px;
            padding: 10px 14px;
            box-shadow: 0 16px 40px rgba(0,0,0,.25);
            display: flex; align-items: center; gap: 10px;
            white-space: nowrap;
        }
        .float-card .fc-icon { font-size: 20px; }
        .float-card .fc-label { font-size: 10px; color: var(--muted); }
        .float-card .fc-value { font-size: 13px; font-weight: 700; color: var(--dark); }
        .float-card-1 {
            top: -20px; left: -40px;
            animation: floatSm 4s ease-in-out infinite .5s;
        }
        .float-card-2 {
            bottom: -10px; right: -40px;
            animation: floatSm 4s ease-in-out infinite 1.2s;
        }
        .float-card-3 {
            top: 50%; right: -50px; transform: translateY(-50%);
            animation: floatSm 4s ease-in-out infinite 2s;
        }

        /* ── SECTION COMMON ── */
        section { padding: 96px 0; }
        .section-tag {
            display: inline-block;
            color: var(--primary); font-size: 12px; font-weight: 700;
            text-transform: uppercase; letter-spacing: 1.2px; margin-bottom: 12px;
        }
        .section-title {
            font-size: 40px; font-weight: 800; color: var(--dark);
            line-height: 1.2; letter-spacing: -.5px; margin-bottom: 16px;
        }
        .section-sub {
            font-size: 17px; color: var(--muted); max-width: 560px; line-height: 1.7;
        }
        .section-header { text-align: center; margin-bottom: 64px; }
        .section-header .section-sub { margin: 0 auto; }

        /* ── LOGOS ── */
        .logos-bar {
            padding: 40px 0;
            background: var(--bg);
            border-top: 1px solid var(--border); border-bottom: 1px solid var(--border);
        }
        .logos-bar p { text-align: center; font-size: 13px; color: var(--muted); font-weight: 500; margin-bottom: 24px; }
        .logos-row { display: flex; align-items: center; justify-content: center; gap: 48px; flex-wrap: wrap; }
        .logos-row .logo-name {
            font-size: 15px; font-weight: 700; color: #aab0bf;
            opacity: .7; letter-spacing: -.2px;
        }

        /* ── FEATURES ── */
        .features { background: var(--white); }
        .features-grid {
            display: grid; grid-template-columns: repeat(3,1fr); gap: 24px;
        }
        .feature-card {
            background: var(--bg); border-radius: 20px; padding: 32px;
            border: 1px solid var(--border); transition: all .3s;
            position: relative; overflow: hidden;
        }
        .feature-card::before {
            content: ''; position: absolute; top: 0; left: 0; right: 0; height: 3px;
            background: linear-gradient(90deg, var(--primary), #ff9a5c);
            opacity: 0; transition: opacity .3s;
        }
        .feature-card:hover { transform: translateY(-4px); box-shadow: 0 20px 48px rgba(0,0,0,.08); border-color: transparent; }
        .feature-card:hover::before { opacity: 1; }
        .feature-icon {
            width: 52px; height: 52px; border-radius: 14px;
            background: rgba(255,107,53,.1); display: flex; align-items: center;
            justify-content: center; font-size: 24px; margin-bottom: 20px;
        }
        .feature-card h3 { font-size: 17px; font-weight: 700; color: var(--dark); margin-bottom: 10px; }
        .feature-card p { font-size: 14px; color: var(--muted); line-height: 1.65; }

        /* ── HOW IT WORKS ── */
        .how { background: var(--bg); }
        .steps { display: flex; gap: 0; position: relative; }
        .steps::before {
            content: ''; position: absolute;
            top: 28px; left: calc(100% / 6); right: calc(100% / 6);
            height: 2px; background: linear-gradient(90deg, var(--primary), #ff9a5c);
            z-index: 0;
        }
        .step { flex: 1; text-align: center; padding: 0 16px; position: relative; z-index: 1; }
        .step-num {
            width: 56px; height: 56px; border-radius: 50%;
            background: var(--primary); color: #fff;
            font-size: 20px; font-weight: 800;
            display: flex; align-items: center; justify-content: center;
            margin: 0 auto 20px; box-shadow: 0 8px 20px rgba(255,107,53,.3);
        }
        .step h4 { font-size: 16px; font-weight: 700; color: var(--dark); margin-bottom: 8px; }
        .step p  { font-size: 14px; color: var(--muted); }

        /* ── PRICING ── */
        .pricing { background: var(--white); }
        .pricing-toggle {
            display: flex; align-items: center; justify-content: center;
            gap: 16px; margin-bottom: 48px;
        }
        .pricing-toggle span { font-size: 14px; font-weight: 600; color: var(--muted); }
        .toggle-switch {
            width: 52px; height: 28px; background: var(--primary);
            border-radius: 100px; position: relative; cursor: pointer; border: none;
            transition: background .2s;
        }
        .toggle-switch::after {
            content: ''; position: absolute;
            top: 4px; left: 4px;
            width: 20px; height: 20px; background: #fff;
            border-radius: 50%; transition: transform .2s;
        }
        .toggle-switch.yearly::after { transform: translateX(24px); }
        .badge-save {
            background: rgba(255,107,53,.12); color: var(--primary);
            font-size: 11px; font-weight: 700; padding: 3px 10px;
            border-radius: 100px; text-transform: uppercase; letter-spacing: .5px;
        }
        .pricing-cards {
            display: grid; grid-template-columns: repeat(3,1fr); gap: 24px; align-items: start;
        }
        .pricing-card {
            border: 2px solid var(--border); border-radius: 24px; padding: 36px;
            transition: all .3s; position: relative;
        }
        .pricing-card.popular {
            border-color: var(--primary);
            box-shadow: 0 16px 48px rgba(255,107,53,.15);
            transform: scale(1.03);
        }
        .popular-badge {
            position: absolute; top: -14px; left: 50%; transform: translateX(-50%);
            background: var(--primary); color: #fff;
            font-size: 12px; font-weight: 700; padding: 4px 20px; border-radius: 100px;
            white-space: nowrap;
        }
        .plan-name { font-size: 14px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; color: var(--muted); margin-bottom: 8px; }
        .plan-price { margin: 16px 0; }
        .plan-price .currency { font-size: 20px; font-weight: 700; color: var(--dark); vertical-align: top; margin-top: 6px; display: inline-block; }
        .plan-price .amount { font-size: 52px; font-weight: 800; color: var(--dark); line-height: 1; letter-spacing: -2px; }
        .plan-price .period { font-size: 14px; color: var(--muted); margin-left: 4px; }
        .plan-desc { font-size: 14px; color: var(--muted); margin-bottom: 28px; line-height: 1.6; }
        .plan-divider { height: 1px; background: var(--border); margin: 24px 0; }
        .plan-features { list-style: none; display: flex; flex-direction: column; gap: 12px; margin-bottom: 32px; }
        .plan-features li {
            display: flex; align-items: flex-start; gap: 10px;
            font-size: 14px; color: var(--text);
        }
        .plan-features li::before { content: '✓'; color: var(--primary); font-weight: 700; flex-shrink: 0; margin-top: 1px; }
        .plan-features li.dim { color: var(--muted); }
        .plan-features li.dim::before { content: '—'; color: var(--border); }
        .plan-btn { width: 100%; text-align: center; justify-content: center; border-radius: 12px; padding: 14px; }

        /* ── TESTIMONIALS ── */
        .testimonials { background: var(--bg); }
        .testi-grid { display: grid; grid-template-columns: repeat(3,1fr); gap: 20px; }
        .testi-card {
            background: #fff; border-radius: 20px; padding: 28px;
            border: 1px solid var(--border); transition: all .3s;
        }
        .testi-card:hover { transform: translateY(-4px); box-shadow: 0 16px 40px rgba(0,0,0,.07); }
        .testi-stars { color: #FFBC44; font-size: 18px; margin-bottom: 14px; letter-spacing: 2px; }
        .testi-text { font-size: 14px; color: var(--text); line-height: 1.7; margin-bottom: 20px; font-style: italic; }
        .testi-author { display: flex; align-items: center; gap: 12px; }
        .testi-avatar {
            width: 40px; height: 40px; border-radius: 50%;
            background: var(--gradient); color: #fff;
            display: flex; align-items: center; justify-content: center;
            font-size: 15px; font-weight: 700; flex-shrink: 0;
        }
        .testi-name { font-size: 14px; font-weight: 700; color: var(--dark); }
        .testi-role { font-size: 12px; color: var(--muted); margin-top: 2px; }

        /* ── CTA ── */
        .cta-section {
            background: var(--gradient);
            padding: 96px 0; text-align: center; position: relative; overflow: hidden;
        }
        .cta-section::before {
            content: '';
            position: absolute; top: -100px; left: 50%; transform: translateX(-50%);
            width: 500px; height: 500px;
            background: radial-gradient(circle, rgba(255,107,53,.2) 0%, transparent 70%);
            pointer-events: none;
        }
        .cta-section h2 { font-size: 44px; font-weight: 800; color: #fff; line-height: 1.2; margin-bottom: 16px; }
        .cta-section p { font-size: 17px; color: rgba(255,255,255,.65); max-width: 480px; margin: 0 auto 36px; }
        .cta-actions { display: flex; justify-content: center; gap: 14px; flex-wrap: wrap; }
        .cta-note { font-size: 13px; color: rgba(255,255,255,.4); margin-top: 16px; }

        /* ── FOOTER ── */
        footer {
            background: var(--dark); padding: 64px 0 32px; color: rgba(255,255,255,.6);
        }
        .footer-grid { display: grid; grid-template-columns: 2fr 1fr 1fr 1fr; gap: 48px; margin-bottom: 48px; }
        .footer-brand .nav-logo { margin-bottom: 16px; display: inline-flex; }
        .footer-brand p { font-size: 14px; line-height: 1.7; max-width: 260px; }
        .footer-col h5 { font-size: 13px; font-weight: 700; color: #fff; text-transform: uppercase; letter-spacing: .8px; margin-bottom: 16px; }
        .footer-col ul { list-style: none; display: flex; flex-direction: column; gap: 10px; }
        .footer-col a { color: rgba(255,255,255,.55); text-decoration: none; font-size: 14px; transition: color .2s; }
        .footer-col a:hover { color: #fff; }
        .footer-bottom { border-top: 1px solid rgba(255,255,255,.08); padding-top: 32px; display: flex; justify-content: space-between; align-items: center; }
        .footer-bottom p { font-size: 13px; }
        .footer-bottom-links { display: flex; gap: 24px; }
        .footer-bottom-links a { color: rgba(255,255,255,.4); text-decoration: none; font-size: 13px; transition: color .2s; }
        .footer-bottom-links a:hover { color: rgba(255,255,255,.8); }

        /* ── RESPONSIVE ── */
        @media (max-width: 1024px) {
            .hero-grid { grid-template-columns: 1fr; text-align: center; }
            .hero p { max-width: 100%; }
            .hero-actions { justify-content: center; }
            .hero-stats { justify-content: center; }
            .hero-visual { margin-top: 60px; }
            .tablet-frame { width: 360px; }
            .float-card-1 { left: -10px; top: -30px; }
            .float-card-2 { right: -10px; bottom: -20px; }
            .float-card-3 { display: none; }
            .features-grid { grid-template-columns: repeat(2,1fr); }
            .pricing-cards { grid-template-columns: 1fr; }
            .pricing-card.popular { transform: none; }
            .testi-grid { grid-template-columns: repeat(2,1fr); }
            .footer-grid { grid-template-columns: 1fr 1fr; }
            .steps { flex-direction: column; }
            .steps::before { display: none; }
            .step { display: flex; align-items: flex-start; gap: 16px; text-align: left; padding: 0; }
            .step-num { margin: 0; flex-shrink: 0; }
        }

        @media (max-width: 640px) {
            .hero h1 { font-size: 36px; }
            .tablet-frame { width: 300px; }
            .float-card-1, .float-card-2 { display: none; }
            .section-title { font-size: 28px; }
            .features-grid { grid-template-columns: 1fr; }
            .testi-grid { grid-template-columns: 1fr; }
            .footer-grid { grid-template-columns: 1fr; gap: 32px; }
            .footer-bottom { flex-direction: column; gap: 12px; text-align: center; }
            nav .nav-links { display: none; }
            .cta-section h2 { font-size: 30px; }
        }
    </style>
</head>
<body>

<!-- ── NAVBAR ── -->
<nav>
    <div class="container">
        <div class="nav-inner">
            <a href="/" class="nav-logo">
                <div class="logo-icon">P</div>
                <span>Payzen</span>
            </a>

            <div class="nav-links">
                <a href="#fitur">Fitur</a>
                <a href="#cara-kerja">Cara Kerja</a>
                <a href="#harga">Harga</a>
                <a href="#testimoni">Testimoni</a>
            </div>

            <div class="nav-cta">
                <a href="#" class="login">Masuk</a>
                <a href="#harga" class="btn btn-primary">Coba Gratis</a>
            </div>
        </div>
    </div>
</nav>

<!-- ── HERO ── -->
<section class="hero">
    <div class="hero-bg"></div>
    <div class="container">
        <div class="hero-grid">
            <div class="hero-content">
                <div class="hero-badge">
                    <span></span> Kasir POS Modern &amp; Offline
                </div>
                <h1>Kelola Bisnis Lebih <em>Cerdas</em> dan Cepat</h1>
                <p>Payzen POS hadir untuk mempermudah operasional kasir Anda. Bekerja offline, multi-cabang, laporan lengkap — semua dalam genggaman.</p>

                <div class="hero-actions">
                    <a href="#harga" class="btn btn-primary">
                        🚀 Mulai Gratis 14 Hari
                    </a>
                    <a href="#fitur" class="btn btn-outline">
                        Lihat Fitur
                    </a>
                </div>

                <div class="hero-stats">
                    <div class="hero-stat">
                        <div class="num">500+</div>
                        <div class="lbl">Merchant Aktif</div>
                    </div>
                    <div class="hero-stat">
                        <div class="num">1 Jt+</div>
                        <div class="lbl">Transaksi/Bulan</div>
                    </div>
                    <div class="hero-stat">
                        <div class="num">99.9%</div>
                        <div class="lbl">Uptime</div>
                    </div>
                </div>
            </div>

            <div class="hero-visual">

                <!-- Float card: pembayaran -->
                <div class="float-card float-card-1">
                    <div class="fc-icon">✅</div>
                    <div>
                        <div class="fc-label">Pembayaran berhasil</div>
                        <div class="fc-value">Rp 185.000</div>
                    </div>
                </div>

                <!-- Float card: loyalty -->
                <div class="float-card float-card-2">
                    <div class="fc-icon">⭐</div>
                    <div>
                        <div class="fc-label">Poin loyalty diperoleh</div>
                        <div class="fc-value">+185 pts</div>
                    </div>
                </div>

                <!-- Float card: stok -->
                <div class="float-card float-card-3">
                    <div class="fc-icon">📦</div>
                    <div>
                        <div class="fc-label">Stok hampir habis</div>
                        <div class="fc-value">Kopi Susu · 3 sisa</div>
                    </div>
                </div>

                <!-- Tablet Dashboard Mockup -->
                <div class="tablet-wrap">
                    <div class="tablet-frame">
                        <div class="tablet-camera"></div>
                        <div class="tablet-screen">
                            <div class="ts-layout">

                                <!-- Sidebar -->
                                <div class="ts-sidebar">
                                    <div class="si-logo">P</div>
                                    <div class="si-icon active">🛒</div>
                                    <div class="si-icon">📊</div>
                                    <div class="si-icon">📦</div>
                                    <div class="si-icon">👥</div>
                                    <div class="si-icon">⚙️</div>
                                </div>

                                <!-- Main area -->
                                <div class="ts-main">
                                    <!-- Product grid -->
                                    <div class="ts-products">
                                        <div class="ts-topbar">
                                            <div class="tb-title">Pilih Produk</div>
                                            <div class="tb-search">🔍 Cari...</div>
                                        </div>
                                        <div class="prod-grid">
                                            <div class="prod-item active">
                                                <div class="pi-emoji">☕</div>
                                                <div class="pi-name">Kopi Susu</div>
                                                <div class="pi-price">25.000</div>
                                            </div>
                                            <div class="prod-item">
                                                <div class="pi-emoji">🥐</div>
                                                <div class="pi-name">Croissant</div>
                                                <div class="pi-price">30.000</div>
                                            </div>
                                            <div class="prod-item">
                                                <div class="pi-emoji">🍰</div>
                                                <div class="pi-name">Cheese Cake</div>
                                                <div class="pi-price">45.000</div>
                                            </div>
                                            <div class="prod-item">
                                                <div class="pi-emoji">🥤</div>
                                                <div class="pi-name">Matcha Latte</div>
                                                <div class="pi-price">28.000</div>
                                            </div>
                                            <div class="prod-item">
                                                <div class="pi-emoji">🍩</div>
                                                <div class="pi-name">Donut</div>
                                                <div class="pi-price">15.000</div>
                                            </div>
                                            <div class="prod-item">
                                                <div class="pi-emoji">🧃</div>
                                                <div class="pi-name">Jus Alpukat</div>
                                                <div class="pi-price">22.000</div>
                                            </div>
                                        </div>
                                    </div>

                                    <!-- Cart panel -->
                                    <div class="ts-cart">
                                        <div class="cart-title">🛒 Keranjang (3)</div>
                                        <div class="cart-items">
                                            <div class="cart-item">
                                                <div class="ci-dot"></div>
                                                <div class="ci-name">Kopi Susu x2</div>
                                                <div class="ci-price">50rb</div>
                                            </div>
                                            <div class="cart-item">
                                                <div class="ci-dot"></div>
                                                <div class="ci-name">Croissant x3</div>
                                                <div class="ci-price">90rb</div>
                                            </div>
                                            <div class="cart-item">
                                                <div class="ci-dot"></div>
                                                <div class="ci-name">Cheese Cake x1</div>
                                                <div class="ci-price">45rb</div>
                                            </div>
                                        </div>
                                        <div class="cart-divider"></div>
                                        <div class="cart-total-row">
                                            <div class="ct-label">Total</div>
                                            <div class="ct-value">185rb</div>
                                        </div>
                                        <div class="cart-pay-btn">Bayar →</div>
                                    </div>
                                </div>
                            </div>

                            <!-- Stats bar -->
                            <div class="ts-statsbar">
                                <div class="ts-stat">
                                    <div class="s-val">Rp 4,2 Jt</div>
                                    <div class="s-lbl">Omzet Hari Ini</div>
                                </div>
                                <div class="ts-stat">
                                    <div class="s-val">48</div>
                                    <div class="s-lbl">Transaksi</div>
                                </div>
                                <div class="ts-stat">
                                    <div class="s-val">12</div>
                                    <div class="s-lbl">Member Baru</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</section>

<!-- ── LOGOS ── -->
<div class="logos-bar">
    <div class="container">
        <p>Dipercaya oleh berbagai jenis usaha</p>
        <div class="logos-row">
            <div class="logo-name">☕ Kafe &amp; Resto</div>
            <div class="logo-name">🛒 Retail &amp; Toko</div>
            <div class="logo-name">💊 Apotek</div>
            <div class="logo-name">👗 Fashion</div>
            <div class="logo-name">🍳 Warteg &amp; Kantin</div>
        </div>
    </div>
</div>

<!-- ── FEATURES ── -->
<section class="features" id="fitur">
    <div class="container">
        <div class="section-header">
            <div class="section-tag">Fitur Unggulan</div>
            <h2 class="section-title">Semua yang Anda Butuhkan</h2>
            <p class="section-sub">Dari kasir harian hingga laporan bulanan — Payzen POS menyediakan fitur lengkap untuk bisnis Anda berkembang.</p>
        </div>

        <div class="features-grid">
            <div class="feature-card">
                <div class="feature-icon">📶</div>
                <h3>Mode Offline</h3>
                <p>Transaksi tetap berjalan walau internet mati. Data otomatis tersinkronisasi saat koneksi pulih.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon">💳</div>
                <h3>Multi-Payment</h3>
                <p>Terima pembayaran tunai, QRIS, transfer, e-wallet, bahkan split payment dalam satu transaksi.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon">⭐</div>
                <h3>Loyalty Points</h3>
                <p>Program loyalitas built-in dengan tier Bronze, Silver, Gold. Pelanggan kumpulkan poin otomatis setiap transaksi.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon">🖨️</div>
                <h3>Cetak Struk</h3>
                <p>Dukung printer thermal Bluetooth. Struk PDF juga tersedia sebagai alternatif tanpa printer fisik.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon">📊</div>
                <h3>Laporan Lengkap</h3>
                <p>Laporan penjualan harian, mingguan, dan bulanan. Export ke PDF atau Excel kapan saja.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon">📦</div>
                <h3>Manajemen Stok</h3>
                <p>Pantau stok produk secara real-time. Notifikasi otomatis saat stok mendekati batas minimum.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon">📱</div>
                <h3>Barcode Scanner</h3>
                <p>Scan produk via kamera atau scanner eksternal. Input barang jadi super cepat dan akurat.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon">🖥️</div>
                <h3>Customer Display</h3>
                <p>Tampilkan keranjang belanja ke layar customer secara real-time melalui browser — tanpa hardware tambahan.</p>
            </div>
            <div class="feature-card">
                <div class="feature-icon">🏪</div>
                <h3>Manajemen Shift</h3>
                <p>Buka dan tutup shift kasir dengan mudah. Rekap kas otomatis setiap akhir shift.</p>
            </div>
        </div>
    </div>
</section>

<!-- ── HOW IT WORKS ── -->
<section class="how" id="cara-kerja">
    <div class="container">
        <div class="section-header">
            <div class="section-tag">Cara Kerja</div>
            <h2 class="section-title">Mulai dalam 4 Langkah</h2>
            <p class="section-sub">Setup cepat tanpa perlu keahlian teknis. Bisnis Anda bisa langsung beroperasi hari ini.</p>
        </div>

        <div class="steps">
            <div class="step">
                <div class="step-num">1</div>
                <div>
                    <h4>Daftar Akun</h4>
                    <p>Buat akun merchant gratis. Nikmati trial 14 hari tanpa kartu kredit.</p>
                </div>
            </div>
            <div class="step">
                <div class="step-num">2</div>
                <div>
                    <h4>Input Produk</h4>
                    <p>Tambahkan produk beserta harga dan stok. Bisa import massal via CSV.</p>
                </div>
            </div>
            <div class="step">
                <div class="step-num">3</div>
                <div>
                    <h4>Install Aplikasi</h4>
                    <p>Unduh aplikasi Payzen POS di perangkat Android. Login dan langsung siap digunakan.</p>
                </div>
            </div>
            <div class="step">
                <div class="step-num">4</div>
                <div>
                    <h4>Mulai Berjualan</h4>
                    <p>Kasir siap beroperasi. Transaksi, laporan, dan stok — semua terpantau otomatis.</p>
                </div>
            </div>
        </div>
    </div>
</section>

<!-- ── PRICING ── -->
<section class="pricing" id="harga">
    <div class="container">
        <div class="section-header">
            <div class="section-tag">Harga</div>
            <h2 class="section-title">Harga Terjangkau, Fitur Penuh</h2>
            <p class="section-sub">Pilih paket yang sesuai kebutuhan. Tanpa biaya tersembunyi, batalkan kapan saja.</p>
        </div>

        <div class="pricing-cards">
            <!-- Free -->
            <div class="pricing-card">
                <div class="plan-name">Free Trial</div>
                <div class="plan-price">
                    <span class="currency">Rp</span>
                    <span class="amount">0</span>
                    <span class="period">/ {{ $trialDays }} hari</span>
                </div>
                <div class="plan-desc">Akses semua fitur selama {{ $trialDays }} hari. Tidak perlu kartu kredit.</div>
                <div class="plan-divider"></div>
                <ul class="plan-features">
                    <li>Semua fitur Starter</li>
                    <li>1 kasir / cabang</li>
                    <li>100 produk</li>
                    <li>Laporan dasar</li>
                    <li class="dim">Loyalty Points</li>
                    <li class="dim">Customer Display</li>
                    <li class="dim">Multi-kasir</li>
                </ul>
                <a href="#" class="btn btn-dark plan-btn">Coba Gratis</a>
            </div>

            <!-- Starter -->
            <div class="pricing-card popular">
                <div class="popular-badge">🔥 Paling Populer</div>
                <div class="plan-name">Starter</div>
                <div class="plan-price">
                    <span class="currency">Rp</span>
                    <span class="amount">{{ $fmt($starterMonthly) }}</span>
                    <span class="period">/ bulan</span>
                </div>
                <div class="plan-desc">Cocok untuk usaha kecil menengah yang sedang berkembang.</div>
                <div class="plan-divider"></div>
                <ul class="plan-features">
                    <li>Semua fitur dasar</li>
                    <li>2 kasir / cabang</li>
                    <li>Produk tak terbatas</li>
                    <li>Laporan lengkap + export</li>
                    <li>Loyalty Points</li>
                    <li>Manajemen shift kasir</li>
                    <li class="dim">Customer Display</li>
                    <li class="dim">Multi-cabang</li>
                </ul>
                <a href="https://wa.me/6285709947075?text=Halo%2C+saya+ingin+berlangganan+paket+*Starter*+Payzen+POS.+Bagaimana+caranya%3F" target="_blank" class="btn btn-primary plan-btn">Pilih Starter</a>
            </div>

            <!-- Business -->
            <div class="pricing-card">
                <div class="plan-name">Business</div>
                <div class="plan-price">
                    <span class="currency">Rp</span>
                    <span class="amount">{{ $fmt($businessMonthly) }}</span>
                    <span class="period">/ bulan</span>
                </div>
                <div class="plan-desc">Untuk bisnis berkembang pesat dengan kebutuhan fitur penuh.</div>
                <div class="plan-divider"></div>
                <ul class="plan-features">
                    <li>Semua fitur Starter</li>
                    <li>Kasir tak terbatas</li>
                    <li>Multi-cabang</li>
                    <li>Customer Display</li>
                    <li>API akses</li>
                    <li>Prioritas support</li>
                    <li>Onboarding personal</li>
                </ul>
                <a href="https://wa.me/6285709947075?text=Halo%2C+saya+ingin+berlangganan+paket+*Business*+Payzen+POS.+Bagaimana+caranya%3F" target="_blank" class="btn btn-dark plan-btn">Pilih Business</a>
            </div>
        </div>

        <p style="text-align:center;margin-top:28px;font-size:14px;color:var(--muted);">
            Bayar tahunan dan hemat hingga <strong style="color:var(--primary)">{{ $starterYearlySave }} bulan gratis</strong> 🎉
        </p>
    </div>
</section>

<!-- ── TESTIMONIALS ── -->
<section class="testimonials" id="testimoni">
    <div class="container">
        <div class="section-header">
            <div class="section-tag">Testimoni</div>
            <h2 class="section-title">Kata Mereka yang Sudah Pakai</h2>
            <p class="section-sub">Bergabung bersama ratusan merchant yang sudah merasakan manfaatnya.</p>
        </div>

        <div class="testi-grid">
            <div class="testi-card">
                <div class="testi-stars">★★★★★</div>
                <p class="testi-text">"Sejak pakai Payzen, kasir jadi jauh lebih cepat. Pelanggan antri lebih sedikit dan omzet naik 30% dalam sebulan pertama!"</p>
                <div class="testi-author">
                    <div class="testi-avatar">A</div>
                    <div>
                        <div class="testi-name">Andi Pratama</div>
                        <div class="testi-role">Owner Kafe Senja, Jakarta</div>
                    </div>
                </div>
            </div>

            <div class="testi-card">
                <div class="testi-stars">★★★★★</div>
                <p class="testi-text">"Fitur offline-nya sangat membantu. Internet sering putus di toko saya, tapi transaksi tetap jalan tanpa hambatan."</p>
                <div class="testi-author">
                    <div class="testi-avatar">S</div>
                    <div>
                        <div class="testi-name">Sari Dewi</div>
                        <div class="testi-role">Pemilik Toko Kelontong, Bandung</div>
                    </div>
                </div>
            </div>

            <div class="testi-card">
                <div class="testi-stars">★★★★★</div>
                <p class="testi-text">"Loyalty points-nya disukai pelanggan setia kami. Program ini berhasil meningkatkan repeat order secara signifikan."</p>
                <div class="testi-author">
                    <div class="testi-avatar">B</div>
                    <div>
                        <div class="testi-name">Budi Santoso</div>
                        <div class="testi-role">Manager Restoran Bahari, Surabaya</div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</section>

<!-- ── CTA ── -->
<section class="cta-section">
    <div class="container">
        <h2>Siap Upgrade Cara Anda Berjualan?</h2>
        <p>Mulai trial gratis 14 hari sekarang. Tidak perlu kartu kredit, tidak ada kontrak jangka panjang.</p>
        <div class="cta-actions">
            <a href="#" class="btn btn-primary">🚀 Mulai Gratis Sekarang</a>
            <a href="https://wa.me/6285709947075?text=Halo%2C+saya+ingin+berlangganan+Payzen+POS.+Bagaimana+caranya%3F" target="_blank" class="btn btn-outline">Hubungi Kami</a>
        </div>
        <p class="cta-note">✓ Setup 5 menit &nbsp;·&nbsp; ✓ Tanpa kartu kredit &nbsp;·&nbsp; ✓ Batalkan kapan saja</p>
    </div>
</section>

<!-- ── FOOTER ── -->
<footer>
    <div class="container">
        <div class="footer-grid">
            <div class="footer-brand">
                <a href="/" class="nav-logo">
                    <div class="logo-icon">P</div>
                    <span>Payzen</span>
                </a>
                <p>Solusi kasir POS modern untuk bisnis Indonesia. Offline, cepat, dan lengkap.</p>
            </div>

            <div class="footer-col">
                <h5>Produk</h5>
                <ul>
                    <li><a href="#fitur">Fitur</a></li>
                    <li><a href="#harga">Harga</a></li>
                    <li><a href="#cara-kerja">Cara Kerja</a></li>
                    <li><a href="#">Download App</a></li>
                </ul>
            </div>

            <div class="footer-col">
                <h5>Perusahaan</h5>
                <ul>
                    <li><a href="#">Tentang Kami</a></li>
                    <li><a href="#">Blog</a></li>
                    <li><a href="#">Karir</a></li>
                    <li><a href="#">Press</a></li>
                </ul>
            </div>

            <div class="footer-col">
                <h5>Bantuan</h5>
                <ul>
                    <li><a href="#">Dokumentasi</a></li>
                    <li><a href="mailto:support@payzen.id">Email Support</a></li>
                    <li><a href="/privacy-policy">Kebijakan Privasi</a></li>
                    <li><a href="#">Syarat &amp; Ketentuan</a></li>
                </ul>
            </div>
        </div>

        <div class="footer-bottom">
            <p>© {{ date('Y') }} Payzen. Seluruh hak cipta dilindungi.</p>
            <div class="footer-bottom-links">
                <a href="/privacy-policy">Privasi</a>
                <a href="#">Ketentuan</a>
                <a href="mailto:support@payzen.id">Kontak</a>
            </div>
        </div>
    </div>
</footer>

</body>
</html>
