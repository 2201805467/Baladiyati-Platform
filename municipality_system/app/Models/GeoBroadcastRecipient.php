<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class GeoBroadcastRecipient extends Model
{
    protected $fillable = [
        'geo_broadcast_id',
        'user_id',
        'matched_by',
        'notification_id',
    ];

    public function broadcast(): BelongsTo
    {
        return $this->belongsTo(GeoBroadcast::class, 'geo_broadcast_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function notification(): BelongsTo
    {
        return $this->belongsTo(Notification::class);
    }
}
