<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $productId = $this->route('product') ?? $this->route('id');
        
        return [
            'name' => 'sometimes|string|max:255',
            'category_id' => 'nullable|exists:categories,id',
            'sku' => 'sometimes|string|unique:products,sku,' . $productId,
            'barcode' => 'nullable|string|unique:products,barcode,' . $productId,
            'description' => 'nullable|string',
            'price' => 'sometimes|numeric|min:0',
            'cost' => 'nullable|numeric|min:0',
            'unit' => 'nullable|string|max:50',
            'min_stock' => 'nullable|integer|min:0',
            'image' => 'nullable|string',
            'is_active' => 'boolean',
        ];
    }

    public function messages(): array
    {
        return [
            'sku.unique' => 'SKU already exists',
            'barcode.unique' => 'Barcode already exists',
            'price.numeric' => 'Price must be a number',
            'price.min' => 'Price must be at least 0',
            'cost.numeric' => 'Cost must be a number',
            'cost.min' => 'Cost must be at least 0',
        ];
    }
}