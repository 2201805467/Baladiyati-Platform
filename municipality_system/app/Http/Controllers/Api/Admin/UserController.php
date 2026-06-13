<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $users = User::with(['role', 'department'])
            ->when($request->filled('role'), fn ($query) => $query->whereHas('role', fn ($query) => $query->where('role_name', $request->string('role'))))
            ->when($request->has('is_active'), fn ($query) => $query->where('is_active', $request->boolean('is_active')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = '%'.$request->string('search')->toString().'%';

                $query->where(fn ($query) => $query
                    ->where('full_name', 'like', $search)
                    ->orWhere('email', 'like', $search)
                    ->orWhere('phone', 'like', $search));
            })
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return response()->json($users);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'full_name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'email', 'max:100', 'unique:users,email'],
            'phone' => ['required', 'string', 'max:20', 'unique:users,phone'],
            'password' => ['required', 'string', 'min:6'],
            'role_id' => ['required', 'exists:roles,id'],
            'dept_id' => ['nullable', 'exists:departments,id', 'unique:users,dept_id'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $this->validateDepartmentRole($data['role_id'], $data['dept_id'] ?? null);

        $user = User::create([
            ...$data,
            'password' => Hash::make($data['password']),
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json([
            'message' => 'User created successfully.',
            'user' => $user->load(['role', 'department']),
        ], 201);
    }

    public function update(Request $request, User $user): JsonResponse
    {
        $data = $request->validate([
            'full_name' => ['sometimes', 'required', 'string', 'max:100'],
            'email' => ['sometimes', 'required', 'email', 'max:100', Rule::unique('users', 'email')->ignore($user->id)],
            'phone' => ['sometimes', 'required', 'string', 'max:20', Rule::unique('users', 'phone')->ignore($user->id)],
            'password' => ['nullable', 'string', 'min:6'],
            'role_id' => ['sometimes', 'required', 'exists:roles,id'],
            'dept_id' => ['nullable', 'exists:departments,id', Rule::unique('users', 'dept_id')->ignore($user->id)],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $roleId = $data['role_id'] ?? $user->role_id;
        $deptId = array_key_exists('dept_id', $data) ? $data['dept_id'] : $user->dept_id;
        $this->validateDepartmentRole($roleId, $deptId);

        if (! empty($data['password'])) {
            $data['password'] = Hash::make($data['password']);
        } else {
            unset($data['password']);
        }

        $user->update($data);

        return response()->json([
            'message' => 'User updated successfully.',
            'user' => $user->fresh()->load(['role', 'department']),
        ]);
    }

    public function deactivate(User $user): JsonResponse
    {
        $user->update(['is_active' => false]);

        return response()->json([
            'message' => 'User deactivated successfully.',
            'user' => $user->fresh()->load(['role', 'department']),
        ]);
    }

    private function validateDepartmentRole(int $roleId, ?int $deptId): void
    {
        $role = Role::find($roleId);

        if ($role?->role_name === 'department' && ! $deptId) {
            abort(422, 'Department role accounts must be linked to a department.');
        }

        if ($role?->role_name !== 'department' && $deptId) {
            abort(422, 'Only department role accounts can be linked to a department.');
        }
    }
}
