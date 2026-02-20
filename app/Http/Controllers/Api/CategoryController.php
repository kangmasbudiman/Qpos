<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Branch;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class CategoryController extends Controller
{
    /**
     * Display a listing of categories.
     *
     * Query params:
     *   - branch_id: filter kategori milik branch tertentu
     *   - scope: "branch" | "merchant" | "all" (default "all")
     *     - branch  = hanya kategori khusus branch yang diminta
     *     - merchant = hanya kategori merchant-level (branch_id null)
     *     - all    = kategori merchant-level + kategori branch yang diminta
     */
    public function index(Request $request)
    {
        $merchantId = $request->user()->merchant_id;
        $branchId   = $request->branch_id;
        $scope      = $request->scope ?? 'all';

        // Pastikan branch milik merchant yang sama
        if ($branchId && !Branch::where('id', $branchId)->where('merchant_id', $merchantId)->exists()) {
            return response()->json([
                'success' => false,
                'message' => 'Branch not found'
            ], 404);
        }

        $query = Category::where('merchant_id', $merchantId)
            ->when($request->search, fn($q, $s) => $q->where('name', 'like', "%{$s}%"))
            ->when($request->has('is_active'), fn($q) => $q->where('is_active', $request->is_active))
            ->withCount('products')
            ->with('branch:id,name,code');

        if ($branchId) {
            match ($scope) {
                'branch'   => $query->where('branch_id', $branchId),
                'merchant' => $query->whereNull('branch_id'),
                default    => $query->where(fn($q) => $q->whereNull('branch_id')->orWhere('branch_id', $branchId)),
            };
        } else {
            // Tanpa branch_id: tampilkan semua (merchant-level + semua branch)
            if ($scope === 'merchant') {
                $query->whereNull('branch_id');
            }
        }

        $categories = $query->orderBy('name')->paginate($request->per_page ?? 15);

        return response()->json([
            'success' => true,
            'data'    => $categories
        ]);
    }

    /**
     * Store a newly created category.
     *
     * Body:
     *   - branch_id (nullable): jika diisi, kategori hanya untuk branch tersebut
     */
    public function store(Request $request)
    {
        $merchantId = $request->user()->merchant_id;

        $validator = Validator::make($request->all(), [
            'name'        => 'required|string|max:255',
            'description' => 'nullable|string',
            'is_active'   => 'boolean',
            'branch_id'   => 'nullable|integer|exists:branches,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors'  => $validator->errors()
            ], 422);
        }

        // Pastikan branch milik merchant ini
        if ($request->branch_id) {
            $branch = Branch::where('id', $request->branch_id)
                ->where('merchant_id', $merchantId)
                ->first();

            if (!$branch) {
                return response()->json([
                    'success' => false,
                    'message' => 'Branch not found or does not belong to your merchant'
                ], 404);
            }
        }

        try {
            $category = Category::create([
                'merchant_id' => $merchantId,
                'branch_id'   => $request->branch_id,
                'name'        => $request->name,
                'description' => $request->description,
                'is_active'   => $request->is_active ?? true,
            ]);

            $category->load('branch:id,name,code');

            return response()->json([
                'success' => true,
                'message' => 'Category created successfully',
                'data'    => $category
            ], 201);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to create category: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Display the specified category.
     */
    public function show(Request $request, $id)
    {
        $category = Category::where('merchant_id', $request->user()->merchant_id)
            ->with('branch:id,name,code')
            ->withCount('products')
            ->find($id);

        if (!$category) {
            return response()->json([
                'success' => false,
                'message' => 'Category not found'
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data'    => $category
        ]);
    }

    /**
     * Update the specified category.
     */
    public function update(Request $request, $id)
    {
        $merchantId = $request->user()->merchant_id;

        $category = Category::where('merchant_id', $merchantId)->find($id);

        if (!$category) {
            return response()->json([
                'success' => false,
                'message' => 'Category not found'
            ], 404);
        }

        $validator = Validator::make($request->all(), [
            'name'        => 'sometimes|string|max:255',
            'description' => 'nullable|string',
            'is_active'   => 'boolean',
            'branch_id'   => 'nullable|integer|exists:branches,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors'  => $validator->errors()
            ], 422);
        }

        // Pastikan branch milik merchant ini jika branch_id dikirim
        if ($request->has('branch_id') && $request->branch_id !== null) {
            $branch = Branch::where('id', $request->branch_id)
                ->where('merchant_id', $merchantId)
                ->first();

            if (!$branch) {
                return response()->json([
                    'success' => false,
                    'message' => 'Branch not found or does not belong to your merchant'
                ], 404);
            }
        }

        try {
            $category->update($request->only(['name', 'description', 'is_active', 'branch_id']));
            $category->load('branch:id,name,code');

            return response()->json([
                'success' => true,
                'message' => 'Category updated successfully',
                'data'    => $category
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to update category: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Remove the specified category.
     */
    public function destroy(Request $request, $id)
    {
        $category = Category::where('merchant_id', $request->user()->merchant_id)->find($id);

        if (!$category) {
            return response()->json([
                'success' => false,
                'message' => 'Category not found'
            ], 404);
        }

        try {
            $category->delete();

            return response()->json([
                'success' => true,
                'message' => 'Category deleted successfully'
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to delete category: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Get all categories for a specific branch (merchant-level + branch-specific).
     * Route: GET /branches/{branchId}/categories
     */
    public function byBranch(Request $request, $branchId)
    {
        $merchantId = $request->user()->merchant_id;

        $branch = Branch::where('id', $branchId)->where('merchant_id', $merchantId)->first();

        if (!$branch) {
            return response()->json([
                'success' => false,
                'message' => 'Branch not found'
            ], 404);
        }

        $categories = Category::where('merchant_id', $merchantId)
            ->where(fn($q) => $q->whereNull('branch_id')->orWhere('branch_id', $branchId))
            ->when($request->search, fn($q, $s) => $q->where('name', 'like', "%{$s}%"))
            ->when($request->has('is_active'), fn($q) => $q->where('is_active', $request->is_active))
            ->withCount('products')
            ->with('branch:id,name,code')
            ->orderByRaw('branch_id IS NULL DESC, name ASC')
            ->paginate($request->per_page ?? 15);

        return response()->json([
            'success' => true,
            'data'    => $categories,
            'branch'  => $branch->only(['id', 'name', 'code'])
        ]);
    }
}
