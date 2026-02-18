<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class SaleResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'invoice_number' => $this->invoice_number,
            'subtotal' => number_format($this->subtotal, 2, '.', ''),
            'discount' => number_format($this->discount, 2, '.', ''),
            'tax' => number_format($this->tax, 2, '.', ''),
            'total' => number_format($this->total, 2, '.', ''),
            'paid' => number_format($this->paid, 2, '.', ''),
            'change' => number_format($this->change, 2, '.', ''),
            'payment_method' => $this->payment_method,
            'status' => $this->status,
            'notes' => $this->notes,
            'customer' => $this->whenLoaded('customer', function () {
                return new CustomerResource($this->customer);
            }),
            'branch' => $this->whenLoaded('branch', function () {
                return [
                    'id' => $this->branch->id,
                    'name' => $this->branch->name,
                    'code' => $this->branch->code,
                ];
            }),
            'cashier' => $this->whenLoaded('user', function () {
                return [
                    'id' => $this->user->id,
                    'name' => $this->user->name,
                    'role' => $this->user->role,
                ];
            }),
            'items' => $this->whenLoaded('items', function () {
                return $this->items->map(function ($item) {
                    return [
                        'id' => $item->id,
                        'product_id' => $item->product_id,
                        'product_name' => $item->product_name,
                        'price' => number_format($item->price, 2, '.', ''),
                        'quantity' => $item->quantity,
                        'discount' => number_format($item->discount, 2, '.', ''),
                        'subtotal' => number_format($item->subtotal, 2, '.', ''),
                    ];
                });
            }),
            'created_at' => $this->created_at?->format('Y-m-d H:i:s'),
            'updated_at' => $this->updated_at?->format('Y-m-d H:i:s'),
        ];
    }
}