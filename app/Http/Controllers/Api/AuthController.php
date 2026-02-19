<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Merchant;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    /**
     * Register a new user (merchant owner)
     * Auto-generate company_code saat register
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
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors'  => $validator->errors()
            ], 422);
        }

        try {
            // Buat user sebagai owner
            $user = User::create([
                'name'      => $request->name,
                'email'     => $request->email,
                'password'  => Hash::make($request->password),
                'phone'     => $request->phone,
                'role'      => 'owner',
                'is_active' => true,
            ]);

            // Generate company_code unik (8 karakter huruf besar)
            do {
                $companyCode = strtoupper(Str::random(8));
            } while (Merchant::where('company_code', $companyCode)->exists());

            // Buat merchant
            $merchant = Merchant::create([
                'name'          => $request->merchant_name,
                'company_code'  => $companyCode,
                'business_type' => $request->business_type,
                'owner_user_id' => $user->id,
                'is_active'     => true,
            ]);

            // Update user dengan merchant_id
            $user->update(['merchant_id' => $merchant->id]);

            // Buat token
            $token = $user->createToken('auth_token')->plainTextToken;

            return response()->json([
                'success' => true,
                'message' => 'Registration successful',
                'data'    => [
                    'user'         => $user->load('merchant'),
                    'token'        => $token,
                    'token_type'   => 'Bearer',
                    'company_code' => $companyCode,
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
     * company_code dipakai untuk validasi bahwa user milik merchant tersebut
     */
    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'company_code' => 'required|string|max:10',
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
                'branches'   => $branches,
                'token'      => $token,
                'token_type' => 'Bearer',
            ]
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
