<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Department;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
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

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'dept_name' => ['required', 'string', 'max:100', 'unique:departments,dept_name'],
            'description' => ['nullable', 'string'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $department = Department::create([
            ...$data,
            'is_active' => $data['is_active'] ?? true,
        ]);

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
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $department->update($data);

        return response()->json([
            'message' => 'Department updated successfully.',
            'department' => $department->fresh()->load('account'),
        ]);
    }

    public function destroy(Request $request, Department $department): JsonResponse
    {
        $request->validate([
            'confirm' => ['accepted'],
        ]);

        if ($department->users()->exists()) {
            return response()->json([
                'message' => 'Department cannot be deleted while users are linked to it.',
            ], 422);
        }

        if ($department->categories()->exists()) {
            return response()->json([
                'message' => 'Department cannot be deleted while categories are linked to it.',
            ], 422);
        }

        if ($department->reports()->exists()) {
            return response()->json([
                'message' => 'Department cannot be deleted while reports are linked to it.',
            ], 422);
        }

        $department->delete();

        return response()->json([
            'message' => 'Department deleted successfully.',
        ]);
    }
}
