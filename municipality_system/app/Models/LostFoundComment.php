<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LostFoundComment extends Model
{
    protected $fillable = [
        'lost_found_item_id',
        'user_id',
        'comment_text',
    ];

    public function item(): BelongsTo
    {
        return $this->belongsTo(LostFoundItem::class, 'lost_found_item_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
