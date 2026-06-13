<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens; // مهمة جداً لتطبيق Flutter
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class User extends Authenticatable
{
    use HasApiTokens, Notifiable;

    protected $fillable = [
        'full_name', 'email', 'phone', 'password', 
        'profile_image', 'is_active', 'role_id', 'dept_id'
    ];

    protected $hidden = ['password', 'remember_token'];

    // المستخدم لديه دور محدد
    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class);
    }

    // المستخدم (الموظف) ينتمي لقسم معين (أو null للمواطن/الأدمن)
    public function department(): BelongsTo
    {
        return $this->belongsTo(Department::class, 'dept_id');
    }

    // المواطن يرفع العديد من البلاغات
    public function reports(): HasMany
    {
        return $this->hasMany(Report::class, 'citizen_id');
    }

    // المواطن يحفظ العديد من مسودات البلاغات
    public function drafts(): HasMany
    {
        return $this->hasMany(DraftReport::class, 'citizen_id');
    }

    // المواطن يقدم العديد من المقترحات
    public function suggestions(): HasMany
    {
        return $this->hasMany(Suggestion::class, 'citizen_id');
    }

    // الموظف يراجع العديد من المقترحات
    public function reviewedSuggestions(): HasMany
    {
        return $this->hasMany(Suggestion::class, 'reviewed_by');
    }

    public function suggestionVotes(): HasMany
    {
        return $this->hasMany(SuggestionVote::class, 'citizen_id');
    }

    public function ratings(): HasMany
    {
        return $this->hasMany(Rating::class, 'citizen_id');
    }

    public function uploadedReportImages(): HasMany
    {
        return $this->hasMany(ReportImage::class, 'uploaded_by');
    }

    public function reportLogs(): HasMany
    {
        return $this->hasMany(ReportLog::class, 'action_by');
    }

    public function reportComments(): HasMany
    {
        return $this->hasMany(ReportComment::class, 'user_id');
    }

    public function addedProjects(): HasMany
    {
        return $this->hasMany(CurrentProject::class, 'added_by');
    }

    public function addedFacilities(): HasMany
    {
        return $this->hasMany(PublicFacility::class, 'added_by');
    }

    public function addedEmergencyContacts(): HasMany
    {
        return $this->hasMany(EmergencyContact::class, 'added_by');
    }

    // المستخدم يستقبل العديد من الإشعارات
    public function notifications(): HasMany
    {
        return $this->hasMany(Notification::class);
    }
    
    // تتبع العمليات الأمنية للمستخدم
    public function securityLogs(): HasMany
    {
        return $this->hasMany(SecurityLog::class);
    }
}
