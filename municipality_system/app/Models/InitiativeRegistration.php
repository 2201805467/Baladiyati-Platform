<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class InitiativeRegistration extends Model
{
    protected $fillable = [
        'initiative_id',
        'citizen_id',
        'status',
        'registered_at',
        'cancelled_at',
        'attended_at',
        'attendance_latitude',
        'attendance_longitude',
    ];

    protected $casts = [
        'registered_at' => 'datetime',
        'cancelled_at' => 'datetime',
        'attended_at' => 'datetime',
        'attendance_latitude' => 'decimal:8',
        'attendance_longitude' => 'decimal:8',
    ];

    public function initiative(): BelongsTo
    {
        return $this->belongsTo(CommunityInitiative::class, 'initiative_id');
    }

    public function citizen(): BelongsTo
    {
        return $this->belongsTo(User::class, 'citizen_id');
    }
}
