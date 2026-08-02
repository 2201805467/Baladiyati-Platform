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
        'employee_number', 'profile_image', 'phone_verified_at', 'email_verified_at', 'otp_code', 'otp_purpose',
        'otp_expires_at', 'is_active', 'initiative_registration_blocked_at',
        'initiative_registration_unblocked_at', 'initiative_registration_block_reason', 'role_id', 'dept_id',
        'home_latitude', 'home_longitude', 'last_latitude', 'last_longitude',
        'last_location_at', 'location_sharing_enabled',
    ];

    protected $hidden = ['password', 'remember_token'];

    protected $casts = [
        'is_active' => 'boolean',
        'phone_verified_at' => 'datetime',
        'email_verified_at' => 'datetime',
        'otp_expires_at' => 'datetime',
        'initiative_registration_blocked_at' => 'datetime',
        'initiative_registration_unblocked_at' => 'datetime',
        'home_latitude' => 'decimal:7',
        'home_longitude' => 'decimal:7',
        'last_latitude' => 'decimal:7',
        'last_longitude' => 'decimal:7',
        'last_location_at' => 'datetime',
        'location_sharing_enabled' => 'boolean',
    ];

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

    public function reportVotes(): HasMany
    {
        return $this->hasMany(ReportVote::class, 'citizen_id');
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

    public function createdInitiatives(): HasMany
    {
        return $this->hasMany(CommunityInitiative::class, 'created_by');
    }

    public function initiativeRegistrations(): HasMany
    {
        return $this->hasMany(InitiativeRegistration::class, 'citizen_id');
    }

    public function createdGeoBroadcasts(): HasMany
    {
        return $this->hasMany(GeoBroadcast::class, 'created_by');
    }

    public function geoBroadcastRecipients(): HasMany
    {
        return $this->hasMany(GeoBroadcastRecipient::class);
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
