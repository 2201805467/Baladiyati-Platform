<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Role extends Model
{
    protected $fillable = ['role_name', 'description'];
    
    public $timestamps = false;

    // الدور الواحد يحتوي على العديد من الصلاحيات
    public function permissions(): BelongsToMany
    {
        return $this->belongsToMany(Permission::class, 'role_permissions');
    }

    // الدور الواحد يمكن أن يحمله العديد من المستخدمين
    public function users(): HasMany
    {
        return $this->hasMany(User::class);
    }
}