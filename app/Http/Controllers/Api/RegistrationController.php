<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Mail\RegistrationApproved;
use App\Mail\RegistrationRejected;
use App\Models\Branch;
use App\Models\Merchant;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class RegistrationController extends Controller
{
    /**
     * List semua pendaftar (untuk super_admin)
     * Filter by status: pending, approved, rejected, all
     */
    public function index(Request $request)
    {
        $status = $request->query('status', 'pending');

        $query = Merchant::with('owner')
            ->orderBy('created_at', 'desc');

        if ($status !== 'all') {
            $query->where('registration_status', $status);
        }

        $merchants = $query->paginate(15);

        $data = $merchants->map(function ($merchant) {
            return [
                'id'                  => $merchant->id,
                'merchant_name'       => $merchant->name,
                'business_type'       => $merchant->business_type,
                'address'             => $merchant->address,
                'phone'               => $merchant->phone,
                'email'               => $merchant->email,
                'registration_status' => $merchant->registration_status,
                'rejection_reason'    => $merchant->rejection_reason,
                'company_code'        => $merchant->company_code,
                'approved_at'         => $merchant->approved_at,
                'rejected_at'         => $merchant->rejected_at,
                'registered_at'       => $merchant->created_at,
                'owner'               => $merchant->owner ? [
                    'id'    => $merchant->owner->id,
                    'name'  => $merchant->owner->name,
                    'email' => $merchant->owner->email,
                    'phone' => $merchant->owner->phone,
                ] : null,
            ];
        });

        return response()->json([
            'success' => true,
            'data'    => $data,
            'meta'    => [
                'current_page' => $merchants->currentPage(),
                'last_page'    => $merchants->lastPage(),
                'per_page'     => $merchants->perPage(),
                'total'        => $merchants->total(),
            ],
        ]);
    }

    /**
     * Detail satu pendaftar
     */
    public function show($id)
    {
        $merchant = Merchant::with('owner')->find($id);

        if (!$merchant) {
            return response()->json([
                'success' => false,
                'message' => 'Data tidak ditemukan'
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data'    => [
                'id'                  => $merchant->id,
                'merchant_name'       => $merchant->name,
                'business_type'       => $merchant->business_type,
                'address'             => $merchant->address,
                'phone'               => $merchant->phone,
                'email'               => $merchant->email,
                'registration_status' => $merchant->registration_status,
                'rejection_reason'    => $merchant->rejection_reason,
                'company_code'        => $merchant->company_code,
                'approved_at'         => $merchant->approved_at,
                'rejected_at'         => $merchant->rejected_at,
                'registered_at'       => $merchant->created_at,
                'owner'               => $merchant->owner ? [
                    'id'    => $merchant->owner->id,
                    'name'  => $merchant->owner->name,
                    'email' => $merchant->owner->email,
                    'phone' => $merchant->owner->phone,
                ] : null,
            ],
        ]);
    }

    /**
     * Approve pendaftaran merchant
     * Generate company_code dan aktifkan merchant + user owner
     */
    public function approve(Request $request, $id)
    {
        $merchant = Merchant::with('owner')->find($id);

        if (!$merchant) {
            return response()->json([
                'success' => false,
                'message' => 'Data tidak ditemukan'
            ], 404);
        }

        if ($merchant->registration_status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Pendaftaran ini sudah diproses sebelumnya (status: ' . $merchant->registration_status . ')'
            ], 422);
        }

        // Generate company_code unik (8 karakter huruf besar)
        do {
            $companyCode = strtoupper(Str::random(8));
        } while (Merchant::where('company_code', $companyCode)->exists());

        // Update merchant: approved + generate company_code + aktifkan
        $merchant->update([
            'registration_status' => 'approved',
            'company_code'        => $companyCode,
            'is_active'           => true,
            'approved_at'         => now(),
            'rejection_reason'    => null,
        ]);

        // Aktifkan user owner
        if ($merchant->owner) {
            $merchant->owner->update(['is_active' => true]);
        }

        // Buat cabang utama otomatis jika belum ada
        $branch = null;
        if (!Branch::where('merchant_id', $merchant->id)->exists()) {
            $branchCode = strtoupper(substr($companyCode, 0, 4)) . '01';
            $branch = Branch::create([
                'merchant_id' => $merchant->id,
                'name'        => 'Cabang Utama',
                'code'        => $branchCode,
                'address'     => $merchant->address,
                'phone'       => $merchant->phone,
                'city'        => null,
                'is_active'   => true,
            ]);
        }

        // Kirim email notifikasi ke merchant (fire & forget, gagal tidak menghentikan proses)
        $emailTo = $merchant->owner?->email ?? $merchant->email;
        if ($emailTo) {
            try {
                Mail::to($emailTo)->send(new RegistrationApproved($merchant, $companyCode));
            } catch (\Throwable $e) {
                Log::error('Failed to send approval email to ' . $emailTo . ': ' . $e->getMessage());
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'Pendaftaran berhasil disetujui',
            'data'    => [
                'merchant_id'   => $merchant->id,
                'merchant_name' => $merchant->name,
                'company_code'  => $companyCode,
                'owner_name'    => $merchant->owner->name ?? '-',
                'owner_email'   => $merchant->owner->email ?? '-',
                'approved_at'   => $merchant->approved_at,
                'branch'        => $branch ? [
                    'id'   => $branch->id,
                    'name' => $branch->name,
                    'code' => $branch->code,
                ] : null,
            ],
        ]);
    }

    /**
     * Reject pendaftaran merchant
     */
    public function reject(Request $request, $id)
    {
        $validator = Validator::make($request->all(), [
            'rejection_reason' => 'required|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Alasan penolakan wajib diisi',
                'errors'  => $validator->errors()
            ], 422);
        }

        $merchant = Merchant::with('owner')->find($id);

        if (!$merchant) {
            return response()->json([
                'success' => false,
                'message' => 'Data tidak ditemukan'
            ], 404);
        }

        if ($merchant->registration_status !== 'pending') {
            return response()->json([
                'success' => false,
                'message' => 'Pendaftaran ini sudah diproses sebelumnya (status: ' . $merchant->registration_status . ')'
            ], 422);
        }

        $merchant->update([
            'registration_status' => 'rejected',
            'rejection_reason'    => $request->rejection_reason,
            'is_active'           => false,
            'rejected_at'         => now(),
        ]);

        // Kirim email notifikasi penolakan ke merchant (fire & forget)
        $emailTo = $merchant->owner?->email ?? $merchant->email;
        if ($emailTo) {
            try {
                Mail::to($emailTo)->send(new RegistrationRejected($merchant, $request->rejection_reason));
            } catch (\Throwable $e) {
                Log::error('Failed to send rejection email to ' . $emailTo . ': ' . $e->getMessage());
            }
        }

        return response()->json([
            'success' => true,
            'message' => 'Pendaftaran berhasil ditolak',
            'data'    => [
                'merchant_id'      => $merchant->id,
                'merchant_name'    => $merchant->name,
                'owner_name'       => $merchant->owner->name ?? '-',
                'owner_email'      => $merchant->owner->email ?? '-',
                'rejection_reason' => $merchant->rejection_reason,
                'rejected_at'      => $merchant->rejected_at,
            ],
        ]);
    }

    /**
     * Kirim ulang kode perusahaan ke email merchant (hanya untuk status approved)
     */
    public function resendCode(Request $request, $id)
    {
        $merchant = Merchant::with('owner')->find($id);

        if (!$merchant) {
            return response()->json([
                'success' => false,
                'message' => 'Data tidak ditemukan'
            ], 404);
        }

        if ($merchant->registration_status !== 'approved') {
            return response()->json([
                'success' => false,
                'message' => 'Kode hanya bisa dikirim ulang untuk merchant yang sudah disetujui'
            ], 422);
        }

        if (!$merchant->company_code) {
            return response()->json([
                'success' => false,
                'message' => 'Merchant ini belum memiliki kode perusahaan'
            ], 422);
        }

        $emailTo = $merchant->owner?->email ?? $merchant->email;
        if (!$emailTo) {
            return response()->json([
                'success' => false,
                'message' => 'Email merchant tidak ditemukan'
            ], 422);
        }

        try {
            Mail::to($emailTo)->send(new RegistrationApproved($merchant, $merchant->company_code));
        } catch (\Throwable $e) {
            Log::error('Failed to resend company code email to ' . $emailTo . ': ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Gagal mengirim email: ' . $e->getMessage()
            ], 500);
        }

        return response()->json([
            'success' => true,
            'message' => 'Kode perusahaan berhasil dikirim ulang ke ' . $emailTo,
            'data'    => [
                'email_to'     => $emailTo,
                'company_code' => $merchant->company_code,
            ],
        ]);
    }

    /**
     * Statistik ringkasan pendaftaran (untuk dashboard owner app)
     */
    public function stats()
    {
        return response()->json([
            'success' => true,
            'data'    => [
                'pending'  => Merchant::where('registration_status', 'pending')->count(),
                'approved' => Merchant::where('registration_status', 'approved')->count(),
                'rejected' => Merchant::where('registration_status', 'rejected')->count(),
                'total'    => Merchant::count(),
            ],
        ]);
    }
}
