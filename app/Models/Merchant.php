<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Merchant extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'company_code',
        'business_type',
        'address',
        'phone',
        'email',
        'owner_user_id',
        'is_active',
        'registration_status',
        'rejection_reason',
        'approved_at',
        'rejected_at',
        'subscription_status',
        'trial_ends_at',
        'subscription_ends_at',
        'plan_type',
        'subscription_tier',
        'last_payment_at',
        'last_payment_amount',
    ];

    protected $casts = [
        'is_active'            => 'boolean',
        'approved_at'          => 'datetime',
        'rejected_at'          => 'datetime',
        'trial_ends_at'        => 'datetime',
        'subscription_ends_at' => 'datetime',
        'last_payment_at'      => 'datetime',
    ];

    // ── Subscription helpers ──────────────────────────────────────────────

    /** Apakah merchant sedang dalam masa trial yang masih aktif */
    public function isOnTrial(): bool
    {
        return $this->subscription_status === 'trial'
            && $this->trial_ends_at
            && $this->trial_ends_at->isFuture();
    }

    /** Apakah langganan berbayar masih aktif */
    public function isSubscriptionActive(): bool
    {
        return $this->subscription_status === 'active'
            && $this->subscription_ends_at
            && $this->subscription_ends_at->isFuture();
    }

    /** Apakah merchant boleh akses aplikasi */
    public function canAccess(): bool
    {
        return $this->isOnTrial() || $this->isSubscriptionActive();
    }

    /** Berapa hari tersisa (trial atau subscription) */
    public function daysRemaining(): int
    {
        if ($this->isOnTrial()) {
            return max(0, (int) now()->diffInDays($this->trial_ends_at, false));
        }
        if ($this->isSubscriptionActive()) {
            return max(0, (int) now()->diffInDays($this->subscription_ends_at, false));
        }
        return 0;
    }

    /** Sync status subscription (panggil saat cek / sebelum kirim response) */
    public function syncSubscriptionStatus(): void
    {
        if ($this->subscription_status === 'suspended') return;

        if ($this->subscription_status === 'active' && $this->subscription_ends_at?->isPast()) {
            $this->update(['subscription_status' => 'expired']);
        } elseif ($this->subscription_status === 'trial' && $this->trial_ends_at?->isPast()) {
            $this->update(['subscription_status' => 'expired']);
        }
    }

    // ── Tier helpers ──────────────────────────────────────────────────────

    /**
     * Tier efektif: trial selalu dapat Business, paid sesuai subscription_tier.
     * Fallback ke 'starter' jika belum disetel.
     */
    public function effectiveTier(): string
    {
        if ($this->isOnTrial()) return 'business';
        return $this->subscription_tier ?? 'starter';
    }

    /** Limit kuantitatif per tier (cabang, staff, produk, laporan) */
    public function getLimit(string $feature): int
    {
        $limits = [
            'starter'  => [
                'branches'    => 1,
                'staff'       => 2,
                'products'    => 100,
                'report_days' => 30,
            ],
            'business' => [
                'branches'    => 5,
                'staff'       => 10,
                'products'    => PHP_INT_MAX,
                'report_days' => 365,
            ],
        ];
        return $limits[$this->effectiveTier()][$feature] ?? PHP_INT_MAX;
    }

    /** Fitur boolean — Business-only features */
    public function canUseFeature(string $feature): bool
    {
        $businessOnly = [
            'bluetooth_print', 'analytics', 'barcode_scanner',
            'loyalty', 'shift', 'item_discount', 'multi_payment',
        ];
        if (in_array($feature, $businessOnly)) {
            return $this->effectiveTier() === 'business';
        }
        return true;
    }

    /** Data subscription untuk dikirim ke Flutter */
    public function subscriptionInfo(): array
    {
        $this->syncSubscriptionStatus();
        return [
            'status'         => $this->subscription_status,
            'days_remaining' => $this->daysRemaining(),
            'trial_ends_at'  => $this->trial_ends_at?->toDateString(),
            'sub_ends_at'    => $this->subscription_ends_at?->toDateString(),
            'plan_type'      => $this->plan_type,
            'can_access'     => $this->canAccess(),
            'tier'           => $this->effectiveTier(),
            'limits'         => [
                'branches'    => $this->getLimit('branches'),
                'staff'       => $this->getLimit('staff'),
                'products'    => $this->getLimit('products') === PHP_INT_MAX ? -1 : $this->getLimit('products'),
                'report_days' => $this->getLimit('report_days'),
            ],
            'features'       => [
                'bluetooth_print' => $this->canUseFeature('bluetooth_print'),
                'analytics'       => $this->canUseFeature('analytics'),
                'barcode_scanner' => $this->canUseFeature('barcode_scanner'),
                'loyalty'         => $this->canUseFeature('loyalty'),
                'shift'           => $this->canUseFeature('shift'),
                'item_discount'   => $this->canUseFeature('item_discount'),
                'multi_payment'   => $this->canUseFeature('multi_payment'),
            ],
        ];
    }

    // Relationships
    public function owner()
    {
        return $this->belongsTo(User::class, 'owner_user_id');
    }

    public function branches()
    {
        return $this->hasMany(Branch::class);
    }

    public function users()
    {
        return $this->hasMany(User::class);
    }

    public function products()
    {
        return $this->hasMany(Product::class);
    }

    public function categories()
    {
        return $this->hasMany(Category::class);
    }

    public function suppliers()
    {
        return $this->hasMany(Supplier::class);
    }

    public function customers()
    {
        return $this->hasMany(Customer::class);
    }

    public function sales()
    {
        return $this->hasMany(Sale::class);
    }

    public function purchases()
    {
        return $this->hasMany(Purchase::class);
    }
}
