<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

class Permission extends Model
{
    protected $fillable = ['permission_name', 'description'];
    
    public $timestamps = false; // لأن الجدول لا يحتوي على created_at و updated_at

    // الصلاحية الواحدة يمكن أن تنتمي لعدة أدوار
    public function roles(): BelongsToMany
    {
        return $this->belongsToMany(Role::class, 'role_permissions');
    }
}