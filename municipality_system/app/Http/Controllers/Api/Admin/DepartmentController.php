<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Department;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class DepartmentController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $departments = Department::with('account')
            ->withCount(['categories', 'reports'])
            ->when($request->has('is_active'), fn ($query) => $query->where('is_active', $request->boolean('is_active')))
            ->when($request->filled('search'), fn ($query) => $query->where('dept_name', 'like', '%'.$request->string('search')->toString().'%'))
            ->orderBy('dept_name')
            ->paginate($request->integer('per_page', 15));

        return response()->json($departments);
    }

    public function availableAccounts(): JsonResponse
    {
        $accounts = User::query()
            ->whereHas('role', fn ($query) => $query->where('role_name', 'department'))
            ->whereNull('dept_id')
            ->where('is_active', true)
            ->orderBy('full_name')
            ->get(['id', 'full_name', 'email', 'employee_number', 'dept_id']);

        return response()->json([
            'accounts' => $accounts,
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'dept_name' => ['required', 'string', 'max:100', 'unique:departments,dept_name'],
            'description' => ['nullable', 'string'],
            'account_id' => ['nullable', 'exists:users,id'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $department = DB::transaction(function () use ($data) {
            $accountId = $data['account_id'] ?? null;
            unset($data['account_id']);

            $department = Department::create([
                ...$data,
                'is_active' => $data['is_active'] ?? true,
            ]);

            if ($accountId) {
                $this->assignAccount($department, (int) $accountId);
            }

            return $department->fresh()->load('account');
        });

        return response()->json([
            'message' => 'Department created successfully.',
            'department' => $department,
        ], 201);
    }

    public function update(Request $request, Department $department): JsonResponse
    {
        $data = $request->validate([
            'dept_name' => ['sometimes', 'required', 'string', 'max:100', Rule::unique('departments', 'dept_name')->ignore($department->id)],
            'description' => ['nullable', 'string'],
            'account_id' => ['nullable', 'exists:users,id'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $department = DB::transaction(function () use ($department, $data) {
            $hasAccountUpdate = array_key_exists('account_id', $data);
            $accountId = $data['account_id'] ?? null;
            unset($data['account_id']);

            $department->update($data);

            if ($hasAccountUpdate) {
                User::where('dept_id', $department->id)->update(['dept_id' => null]);

                if ($accountId) {
                    $this->assignAccount($department, (int) $accountId);
                }
            }

            return $department->fresh()->load('account');
        });

        return response()->json([
            'message' => 'تم تحديث بيانات القسم بنجاح.',
            'department' => $department,
        ]);
    }

    public function destroy(Request $request, Department $department): JsonResponse
    {
        $request->validate([
            'confirm' => ['accepted'],
        ]);

        if ($department->users()->exists()) {
            return response()->json([
                'message' => 'لا يمكن حذف هذا القسم لوجود موظفين مرتبطين به حالياً، يرجى نقل الموظفين أولاً.',
            ], 422);
        }

        if ($department->categories()->exists()) {
            return response()->json([
                'message' => 'لا يمكن حذف هذا القسم لوجود تصنيفات بلاغات مرتبطة به حالياً، يرجى تعديل التصنيفات أولاً.',
            ], 422);
        }

        if ($department->reports()->exists()) {
            return response()->json([
                'message' => 'لا يمكن حذف هذا القسم لوجود بلاغات مرتبطة به في النظام.',
            ], 422);
        }

        $department->delete();

        return response()->json([
            'message' => 'تم حذف القسم الفني وإزالته من النظام بنجاح.',
        ]);
    }

    private function assignAccount(Department $department, int $accountId): void
    {
        $account = User::with('role')->findOrFail($accountId);

        if ($account->role?->role_name !== 'department') {
            abort(422, 'الحساب المختار ليس حساب موظف قسم.');
        }

        if ($account->dept_id && (int) $account->dept_id !== (int) $department->id) {
            abort(422, 'هذا الحساب مرتبط بقسم آخر حالياً.');
        }

        $account->update(['dept_id' => $department->id]);
    }
}
