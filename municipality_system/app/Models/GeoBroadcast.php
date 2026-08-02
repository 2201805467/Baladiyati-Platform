<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class GeoBroadcast extends Model
{
    protected $fillable = [
        'title',
        'body',
        'broadcast_type',
        'latitude',
        'longitude',
        'radius_meters',
        'starts_at',
        'ends_at',
        'status',
        'cancel_reason',
        'created_by',
    ];

    protected $casts = [
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'radius_meters' => 'integer',
        'starts_at' => 'datetime',
        'ends_at' => 'datetime',
    ];

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function recipients(): HasMany
    {
        return $this->hasMany(GeoBroadcastRecipient::class);
    }
}
