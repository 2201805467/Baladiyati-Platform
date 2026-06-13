<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ReportComment extends Model
{
    protected $fillable = ['report_id', 'user_id', 'comment_text'];
    
    public $timestamps = false;

    public function report(): BelongsTo
    {
        return $this->belongsTo(Report::class, 'report_id');
    }

    // كاتب التعليق (مواطن أو موظف)
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}