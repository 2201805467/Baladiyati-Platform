<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class CommunityInitiative extends Model
{
    protected $fillable = [
        'title',
        'description',
        'goal',
        'initiative_type',
        'cover_image_url',
        'starts_at',
        'ends_at',
        'latitude',
        'longitude',
        'radius_meters',
        'max_capacity',
        'target_audience',
        'requirements',
        'status',
        'cancel_reason',
        'completion_image_url',
        'created_by',
        'capacity_notified_at',
    ];

    protected $casts = [
        'starts_at' => 'datetime',
        'ends_at' => 'datetime',
        'latitude' => 'decimal:8',
        'longitude' => 'decimal:8',
        'radius_meters' => 'integer',
        'max_capacity' => 'integer',
        'capacity_notified_at' => 'datetime',
    ];

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function registrations(): HasMany
    {
        return $this->hasMany(InitiativeRegistration::class, 'initiative_id');
    }

    public function activeRegistrations(): HasMany
    {
        return $this->registrations()->where('status', 'registered');
    }

    public function attendees(): HasMany
    {
        return $this->registrations()->whereNotNull('attended_at');
    }
}
