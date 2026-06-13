<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Department extends Model
{
    protected $fillable = ['dept_name', 'description', 'is_active'];

    // القسم الواحد يحتوي على العديد من الموظفين
    public function users(): HasMany
    {
        return $this->hasMany(User::class, 'dept_id');
    }

    public function account(): HasOne
    {
        return $this->hasOne(User::class, 'dept_id');
    }

    // القسم الواحد يمتلك العديد من تصنيفات البلاغات
    public function categories(): HasMany
    {
        return $this->hasMany(Category::class, 'dept_id');
    }

    // القسم يعالج العديد من البلاغات
    public function reports(): HasMany
    {
        return $this->hasMany(Report::class, 'dept_id');
    }
}
