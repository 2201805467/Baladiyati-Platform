<?php

namespace App\Http\Middleware;

use App\Models\SecurityLog;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserHasPermission
{
    public function handle(Request $request, Closure $next, string ...$permissions): Response
    {
        $user = $request->user();
        $userPermissions = $user?->role?->permissions()
            ->pluck('permission_name')
            ->all() ?? [];

        $allowed = collect($permissions)->every(
            fn (string $permission) => in_array($permission, $userPermissions, true)
        );

        if (! $user || ! $allowed) {
            if ($user) {
                SecurityLog::create([
                    'user_id' => $user->id,
                    'action' => 'permission_denied:'.implode(',', $permissions),
                    'ip_address' => $request->ip() ?? 'unknown',
                    'status' => 'denied',
                ]);
            }

            return response()->json([
                'message' => 'You do not have permission to perform this action.',
            ], 403);
        }

        return $next($request);
    }
}
