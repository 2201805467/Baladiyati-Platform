<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Report extends Model
{
    protected $fillable = [
        'report_number', 'citizen_id', 'category_id', 'dept_id', 'area_id',
        'title', 'description', 'latitude', 'longitude', 'severity', 'status',
        'ai_suggested_category', 'is_duplicate', 'parent_report_id', 'closed_at'
    ];

    protected $casts = [
        'is_duplicate' => 'boolean',
        'latitude' => 'decimal:8',
        'longitude' => 'decimal:8',
        'closed_at' => 'datetime',
    ];

    // البلاغ يرفعه مواطن (مستخدم)
    public function citizen(): BelongsTo
    {
        return $this->belongsTo(User::class, 'citizen_id');
    }

    // البلاغ يتبع تصنيف معين
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class, 'category_id');
    }

    // البlaغ يوجه لقسم معين لمعالجته
    public function department(): BelongsTo
    {
        return $this->belongsTo(Department::class, 'dept_id');
    }

    // البلاغ يقع في منطقة جغرافية محددة
    public function area(): BelongsTo
    {
        return $this->belongsTo(Area::class, 'area_id');
    }

    // في حال تكرار البلاغ: ينتمي لبلاغ أب (أصلي)
    public function parentReport(): BelongsTo
    {
        return $this->belongsTo(Report::class, 'parent_report_id');
    }

    // البلاغ الأصلي قد تتبعه بلاغات مكررة كثيرة من مواطنين آخرين
    public function duplicateReports(): HasMany
    {
        return $this->hasMany(Report::class, 'parent_report_id');
    }

    // البلاغ له العديد من الصور (قبل وبعد الإصلاح)
    public function images(): HasMany
    {
        return $this->hasMany(ReportImage::class, 'report_id');
    }

    // تتبع الحركات والتغييرات الإدارية للبلاغ
    public function logs(): HasMany
    {
        return $this->hasMany(ReportLog::class, 'report_id');
    }

    // البلاغ يحتوي على تعليقات متعددة
    public function comments(): HasMany
    {
        return $this->hasMany(ReportComment::class, 'report_id');
    }

    // البلاغ يحصل على تقييم واحد فقط بعد إغلاقه (بناءً على قيد الفريد في الـ Migration)
    public function rating(): HasOne
    {
        return $this->hasOne(Rating::class, 'report_id');
    }

    
}
