<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Category;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CategoryController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $categories = Category::with('department')
            ->withCount('reports')
            ->when($request->filled('dept_id'), fn ($query) => $query->where('dept_id', $request->integer('dept_id')))
            ->when($request->has('is_active'), fn ($query) => $query->where('is_active', $request->boolean('is_active')))
            ->when($request->filled('search'), fn ($query) => $query->where('category_name', 'like', '%'.$request->string('search')->toString().'%'))
            ->orderBy('category_name')
            ->paginate($request->integer('per_page', 15));

        return response()->json($categories);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'category_name' => ['required', 'string', 'max:100', 'unique:categories,category_name'],
            'description' => ['nullable', 'string'],
            'dept_id' => ['required', 'exists:departments,id'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $category = Category::create([
            ...$data,
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json([
            'message' => 'Category created successfully.',
            'category' => $category->load('department'),
        ], 201);
    }

    public function update(Request $request, Category $category): JsonResponse
    {
        $data = $request->validate([
            'category_name' => ['sometimes', 'required', 'string', 'max:100', Rule::unique('categories', 'category_name')->ignore($category->id)],
            'description' => ['nullable', 'string'],
            'dept_id' => ['sometimes', 'required', 'exists:departments,id'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $category->update($data);

        return response()->json([
            'message' => 'Category updated successfully.',
            'category' => $category->fresh()->load('department'),
        ]);
    }
}
