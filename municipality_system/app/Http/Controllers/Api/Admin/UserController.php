<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Mail\EmployeeCredentialsMail;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;
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
                    ->orWhere('phone', 'like', $search)
                    ->orWhere('employee_number', 'like', $search));
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
            'employee_number' => ['nullable', 'string', 'max:50', 'unique:users,employee_number'],
            'password' => ['nullable', 'string', 'min:6'],
            'role_id' => ['required', 'exists:roles,id'],
            'dept_id' => ['nullable', 'exists:departments,id', 'unique:users,dept_id'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $this->validateDepartmentRole($data['role_id'], $data['dept_id'] ?? null);
        $role = Role::findOrFail($data['role_id']);
        $this->validateEmployeeNumber($role, $data['employee_number'] ?? null);

        $plainPassword = $data['password'] ?? $this->generatePassword();

        $user = User::create([
            ...$data,
            'password' => Hash::make($plainPassword),
            'is_active' => $data['is_active'] ?? true,
        ]);

        if ($role->role_name !== 'citizen') {
            Mail::to($user->email)->send(new EmployeeCredentialsMail($user->load('role', 'department'), $plainPassword));
        }

        return response()->json([
            'message' => 'User created successfully.',
            'user' => $user->load(['role', 'department']),
            'credentials_sent' => $role->role_name !== 'citizen',
            'dev_password' => app()->isProduction() ? null : $plainPassword,
        ], 201);
    }

    public function update(Request $request, User $user): JsonResponse
    {
        $data = $request->validate([
            'full_name' => ['sometimes', 'required', 'string', 'max:100'],
            'email' => ['sometimes', 'required', 'email', 'max:100', Rule::unique('users', 'email')->ignore($user->id)],
            'phone' => ['sometimes', 'required', 'string', 'max:20', Rule::unique('users', 'phone')->ignore($user->id)],
            'employee_number' => ['nullable', 'string', 'max:50', Rule::unique('users', 'employee_number')->ignore($user->id)],
            'password' => ['nullable', 'string', 'min:6'],
            'role_id' => ['sometimes', 'required', 'exists:roles,id'],
            'dept_id' => ['nullable', 'exists:departments,id', Rule::unique('users', 'dept_id')->ignore($user->id)],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $roleId = $data['role_id'] ?? $user->role_id;
        $deptId = array_key_exists('dept_id', $data) ? $data['dept_id'] : $user->dept_id;
        $this->validateDepartmentRole($roleId, $deptId);
        $role = Role::findOrFail($roleId);
        $employeeNumber = array_key_exists('employee_number', $data)
            ? $data['employee_number']
            : $user->employee_number;
        $this->validateEmployeeNumber($role, $employeeNumber);

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

    public function destroy(Request $request, User $user): JsonResponse
    {
        $data = $request->validate([
            'confirm' => ['accepted'],
        ]);

        if ($request->user()->id === $user->id) {
            return response()->json([
                'message' => 'You cannot delete your own account.',
            ], 422);
        }

        $user->delete();

        return response()->json([
            'message' => 'User deleted permanently.',
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

    private function validateEmployeeNumber(Role $role, ?string $employeeNumber): void
    {
        if ($role->role_name !== 'citizen' && ! $employeeNumber) {
            abort(422, 'Employee number is required for staff accounts.');
        }

        if ($role->role_name === 'citizen' && $employeeNumber) {
            abort(422, 'Citizen accounts cannot have an employee number.');
        }
    }

    private function generatePassword(): string
    {
        return Str::password(12, letters: true, numbers: true, symbols: true, spaces: false);
    }
}
