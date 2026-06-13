<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Area extends Model
{
    protected $fillable = ['area_name', 'city', 'boundary_coords'];

    // المنطقة تقع فيها العديد من البلاغات
    public function reports(): HasMany
    {
        return $this->hasMany(Report::class, 'area_id');
    }

    // المنطقة تقام فيها العديد من المشاريع التنموية
    public function projects(): HasMany
    {
        return $this->hasMany(CurrentProject::class, 'area_id');
    }
}