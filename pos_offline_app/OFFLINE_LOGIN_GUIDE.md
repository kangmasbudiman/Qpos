# 🔴 Offline Login - How It Works

## 📱 Overview
Aplikasi POS ini mendukung **offline login** setelah Anda login online minimal 1 kali.

---

## ✅ Cara Kerja Offline Login

### **1. First Time Login (Online Required)**
```
📶 Internet ON → Login with credentials → ✅ Success → 💾 Cache credentials
```

**Yang di-cache:**
- ✅ User data (name, email, role, merchant, branch)
- ✅ Auth token
- ✅ Email address
- ✅ Password hash (simplified)

### **2. Subsequent Login (Can Be Offline)**
```
🔴 Internet OFF → Login with same email → ✅ Load from cache → Success!
```

**Flow offline login:**
1. User masukkan email & password
2. App cek: **Ada internet?**
   - ❌ NO → Cek cached credentials
   - ✅ YES → Login ke server
3. Jika cached data ada → Login berhasil
4. Show notification: "🔴 Offline Mode"

---

## 🧪 Testing Offline Login

### **Step 1: Login Online Pertama Kali**
1. ✅ Pastikan emulator ada WiFi
2. ✅ Login dengan: `owner@pos.com` / `password`
3. ✅ Wait for "Login successful"
4. ✅ Credentials ter-cache otomatis

### **Step 2: Test Offline Login**
1. **Logout** dari app
2. **Matikan WiFi** di emulator:
   - Swipe down → Settings
   - Network & Internet → WiFi → OFF
3. **Kembali ke app**
4. **Login dengan credentials yang sama**
5. ✅ **Should work offline!**

**Expected result:**
```
🔴 Offline Mode
Logged in as John Doe
⚠️ Working offline - data will sync when online
```

---

## ⚠️ Important Notes

### **Limitations:**
1. **Harus login online minimal 1x** - Untuk cache credentials
2. **Password verification simplified** - Untuk demo purposes
3. **Token tidak di-refresh** - Bisa expired saat online lagi
4. **Email case-insensitive** - `owner@pos.com` = `OWNER@POS.COM`

### **Security Notes:**
- ⚠️ **Current implementation**: Password hash simplified (demo only)
- ✅ **For production**: Implement proper bcrypt/argon2 hashing
- ✅ **For production**: Add biometric authentication option
- ✅ **For production**: Add PIN code for offline access

---

## 🔧 Troubleshooting

### **Problem: "No cached credentials found"**
**Cause:** Belum pernah login online
**Solution:** Login dengan internet ON minimal 1x

### **Problem: "Email does not match"**
**Cause:** Mencoba login dengan email berbeda
**Solution:** Login dengan email yang sama seperti saat online login

### **Problem: Still asks for internet**
**Cause:** Cached data mungkin ter-clear
**Solution:** 
- Clear app data & cache
- Login online lagi
- Try offline login

---

## 🎯 Best Practices

### **For Development:**
1. ✅ Test online login first
2. ✅ Verify cache tersimpan (check logs)
3. ✅ Test offline dengan WiFi OFF
4. ✅ Test online sync setelah offline

### **For Production:**
1. ✅ Implement proper password hashing
2. ✅ Add biometric authentication
3. ✅ Add token refresh mechanism
4. ✅ Add offline session timeout
5. ✅ Encrypt cached data

---

## 📊 Debug Logs

Check console untuk logs:
```
🔴 Attempting offline login for: owner@pos.com
📦 Cached data check:
  - User data: ✅
  - Token: ✅
  - Email: ✅
  - Password hash: ✅
✅ Offline login successful for: owner@pos.com (owner)
```

---

## 🚀 Future Enhancements

**Planned features:**
- [ ] Biometric authentication (Face ID / Fingerprint)
- [ ] PIN code for quick offline access
- [ ] Offline session timeout
- [ ] Proper password hashing with crypto package
- [ ] Encrypted local storage
- [ ] Multi-user offline support

---

**Questions or issues? Check the logs or contact support!** 📱
