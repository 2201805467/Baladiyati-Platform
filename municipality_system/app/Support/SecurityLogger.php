<?php

namespace App\Support;

use App\Models\SecurityLog;
use App\Models\User;
use Illuminate\Http\Request;

class SecurityLogger
{
    public static function log(Request $request, ?User $user, string $action, string $status): void
    {
        if (! $user) {
            return;
        }

        SecurityLog::create([
            'user_id' => $user->id,
            'action' => str($action)->limit(100, '')->toString(),
            'ip_address' => $request->ip() ?? 'unknown',
            'status' => $status,
        ]);
    }
}
