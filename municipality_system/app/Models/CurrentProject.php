<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CurrentProject extends Model
{
    protected $fillable = ['name', 'description', 'area_id', 'contractor', 'progress_percent', 'start_date', 'end_date', 'added_by', 'status'];

    protected $casts = [
        'start_date' => 'date',
        'end_date' => 'date',
        'progress_percent' => 'integer'
    ];
    
    public $timestamps = false;

    // المنطقة الجغرافية التي ينفذ فيها المشروع التنموي
    public function area(): BelongsTo
    {
        return $this->belongsTo(Area::class, 'area_id');
    }

    // الموظف أو الإداري الذي أضاف المشروع للنظام
    public function adder(): BelongsTo
    {
        return $this->belongsTo(User::class, 'added_by');
    }
}