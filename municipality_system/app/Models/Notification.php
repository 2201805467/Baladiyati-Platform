<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Notification extends Model
{
    protected $fillable = ['user_id', 'title', 'body', 'type', 'related_id', 'related_type', 'is_read'];

    protected $casts = [
        'is_read' => 'boolean',
    ];
    
    public $timestamps = false;

    // المستخدم المستلم للإشعار
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * علاقة المرجع متعدد الأشكال (Polymorphic Relation)
     * تتيح استدعاء الكيان المرتبط بالإشعار تلقائياً أياً كان نوعه
     */
    public function related()
    {
        return $this->morphTo(null, 'related_type', 'related_id');
    }
}