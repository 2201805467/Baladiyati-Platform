<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ReportImage extends Model
{
    protected $fillable = ['report_id', 'image_url', 'image_type', 'uploaded_by'];
    
    public $timestamps = false; // نعتمد على حقل uploaded_at المجهز بالـ Migration

    // الصورة تنتمي لبلاغ محدد
    public function report(): BelongsTo
    {
        return $this->belongsTo(Report::class, 'report_id');
    }

    // من قام برفع الصورة (مواطن أو موظف ميداني)
    public function uploader(): BelongsTo
    {
        return $this->belongsTo(User::class, 'uploaded_by');
    }
}