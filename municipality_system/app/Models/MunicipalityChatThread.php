<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class MunicipalityChatThread extends Model
{
    protected $fillable = [
        'citizen_id',
        'assigned_dept_id',
        'status',
        'last_message_at',
        'citizen_unread_count',
        'reception_unread_count',
        'department_unread_count',
        'closed_at',
    ];

    protected $casts = [
        'last_message_at' => 'datetime',
        'closed_at' => 'datetime',
    ];

    public function citizen(): BelongsTo
    {
        return $this->belongsTo(User::class, 'citizen_id');
    }

    public function assignedDepartment(): BelongsTo
    {
        return $this->belongsTo(Department::class, 'assigned_dept_id');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(MunicipalityChatMessage::class, 'thread_id');
    }
}
