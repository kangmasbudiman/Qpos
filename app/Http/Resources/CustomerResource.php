<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CustomerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'phone' => $this->phone,
            'email' => $this->email,
            'address' => $this->address,
            'birthday' => $this->birthday?->format('Y-m-d'),
            'total_spent' => number_format($this->total_spent, 2, '.', ''),
            'total_transactions' => $this->total_transactions,
            'is_active' => $this->is_active,
            'recent_sales' => $this->whenLoaded('sales', function () {
                return $this->sales->map(function ($sale) {
                    return [
                        'id' => $sale->id,
                        'invoice_number' => $sale->invoice_number,
                        'total' => number_format($sale->total, 2, '.', ''),
                        'created_at' => $sale->created_at->format('Y-m-d H:i:s'),
                    ];
                });
            }),
            'created_at' => $this->created_at?->format('Y-m-d H:i:s'),
            'updated_at' => $this->updated_at?->format('Y-m-d H:i:s'),
        ];
    }
}