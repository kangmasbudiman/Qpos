<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProductResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'sku' => $this->sku,
            'barcode' => $this->barcode,
            'description' => $this->description,
            'price' => number_format($this->price, 2, '.', ''),
            'cost' => number_format($this->cost, 2, '.', ''),
            'unit' => $this->unit,
            'min_stock' => $this->min_stock,
            'image' => $this->image,
            'is_active' => $this->is_active,
            'category' => $this->whenLoaded('category', function () {
                return new CategoryResource($this->category);
            }),
            'stock' => $this->whenLoaded('stocks', function () {
                return $this->stocks->map(function ($stock) {
                    return [
                        'branch_id' => $stock->branch_id,
                        'branch_name' => $stock->branch->name,
                        'quantity' => $stock->quantity,
                        'low_stock' => $stock->quantity <= $this->min_stock,
                    ];
                });
            }),
            'created_at' => $this->created_at?->format('Y-m-d H:i:s'),
            'updated_at' => $this->updated_at?->format('Y-m-d H:i:s'),
        ];
    }
}