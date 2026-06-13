<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ReportLog extends Model
{
    protected $fillable = ['report_id', 'action_by', 'action', 'old_status', 'new_status', 'note'];
    
    public $timestamps = false;

    public function report(): BelongsTo
    {
        return $this->belongsTo(Report::class, 'report_id');
    }

    // الموظف المسؤول عن الإجراء الإداري أو الجغرافي
    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'action_by');
    }
}