<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserHasRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (! $user || ! $user->role || ! in_array($user->role->role_name, $roles, true)) {
            return response()->json([
                'message' => 'Unauthorized role.',
            ], 403);
        }

        return $next($request);
    }
}
