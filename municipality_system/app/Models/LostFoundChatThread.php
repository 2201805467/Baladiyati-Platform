<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class LostFoundChatThread extends Model
{
    protected $fillable = [
        'lost_found_item_id',
        'publisher_id',
        'interested_user_id',
        'status',
    ];

    public function item(): BelongsTo
    {
        return $this->belongsTo(LostFoundItem::class, 'lost_found_item_id');
    }

    public function publisher(): BelongsTo
    {
        return $this->belongsTo(User::class, 'publisher_id');
    }

    public function interestedUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'interested_user_id');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(LostFoundChatMessage::class)->orderBy('id');
    }
}
