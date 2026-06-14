<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Permission;
use App\Models\Role;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PermissionController extends Controller
{
    public function roles(): JsonResponse
    {
        return response()->json([
            'roles' => Role::with('permissions')
                ->orderBy('role_name')
                ->get(),
        ]);
    }

    public function permissions(): JsonResponse
    {
        return response()->json([
            'permissions' => Permission::orderBy('permission_name')->get(),
        ]);
    }

    public function updateRolePermissions(Request $request, Role $role): JsonResponse
    {
        $data = $request->validate([
            'permission_ids' => ['required', 'array'],
            'permission_ids.*' => ['integer', 'exists:permissions,id'],
        ]);

        $role->permissions()->sync($data['permission_ids']);

        return response()->json([
            'message' => 'Role permissions updated successfully.',
            'role' => $role->fresh()->load('permissions'),
        ]);
    }
}
