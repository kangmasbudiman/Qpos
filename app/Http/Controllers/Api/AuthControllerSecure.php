<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Merchant;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rules\Password;
use Carbon\Carbon;

class AuthControllerSecure extends Controller
{
    /**
     * Login with enhanced security
     */
    public function login(Request $request)
    {
        // Rate limiting per IP
        $key = 'login_attempts:' . $request->ip();
        $maxAttempts = 5;
        $decayMinutes = 15;

        if (RateLimiter::tooManyAttempts($key, $maxAttempts)) {
            $seconds = RateLimiter::availableIn($key);
            Log::warning('Too many login attempts', [
                'ip' => $request->ip(),
                'email' => $request->email,
                'user_agent' => $request->header('User-Agent')
            ]);
            
            return response()->json([
                'success' => false,
                'message' => "Too many login attempts. Please try again in {$seconds} seconds."
            ], 429);
        }

        $validator = Validator::make($request->all(), [
            'email' => 'required|email',
            'password' => 'required|string',
            'device_name' => 'nullable|string|max:255', // Track device
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors' => $validator->errors()
            ], 422);
        }

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            // Increment failed attempts
            RateLimiter::hit($key, $decayMinutes * 60);
            
            // Log failed login attempt
            Log::warning('Failed login attempt', [
                'email' => $request->email,
                'ip' => $request->ip(),
                'user_agent' => $request->header('User-Agent'),
                'timestamp' => now()
            ]);

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

        // Clear rate limit on successful login
        RateLimiter::clear($key);

        // Optional: Limit concurrent sessions per user
        $user->tokens()->where('created_at', '<', now()->subDays(30))->delete(); // Cleanup old tokens
        
        // Create new token with device info
        $deviceName = $request->device_name ?? 'Unknown Device';
        $token = $user->createToken($deviceName, ['*'], now()->addDays(30))->plainTextToken;

        // Log successful login
        Log::info('Successful login', [
            'user_id' => $user->id,
            'email' => $user->email,
            'ip' => $request->ip(),
            'device' => $deviceName,
            'timestamp' => now()
        ]);

        // Update last login
        $user->update([
            'last_login_at' => now(),
            'last_login_ip' => $request->ip()
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Login successful',
            'data' => [
                'user' => $user->load(['merchant', 'branch']),
                'token' => $token,
                'token_type' => 'Bearer',
                'expires_in' => 30 * 24 * 60 * 60, // 30 days in seconds
            ]
        ], 200);
    }

    /**
     * Register with stronger password requirements
     */
    public function register(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users|confirmed', // Email confirmation
            'password' => [
                'required', 
                'confirmed',
                Password::min(8)
                    ->letters()
                    ->mixedCase()
                    ->numbers()
                    ->symbols()
                    ->uncompromised() // Check against data breaches
            ],
            'phone' => 'nullable|string|max:20',
            'merchant_name' => 'required|string|max:255',
            'business_type' => 'nullable|string|max:255',
            'terms_accepted' => 'required|boolean|accepted', // Terms and conditions
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            // Create user with email verification
            $user = User::create([
                'name' => $request->name,
                'email' => $request->email,
                'password' => Hash::make($request->password),
                'phone' => $request->phone,
                'role' => 'owner',
                'is_active' => true, // In production, set to false until email verified
                'email_verified_at' => now(), // In production, null until verified
                'registration_ip' => $request->ip(),
            ]);

            // Create merchant
            $merchant = Merchant::create([
                'name' => $request->merchant_name,
                'business_type' => $request->business_type,
                'owner_user_id' => $user->id,
                'is_active' => true,
            ]);

            $user->update(['merchant_id' => $merchant->id]);

            // Create token
            $token = $user->createToken('registration_token')->plainTextToken;

            // Log registration
            Log::info('User registered', [
                'user_id' => $user->id,
                'email' => $user->email,
                'merchant_name' => $merchant->name,
                'ip' => $request->ip(),
                'timestamp' => now()
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Registration successful',
                'data' => [
                    'user' => $user->load('merchant'),
                    'token' => $token,
                    'token_type' => 'Bearer',
                ]
            ], 201);

        } catch (\Exception $e) {
            Log::error('Registration failed', [
                'email' => $request->email,
                'error' => $e->getMessage(),
                'ip' => $request->ip()
            ]);
            
            return response()->json([
                'success' => false,
                'message' => 'Registration failed: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Two-Factor Authentication (Optional)
     */
    public function enableTwoFactor(Request $request)
    {
        // Implementation untuk 2FA
        // Bisa menggunakan Google Authenticator atau SMS OTP
    }

    /**
     * Logout dari semua device
     */
    public function logoutAll(Request $request)
    {
        $request->user()->tokens()->delete();
        
        Log::info('User logged out from all devices', [
            'user_id' => $request->user()->id,
            'ip' => $request->ip()
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Logged out from all devices successfully'
        ]);
    }

    /**
     * Get active sessions
     */
    public function activeSessions(Request $request)
    {
        $tokens = $request->user()->tokens()
            ->select('id', 'name', 'last_used_at', 'created_at')
            ->latest()
            ->get();

        return response()->json([
            'success' => true,
            'data' => $tokens
        ]);
    }
}