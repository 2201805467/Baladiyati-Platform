<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Permission;
use App\Models\Role;
use App\Support\SecurityLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PermissionController extends Controller
{
    private const ROLE_ALLOWED_PERMISSIONS = [
        'admin' => [
            'manage_users',
            'manage_departments',
            'manage_categories',
            'manage_public_facilities',
            'manage_projects',
            'manage_permissions',
            'view_analytics',
            'review_reports',
            'assign_reports',
            'review_suggestions',
            'process_department_reports',
            'submit_reports',
            'submit_suggestions',
            'vote_suggestions',
            'rate_reports',
        ],
        'reception' => [
            'review_reports',
            'assign_reports',
            'review_suggestions',
            'manage_public_facilities',
            'manage_projects',
        ],
        'department' => [
            'process_department_reports',
        ],
        'citizen' => [
            'submit_reports',
            'submit_suggestions',
            'vote_suggestions',
            'rate_reports',
        ],
    ];

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

        $permissionIds = Permission::whereIn('id', $data['permission_ids'])
            ->whereIn('permission_name', self::ROLE_ALLOWED_PERMISSIONS[$role->role_name] ?? [])
            ->pluck('id')
            ->all();

        if (count($permissionIds) !== count(array_unique($data['permission_ids']))) {
            return response()->json([
                'message' => 'One or more permissions are not allowed for this role.',
            ], 422);
        }

        $role->permissions()->sync($permissionIds);
        SecurityLogger::log($request, $request->user(), 'admin.permissions.updated:'.$role->role_name, 'success');

        return response()->json([
            'message' => 'Role permissions updated successfully.',
            'role' => $role->fresh()->load('permissions'),
        ]);
    }
}
