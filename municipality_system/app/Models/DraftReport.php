<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DraftReport extends Model
{
    protected $fillable = ['citizen_id', 'category_id', 'description', 'latitude', 'longitude', 'image_local_path'];

    protected $casts = [
        'latitude' => 'decimal:8',
        'longitude' => 'decimal:8',
    ];

    // المسودة تخص مواطن معين
    public function citizen(): BelongsTo
    {
        return $this->belongsTo(User::class, 'citizen_id');
    }

    // المسودة قد تتبع تصنيفاً معيناً تم اختياره مبدئياً
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class, 'category_id');
    }
}