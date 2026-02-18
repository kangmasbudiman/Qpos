<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Customer extends Model
{
    use HasFactory;

    protected $fillable = [
        'merchant_id',
        'name',
        'phone',
        'email',
        'address',
        'birthday',
        'total_spent',
        'total_transactions',
        'is_active',
    ];

    protected $casts = [
        'birthday' => 'date',
        'total_spent' => 'decimal:2',
        'is_active' => 'boolean',
    ];

    // Relationships
    public function merchant()
    {
        return $this->belongsTo(Merchant::class);
    }

    public function sales()
    {
        return $this->hasMany(Sale::class);
    }
}
