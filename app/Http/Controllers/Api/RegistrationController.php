<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Merchant;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Validator;

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
