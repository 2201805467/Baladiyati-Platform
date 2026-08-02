<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LostFoundChatMessage extends Model
{
    protected $fillable = [
        'lost_found_chat_thread_id',
        'sender_id',
        'message_text',
    ];

    public function thread(): BelongsTo
    {
        return $this->belongsTo(LostFoundChatThread::class, 'lost_found_chat_thread_id');
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }
}
