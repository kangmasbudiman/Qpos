<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CreateSaleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'branch_id' => 'required|exists:branches,id',
            'customer_id' => 'nullable|exists:customers,id',
            'items' => 'required|array|min:1',
            'items.*.product_id' => 'required|exists:products,id',
            'items.*.quantity' => 'required|integer|min:1',
            'items.*.price' => 'required|numeric|min:0',
            'items.*.discount' => 'nullable|numeric|min:0',
            'discount' => 'nullable|numeric|min:0',
            'tax' => 'nullable|numeric|min:0',
            'paid' => 'required|numeric|min:0',
            'payment_method' => 'required|in:cash,card,transfer,ewallet,debit,credit,qris,mixed',
            'notes' => 'nullable|string',
        ];
    }

    public function messages(): array
    {
        return [
            'branch_id.required' => 'Branch is required',
            'branch_id.exists' => 'Invalid branch selected',
            'items.required' => 'At least one item is required',
            'items.*.product_id.required' => 'Product is required for each item',
            'items.*.product_id.exists' => 'Invalid product selected',
            'items.*.quantity.required' => 'Quantity is required for each item',
            'items.*.quantity.min' => 'Quantity must be at least 1',
            'items.*.price.required' => 'Price is required for each item',
            'paid.required' => 'Payment amount is required',
            'paid.min' => 'Payment amount must be at least 0',
            'payment_method.required' => 'Payment method is required',
            'payment_method.in' => 'Invalid payment method',
        ];
    }
}