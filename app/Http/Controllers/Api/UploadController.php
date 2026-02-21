<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;

class UploadController extends Controller
{
    /**
     * Upload a single image file.
     *
     * POST /api/upload/image
     * Body: multipart/form-data  { file: <image>, folder?: string }
     *
     * Returns: { success, url, path }
     */
    public function uploadImage(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'file'   => 'required|image|mimes:jpeg,jpg,png,webp|max:5120', // max 5 MB
            'folder' => 'nullable|string|max:50',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation error',
                'errors'  => $validator->errors(),
            ], 422);
        }

        try {
            $folder = $request->input('folder', 'products');
            // Sanitize folder name
            $folder = preg_replace('/[^a-zA-Z0-9_\-]/', '', $folder);

            $file     = $request->file('file');
            $filename = Str::uuid() . '.' . $file->getClientOriginalExtension();
            //$path     = $file->storeAs("public/{$folder}", $filename);
            // Simpan ke disk public TANPA prefix public/
            $path = $file->storeAs($folder, $filename, 'public');


            // Build public URL
            $url = rtrim(config('app.url'), '/') . '/qpos/storage/' . $folder . '/' . $filename;
            //$url = asset('storage/' . $folder . '/' . $filename);
            return response()->json([
                'success' => true,
                'message' => 'Image uploaded successfully',
                'url'     => $url,
                'path'    => $path,
            ], 201);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Upload failed: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Delete an uploaded image.
     *
     * DELETE /api/upload/image
     * Body: { path: "public/products/xxx.jpg" }
     */
    public function deleteImage(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'path' => 'required|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Path is required',
            ], 422);
        }

        try {
            $path = $request->input('path');

            // Security: only allow deleting from public/ folder
            if (!str_starts_with($path, 'public/')) {
                return response()->json([
                    'success' => false,
                    'message' => 'Invalid path',
                ], 403);
            }

            if (Storage::exists($path)) {
                Storage::delete($path);
            }

            return response()->json([
                'success' => true,
                'message' => 'Image deleted successfully',
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Delete failed: ' . $e->getMessage(),
            ], 500);
        }
    }
}
