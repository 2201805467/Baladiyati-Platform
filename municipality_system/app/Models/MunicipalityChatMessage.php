<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MunicipalityChatMessage extends Model
{
    protected $fillable = [
        'thread_id',
        'sender_id',
        'sender_role',
        'message_text',
        'image_url',
        'latitude',
        'longitude',
        'is_system',
    ];

    protected $casts = [
        'latitude' => 'decimal:7',
        'longitude' => 'decimal:7',
        'is_system' => 'boolean',
    ];

    public function thread(): BelongsTo
    {
        return $this->belongsTo(MunicipalityChatThread::class, 'thread_id');
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }
}
