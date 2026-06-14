<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Report extends Model
{
    private const SLA_WARNING_REMAINING_RATIO = 0.25;

    protected $fillable = [
        'report_number', 'citizen_id', 'category_id', 'dept_id', 'area_id',
        'title', 'description', 'latitude', 'longitude', 'severity', 'status',
        'ai_suggested_category', 'is_duplicate', 'parent_report_id',
        'rejection_reason', 'completion_report', 'closed_at', 'sla_due_at'
    ];

    protected $casts = [
        'is_duplicate' => 'boolean',
        'latitude' => 'decimal:8',
        'longitude' => 'decimal:8',
        'closed_at' => 'datetime',
        'sla_due_at' => 'datetime',
    ];

    protected $appends = [
        'sla_status',
        'sla_color',
        'sla_remaining_seconds',
        'sla_overdue_seconds',
        'sla_progress_percent',
    ];

    public function getSlaStatusAttribute(): ?string
    {
        if (! $this->sla_due_at) {
            return null;
        }

        if ($this->status === 'closed') {
            return 'completed';
        }

        if (now()->greaterThanOrEqualTo($this->sla_due_at)) {
            return 'overdue';
        }

        $totalSeconds = $this->slaTotalSeconds();

        if ($totalSeconds <= 0) {
            return 'approaching';
        }

        return $this->slaRemainingSeconds() <= ($totalSeconds * self::SLA_WARNING_REMAINING_RATIO)
            ? 'approaching'
            : 'on_track';
    }

    public function getSlaColorAttribute(): ?string
    {
        return match ($this->sla_status) {
            'completed' => 'gray',
            'overdue' => 'red',
            'approaching' => 'yellow',
            'on_track' => 'green',
            default => null,
        };
    }

    public function getSlaRemainingSecondsAttribute(): ?int
    {
        if (! $this->sla_due_at || in_array($this->sla_status, ['completed', 'overdue'], true)) {
            return null;
        }

        return $this->slaRemainingSeconds();
    }

    public function getSlaOverdueSecondsAttribute(): ?int
    {
        if (! $this->sla_due_at || $this->sla_status !== 'overdue') {
            return null;
        }

        return now()->diffInSeconds($this->sla_due_at);
    }

    public function getSlaProgressPercentAttribute(): ?int
    {
        if (! $this->sla_due_at || ! $this->created_at) {
            return null;
        }

        if ($this->sla_status === 'completed') {
            return 100;
        }

        $totalSeconds = $this->slaTotalSeconds();

        if ($totalSeconds <= 0) {
            return 100;
        }

        $elapsedSeconds = max(0, $this->created_at->diffInSeconds(now(), false));

        return min(100, (int) round(($elapsedSeconds / $totalSeconds) * 100));
    }

    private function slaTotalSeconds(): int
    {
        if (! $this->created_at || ! $this->sla_due_at) {
            return 0;
        }

        return max(0, $this->created_at->diffInSeconds($this->sla_due_at, false));
    }

    private function slaRemainingSeconds(): int
    {
        if (! $this->sla_due_at) {
            return 0;
        }

        return max(0, now()->diffInSeconds($this->sla_due_at, false));
    }

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
