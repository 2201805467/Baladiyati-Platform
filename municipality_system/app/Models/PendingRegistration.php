<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PendingRegistration extends Model
{
    protected $fillable = [
        'full_name',
        'email',
        'phone',
        'password',
        'otp_code',
        'otp_expires_at',
    ];

    protected $hidden = [
        'password',
        'otp_code',
    ];

    protected $casts = [
        'otp_expires_at' => 'datetime',
    ];
}
