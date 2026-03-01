<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AppSetting;
use App\Models\User;
use App\Models\Merchant;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Mail;

class AuthController extends Controller
{
    /**
     * Register a new merchant owner - status pending menunggu approval super_admin
     */
    public function register(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name'          => 'required|string|max:255',
            'email'         => 'required|string|email|max:255|unique:users',
            'password'      => 'required|string|min:8|confirmed',
            'phone'         => 'nullable|string|max:20',
            'merchant_name' => 'required|string|max:255',
            'business_type' => 'nullable|string|max:255',
            'address'       => 'nullable|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors'  => $validator->errors()
            ], 422);
        }

        try {
            // Buat user sebagai owner tapi belum aktif (menunggu approval)
            $user = User::create([
                'name'      => $request->name,
                'email'     => $request->email,
                'password'  => Hash::make($request->password),
                'phone'     => $request->phone,
                'role'      => 'owner',
                'is_active' => false,
            ]);

            // Buat merchant dengan status pending (belum dapat company_code)
            $merchant = Merchant::create([
                'name'                => $request->merchant_name,
                'business_type'       => $request->business_type,
                'address'             => $request->address,
                'phone'               => $request->phone,
                'email'               => $request->email,
                'owner_user_id'       => $user->id,
                'is_active'           => false,
                'registration_status' => 'pending',
            ]);

            // Update user dengan merchant_id
            $user->update(['merchant_id' => $merchant->id]);

            return response()->json([
                'success' => true,
                'message' => 'Pendaftaran berhasil. Menunggu persetujuan dari admin. Anda akan mendapatkan kode perusahaan setelah disetujui.',
                'data'    => [
                    'user' => [
                        'id'    => $user->id,
                        'name'  => $user->name,
                        'email' => $user->email,
                        'phone' => $user->phone,
                    ],
                    'merchant' => [
                        'id'                  => $merchant->id,
                        'name'                => $merchant->name,
                        'business_type'       => $merchant->business_type,
                        'registration_status' => $merchant->registration_status,
                    ],
                ]
            ], 201);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Registration failed: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Check registration status by email
     */
    public function checkRegistrationStatus(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|email',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors'  => $validator->errors()
            ], 422);
        }

        $user = User::where('email', $request->email)
            ->where('role', 'owner')
            ->with('merchant')
            ->first();

        if (!$user || !$user->merchant) {
            return response()->json([
                'success' => false,
                'message' => 'Email tidak ditemukan'
            ], 404);
        }

        $merchant = $user->merchant;
        $data = [
            'registration_status' => $merchant->registration_status,
            'merchant_name'       => $merchant->name,
        ];

        if ($merchant->registration_status === 'approved') {
            $data['company_code'] = $merchant->company_code;
            $data['message']      = 'Pendaftaran Anda telah disetujui. Gunakan kode perusahaan untuk login.';
        } elseif ($merchant->registration_status === 'rejected') {
            $data['rejection_reason'] = $merchant->rejection_reason;
            $data['message']          = 'Pendaftaran Anda ditolak.';
        } else {
            $data['message'] = 'Pendaftaran Anda sedang menunggu persetujuan admin.';
        }

        return response()->json([
            'success' => true,
            'data'    => $data,
        ]);
    }

    /**
     * Lookup company by company_code - step pertama login
     * Return info company + list cabang aktif
     */
    public function lookupCompany(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'company_code' => 'required|string|max:10',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Company code is required',
                'errors'  => $validator->errors()
            ], 422);
        }

        $merchant = Merchant::where('company_code', strtoupper($request->company_code))
            ->where('is_active', true)
            ->with(['branches' => function ($q) {
                $q->where('is_active', true)->select('id', 'merchant_id', 'name', 'code', 'city', 'address', 'phone');
            }])
            ->first();

        if (!$merchant) {
            return response()->json([
                'success' => false,
                'message' => 'Company not found or inactive'
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data'    => [
                'merchant_id'   => $merchant->id,
                'company_name'  => $merchant->name,
                'company_code'  => $merchant->company_code,
                'business_type' => $merchant->business_type,
                'branches'      => $merchant->branches,
            ]
        ]);
    }

    /**
     * Login user dengan company_code
     * Super admin cukup email + password (tanpa company_code)
     */
    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'company_code' => 'nullable|string|max:10',
            'email'        => 'required|email',
            'password'     => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors'  => $validator->errors()
            ], 422);
        }

        // --- Login Super Admin (tanpa company_code) ---
        if (empty($request->company_code)) {
            $user = User::where('email', $request->email)
                ->where('role', 'super_admin')
                ->first();

            if (!$user || !Hash::check($request->password, $user->password)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Invalid credentials'
                ], 401);
            }

            if (!$user->is_active) {
                return response()->json([
                    'success' => false,
                    'message' => 'Account is inactive'
                ], 403);
            }

            $user->tokens()->delete();
            $token = $user->createToken('auth_token')->plainTextToken;

            return response()->json([
                'success' => true,
                'message' => 'Login successful',
                'data'    => [
                    'user'       => $user->makeHidden(['remember_token']),
                    'token'      => $token,
                    'token_type' => 'Bearer',
                ]
            ]);
        }

        // --- Login Owner/Cashier/Manager (dengan company_code) ---

        // Cari merchant berdasarkan company_code
        $merchant = Merchant::where('company_code', strtoupper($request->company_code))
            ->where('is_active', true)
            ->first();

        if (!$merchant) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid company code'
            ], 401);
        }

        // Cari user berdasarkan email DAN merchant_id
        $user = User::where('email', $request->email)
            ->where('merchant_id', $merchant->id)
            ->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid credentials'
            ], 401);
        }

        if (!$user->is_active) {
            return response()->json([
                'success' => false,
                'message' => 'Account is inactive'
            ], 403);
        }

        // Hanya role owner dan cashier yang boleh login via POS app
        if (!in_array($user->role, ['owner', 'cashier', 'manager'])) {
            return response()->json([
                'success' => false,
                'message' => 'Access denied for this role'
            ], 403);
        }

        // Hapus token lama
        $user->tokens()->delete();

        // Buat token baru
        $token = $user->createToken('auth_token')->plainTextToken;

        // Load branches milik merchant untuk dipilih user
        $branches = $merchant->branches()->where('is_active', true)
            ->select('id', 'merchant_id', 'name', 'code', 'city', 'address', 'phone')
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Login successful',
            'data'    => [
                'user'       => $user->makeHidden(['remember_token']),
                'merchant'   => [
                    'id'           => $merchant->id,
                    'name'         => $merchant->name,
                    'company_code' => $merchant->company_code,
                    'business_type'=> $merchant->business_type,
                ],
                'subscription' => $merchant->subscriptionInfo(),
                'pricing'     => [
                    'price_monthly'    => AppSetting::priceMonthly(),
                    'price_yearly'     => AppSetting::priceYearly(),
                    'trial_days'       => AppSetting::trialDays(),
                    'support_email'    => AppSetting::get('support_email', 'support@payzen.id'),
                    'support_whatsapp' => AppSetting::get('support_whatsapp', ''),
                ],
                'branches'   => $branches,
                'token'      => $token,
                'token_type' => 'Bearer',
            ]
        ]);
    }

    /**
     * Get branches for the logged-in user's merchant (used by mobile app to refresh branch list)
     */
    public function branches(Request $request)
    {
        $user = $request->user();

        if (!$user->merchant_id) {
            return response()->json([
                'success' => true,
                'data'    => [],
            ]);
        }

        $branches = \App\Models\Branch::where('merchant_id', $user->merchant_id)
            ->where('is_active', true)
            ->select('id', 'merchant_id', 'name', 'code', 'city', 'address', 'phone')
            ->get();

        return response()->json([
            'success' => true,
            'data'    => $branches,
        ]);
    }

    /**
     * Logout user
     */
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Logout successful'
        ]);
    }

    /**
     * Get current user profile
     */
    public function profile(Request $request)
    {
        return response()->json([
            'success' => true,
            'data'    => $request->user()->load(['merchant', 'branch'])
        ]);
    }

    /**
     * Update user profile
     */
    public function updateProfile(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name'  => 'sometimes|string|max:255',
            'phone' => 'nullable|string|max:20',
            'email' => 'sometimes|email|unique:users,email,' . $request->user()->id,
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors'  => $validator->errors()
            ], 422);
        }

        try {
            $user = $request->user();
            $user->update($request->only(['name', 'phone', 'email']));

            return response()->json([
                'success' => true,
                'message' => 'Profile updated successfully',
                'data'    => $user->load(['merchant', 'branch'])
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Update failed: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Forgot password — generate password baru & kirim ke email
     * POST /api/auth/forgot-password
     * Body: { email, company_code? }
     */
    public function forgotPassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email'        => 'required|email',
            'company_code' => 'nullable|string|max:10',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors'  => $validator->errors()
            ], 422);
        }

        // Cari user berdasarkan email
        $query = User::where('email', $request->email);

        // Jika ada company_code, batasi ke merchant tersebut
        if (!empty($request->company_code)) {
            $merchant = Merchant::where('company_code', strtoupper($request->company_code))
                ->where('is_active', true)
                ->first();

            if (!$merchant) {
                // Tetap return sukses agar tidak bocorkan info
                return response()->json([
                    'success' => true,
                    'message' => 'Jika email terdaftar, password baru telah dikirim ke email Anda.',
                ]);
            }

            $query->where('merchant_id', $merchant->id);
        }

        $user = $query->first();

        // Selalu return sukses agar tidak bocorkan apakah email exist atau tidak
        if (!$user || !$user->is_active) {
            return response()->json([
                'success' => true,
                'message' => 'Jika email terdaftar, password baru telah dikirim ke email Anda.',
            ]);
        }

        try {
            // Generate password baru (8 karakter: huruf + angka)
            $newPassword = Str::random(6) . rand(10, 99);

            // Update password user
            $user->update(['password' => Hash::make($newPassword)]);
            // Hapus semua token lama (paksa login ulang)
            $user->tokens()->delete();

            // Kirim email
            $storeName = $user->merchant?->name ?? 'PAYZEN';
            Mail::send([], [], function ($message) use ($user, $newPassword, $storeName) {
                $message->to($user->email, $user->name)
                    ->subject("[$storeName] Password Baru Anda")
                    ->html(view('emails.new_password', [
                        'name'        => $user->name,
                        'newPassword' => $newPassword,
                        'storeName'   => $storeName,
                        'email'       => $user->email,
                    ])->render());
            });

            return response()->json([
                'success' => true,
                'message' => 'Password baru telah dikirim ke email Anda. Silakan login dengan password baru.',
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal mengirim email. Periksa konfigurasi SMTP: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Change password
     */
    public function changePassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'current_password' => 'required|string',
            'new_password'     => 'required|string|min:8|confirmed',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors'  => $validator->errors()
            ], 422);
        }

        $user = $request->user();

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Current password is incorrect'
            ], 401);
        }

        try {
            $user->update(['password' => Hash::make($request->new_password)]);
            $user->tokens()->delete();

            return response()->json([
                'success' => true,
                'message' => 'Password changed successfully. Please login again.'
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Password change failed: ' . $e->getMessage()
            ], 500);
        }
    }
}
