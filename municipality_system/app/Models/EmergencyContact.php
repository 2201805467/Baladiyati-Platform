<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class EmergencyContact extends Model
{
    protected $fillable = ['name', 'phone', 'alt_phone', 'category', 'description', 'added_by', 'is_active'];

    protected $casts = [
        'is_active' => 'boolean',
    ];
    
    public $timestamps = false;

    // الموظف الذي أضاف الرقم للدليل
    public function adder(): BelongsTo
    {
        return $this->belongsTo(User::class, 'added_by');
    }
}