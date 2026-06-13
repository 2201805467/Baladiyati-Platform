<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PublicFacility extends Model
{
    protected $fillable = ['name', 'facility_type', 'latitude', 'longitude', 'working_hours', 'services', 'added_by', 'is_active'];

    protected $casts = [
        'is_active' => 'boolean',
        'latitude' => 'decimal:8',
        'longitude' => 'decimal:8',
    ];
    
    public $timestamps = false;

    // الموظف الذي أضاف المرفق العام
    public function adder(): BelongsTo
    {
        return $this->belongsTo(User::class, 'added_by');
    }
}