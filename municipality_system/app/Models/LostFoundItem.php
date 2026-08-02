<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class LostFoundItem extends Model
{
    protected $fillable = [
        'user_id',
        'item_type',
        'category',
        'title',
        'description',
        'image_url',
        'latitude',
        'longitude',
        'area_name',
        'incident_date',
        'pet_type',
        'pet_identifying_marks',
        'pet_has_collar',
        'status',
        'resolved_at',
        'expires_at',
        'removed_by',
        'removed_at',
        'removal_reason',
    ];

    protected $casts = [
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'incident_date' => 'date',
        'pet_has_collar' => 'boolean',
        'resolved_at' => 'datetime',
        'expires_at' => 'datetime',
        'removed_at' => 'datetime',
    ];

    public function publisher(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function remover(): BelongsTo
    {
        return $this->belongsTo(User::class, 'removed_by');
    }

    public function comments(): HasMany
    {
        return $this->hasMany(LostFoundComment::class)->orderBy('id');
    }

    public function chatThreads(): HasMany
    {
        return $this->hasMany(LostFoundChatThread::class);
    }
}
