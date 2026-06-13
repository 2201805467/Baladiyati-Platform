<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Category extends Model
{
    protected $fillable = ['category_name', 'description', 'dept_id', 'is_active'];
    
    public $timestamps = false;

    // التصنيف ينتمي لقسم إداري معين
    public function department(): BelongsTo
    {
        return $this->belongsTo(Department::class, 'dept_id');
    }

    // التصنيف يندرج تحته العديد من البلاغات
    public function reports(): HasMany
    {
        return $this->hasMany(Report::class, 'category_id');
    }

    // التصنيف قد يربط بالعديد من مسودات البلاغات
    public function draftReports(): HasMany
    {
        return $this->hasMany(DraftReport::class, 'category_id');
    }
}