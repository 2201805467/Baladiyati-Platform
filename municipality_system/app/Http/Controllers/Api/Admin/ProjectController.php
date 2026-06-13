<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\CurrentProject;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ProjectController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $projects = CurrentProject::with(['area', 'adder:id,full_name'])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('area_id'), fn ($query) => $query->where('area_id', $request->integer('area_id')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = '%'.$request->string('search')->toString().'%';

                $query->where(fn ($query) => $query
                    ->where('name', 'like', $search)
                    ->orWhere('description', 'like', $search)
                    ->orWhere('contractor', 'like', $search));
            })
            ->orderByDesc('id')
            ->paginate($request->integer('per_page', 15));

        return response()->json($projects);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:200'],
            'description' => ['nullable', 'string'],
            'area_id' => ['nullable', 'exists:areas,id'],
            'contractor' => ['nullable', 'string', 'max:100'],
            'progress_percent' => ['nullable', 'integer', 'min:0', 'max:100'],
            'start_date' => ['nullable', 'date'],
            'end_date' => ['nullable', 'date', 'after_or_equal:start_date'],
            'status' => ['nullable', Rule::in(['planned', 'in_progress', 'completed', 'paused', 'cancelled'])],
        ]);

        $project = CurrentProject::create([
            ...$data,
            'progress_percent' => $data['progress_percent'] ?? 0,
            'added_by' => $request->user()->id,
            'status' => $data['status'] ?? 'planned',
        ]);

        return response()->json([
            'message' => 'Project created successfully.',
            'project' => $project->load(['area', 'adder']),
        ], 201);
    }

    public function update(Request $request, CurrentProject $project): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:200'],
            'description' => ['nullable', 'string'],
            'area_id' => ['nullable', 'exists:areas,id'],
            'contractor' => ['nullable', 'string', 'max:100'],
            'progress_percent' => ['sometimes', 'integer', 'min:0', 'max:100'],
            'start_date' => ['nullable', 'date'],
            'end_date' => ['nullable', 'date', 'after_or_equal:start_date'],
            'status' => ['sometimes', Rule::in(['planned', 'in_progress', 'completed', 'paused', 'cancelled'])],
        ]);

        $project->update($data);

        return response()->json([
            'message' => 'Project updated successfully.',
            'project' => $project->fresh()->load(['area', 'adder']),
        ]);
    }
}
