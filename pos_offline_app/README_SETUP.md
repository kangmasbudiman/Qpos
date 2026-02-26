# 🚀 POS Offline App - Setup Guide

## 📡 Konfigurasi Backend URL

### 1️⃣ **Untuk Android Emulator:**
```dart
// Di file: lib/core/constants/app_constants.dart
static const String baseUrl = 'http://10.0.2.2:8001/api';
```
**Penjelasan:** `10.0.2.2` adalah IP khusus Android emulator untuk akses localhost komputer host.

---

### 2️⃣ **Untuk Physical Device (HP Android/iOS):**

**Step 1:** Cari IP komputer Anda
```bash
# Mac/Linux
ifconfig | grep "inet "

# Windows
ipconfig
```

**Step 2:** Update URL
```dart
// Contoh jika IP komputer: 192.168.1.10
static const String baseUrl = 'http://192.168.1.10:8001/api';
```

**Step 3:** Pastikan HP dan Komputer dalam **WiFi yang sama**

---

### 3️⃣ **Untuk iOS Simulator:**
```dart
static const String baseUrl = 'http://127.0.0.1:8001/api';
// atau gunakan IP komputer
static const String baseUrl = 'http://192.168.1.10:8001/api';
```

---

### 4️⃣ **Untuk Production/Deployment:**
```dart
static const String baseUrl = 'https://api.yourapp.com/api';
```

---

## 🔧 Cara Ganti URL Secara Dinamis

### Method 1: Edit `app_constants.dart`
```dart
// File: lib/core/constants/app_constants.dart
class AppConstants {
  static const String baseUrl = 'http://10.0.2.2:8001/api'; // <-- GANTI DI SINI
}
```

### Method 2: Gunakan Environment Config (Recommended)
```dart
// File: lib/main.dart
void main() {
  // Set environment
  EnvironmentConfig.setEnvironment(Environment.development);
  
  runApp(POSApp());
}

// Akses URL
final url = EnvironmentConfig.baseUrl;
```

### Method 3: Build Variants (Advanced)
```bash
# Development
flutter run --dart-define=ENV=dev

# Production
flutter run --dart-define=ENV=prod
```

---

## ✅ Test Koneksi Backend

### 1. Pastikan Laravel Backend Running:
```bash
cd pos-backend
php artisan serve --host=0.0.0.0 --port=8001
```

### 2. Test dari Browser/Postman:
```
http://YOUR_IP:8001/api/products
```

### 3. Test dari Flutter:
- Login dengan credentials
- Check console logs untuk API calls
- Lihat response di DevTools

---

## 🐛 Troubleshooting

### Error: "Connection refused"
✅ **Solusi:**
- Pastikan backend running
- Pastikan port 8001 tidak diblock firewall
- Untuk physical device, pastikan satu WiFi dengan komputer

### Error: "Network unreachable"
✅ **Solusi:**
- Check IP address komputer
- Restart Laravel backend dengan `--host=0.0.0.0`
- Disable antivirus/firewall sementara

### Error: "SSL Handshake failed" (HTTPS)
✅ **Solusi:**
- Untuk development, gunakan HTTP (bukan HTTPS)
- Atau tambahkan certificate exception

---

## 📱 Quick Reference

| Platform | URL Format | Example |
|----------|-----------|---------|
| Android Emulator | `http://10.0.2.2:PORT/api` | `http://10.0.2.2:8001/api` |
| iOS Simulator | `http://localhost:PORT/api` | `http://localhost:8001/api` |
| Physical Device | `http://YOUR_IP:PORT/api` | `http://192.168.1.10:8001/api` |
| Production | `https://domain/api` | `https://api.yourapp.com/api` |

---

## 🔐 Security Notes

**Development:**
- ✅ HTTP OK untuk testing
- ✅ IP lokal OK

**Production:**
- ⚠️ **WAJIB** gunakan HTTPS
- ⚠️ **WAJIB** gunakan domain, bukan IP
- ⚠️ Validate SSL certificates
- ⚠️ Implement API key/token security

---

**Need help? Check logs:**
```bash
flutter logs
# atau
adb logcat | grep flutter
```
