<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class StaffController extends Controller
{
    /**
     * List all staff (cashier/manager) milik merchant yang sama
     */
    public function index(Request $request)
    {
        $merchantId = $request->user()->merchant_id;

        $staff = User::where('merchant_id', $merchantId)
            ->whereIn('role', ['cashier', 'manager'])
            ->when($request->branch_id, fn($q, $id) => $q->where('branch_id', $id))
            ->when($request->search, fn($q, $s) =>
                $q->where(fn($q2) => $q2->where('name', 'like', "%$s%")
                                         ->orWhere('email', 'like', "%$s%")))
            ->orderBy('name')
            ->get(['id', 'name', 'email', 'phone', 'role', 'branch_id', 'is_active', 'created_at']);

        return response()->json([
            'success' => true,
            'data'    => $staff,
        ]);
    }

    /**
     * Buat staff baru (role: cashier)
     * Hanya owner/manager yang boleh
     */
    public function store(Request $request)
    {
        $actor = $request->user();

        if (!in_array($actor->role, ['owner', 'manager'])) {
            return response()->json([
                'success' => false,
                'message' => 'Tidak punya izin untuk menambah staff',
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'name'      => 'required|string|max:255',
            'email'     => 'required|email|unique:users,email',
            'password'  => 'required|string|min:6',
            'phone'     => 'nullable|string|max:20',
            'role'      => 'required|in:cashier,manager',
            'branch_id' => 'nullable|exists:branches,id',
        ], [
            'email.unique'    => 'Email sudah digunakan',
            'password.min'    => 'Password minimal 6 karakter',
            'role.in'         => 'Role harus cashier atau manager',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal',
                'errors'  => $validator->errors(),
            ], 422);
        }

        // Manager hanya bisa buat cashier (bukan sesama manager)
        if ($actor->role === 'manager' && $request->role === 'manager') {
            return response()->json([
                'success' => false,
                'message' => 'Manager tidak dapat membuat akun manager',
            ], 403);
        }

        try {
            $staff = User::create([
                'name'        => $request->name,
                'email'       => $request->email,
                'password'    => Hash::make($request->password),
                'phone'       => $request->phone,
                'role'        => $request->role,
                'merchant_id' => $actor->merchant_id,
                'branch_id'   => $request->branch_id,
                'is_active'   => true,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Staff berhasil ditambahkan',
                'data'    => $staff->only([
                    'id', 'name', 'email', 'phone', 'role',
                    'branch_id', 'is_active', 'created_at',
                ]),
            ], 201);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal menambah staff: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Detail satu staff
     */
    public function show(Request $request, $id)
    {
        $staff = User::where('merchant_id', $request->user()->merchant_id)
            ->whereIn('role', ['cashier', 'manager'])
            ->find($id);

        if (!$staff) {
            return response()->json([
                'success' => false,
                'message' => 'Staff tidak ditemukan',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data'    => $staff->only([
                'id', 'name', 'email', 'phone', 'role',
                'branch_id', 'is_active', 'created_at',
            ]),
        ]);
    }

    /**
     * Update data staff (nama, telepon, role, branch, status)
     */
    public function update(Request $request, $id)
    {
        $actor = $request->user();

        if (!in_array($actor->role, ['owner', 'manager'])) {
            return response()->json([
                'success' => false,
                'message' => 'Tidak punya izin untuk mengubah staff',
            ], 403);
        }

        $staff = User::where('merchant_id', $actor->merchant_id)
            ->whereIn('role', ['cashier', 'manager'])
            ->find($id);

        if (!$staff) {
            return response()->json([
                'success' => false,
                'message' => 'Staff tidak ditemukan',
            ], 404);
        }

        $validator = Validator::make($request->all(), [
            'name'      => 'sometimes|string|max:255',
            'phone'     => 'nullable|string|max:20',
            'role'      => 'sometimes|in:cashier,manager',
            'branch_id' => 'nullable|exists:branches,id',
            'is_active' => 'sometimes|boolean',
            'password'  => 'nullable|string|min:6',
        ], [
            'password.min' => 'Password minimal 6 karakter',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validasi gagal',
                'errors'  => $validator->errors(),
            ], 422);
        }

        try {
            $data = $request->only(['name', 'phone', 'role', 'branch_id', 'is_active']);

            if ($request->filled('password')) {
                $data['password'] = Hash::make($request->password);
            }

            $staff->update($data);

            return response()->json([
                'success' => true,
                'message' => 'Staff berhasil diperbarui',
                'data'    => $staff->fresh()->only([
                    'id', 'name', 'email', 'phone', 'role',
                    'branch_id', 'is_active', 'created_at',
                ]),
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal memperbarui staff: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Hapus (soft-delete = nonaktifkan) staff
     */
    public function destroy(Request $request, $id)
    {
        $actor = $request->user();

        if ($actor->role !== 'owner') {
            return response()->json([
                'success' => false,
                'message' => 'Hanya owner yang dapat menghapus staff',
            ], 403);
        }

        $staff = User::where('merchant_id', $actor->merchant_id)
            ->whereIn('role', ['cashier', 'manager'])
            ->find($id);

        if (!$staff) {
            return response()->json([
                'success' => false,
                'message' => 'Staff tidak ditemukan',
            ], 404);
        }

        try {
            // Revoke semua token agar tidak bisa login lagi
            $staff->tokens()->delete();
            $staff->delete();

            return response()->json([
                'success' => true,
                'message' => 'Staff berhasil dihapus',
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Gagal menghapus staff: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Toggle aktif/nonaktif staff
     */
    public function toggleActive(Request $request, $id)
    {
        $actor = $request->user();

        if (!in_array($actor->role, ['owner', 'manager'])) {
            return response()->json([
                'success' => false,
                'message' => 'Tidak punya izin',
            ], 403);
        }

        $staff = User::where('merchant_id', $actor->merchant_id)
            ->whereIn('role', ['cashier', 'manager'])
            ->find($id);

        if (!$staff) {
            return response()->json([
                'success' => false,
                'message' => 'Staff tidak ditemukan',
            ], 404);
        }

        $staff->update(['is_active' => !$staff->is_active]);

        if (!$staff->is_active) {
            $staff->tokens()->delete(); // Paksa logout jika dinonaktifkan
        }

        return response()->json([
            'success' => true,
            'message' => $staff->is_active ? 'Staff diaktifkan' : 'Staff dinonaktifkan',
            'data'    => ['id' => $staff->id, 'is_active' => $staff->is_active],
        ]);
    }
}
