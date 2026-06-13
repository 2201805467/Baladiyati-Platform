<?php

namespace App\Http\Controllers\Api\Reception;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Department;
use App\Models\Report;
use App\Models\ReportLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class ReportController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $reports = Report::with(['citizen', 'category', 'department', 'area', 'images'])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('category_id'), fn ($query) => $query->where('category_id', $request->integer('category_id')))
            ->when($request->filled('dept_id'), fn ($query) => $query->where('dept_id', $request->integer('dept_id')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = '%'.$request->string('search')->toString().'%';

                $query->where(function ($query) use ($search) {
                    $query->where('report_number', 'like', $search)
                        ->orWhere('title', 'like', $search)
                        ->orWhere('description', 'like', $search);
                });
            })
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return response()->json($reports);
    }

    public function show(Report $report): JsonResponse
    {
        return response()->json([
            'report' => $report->load([
                'citizen',
                'category.department',
                'department',
                'area',
                'images.uploader',
                'comments.user',
                'logs.actor',
                'rating',
            ]),
        ]);
    }

    public function classify(Request $request, Report $report): JsonResponse
    {
        $data = $request->validate([
            'category_id' => ['required', 'exists:categories,id'],
            'note' => ['nullable', 'string', 'max:2000'],
        ]);

        $category = Category::findOrFail($data['category_id']);
        $oldStatus = $report->status;

        DB::transaction(function () use ($report, $category, $request, $data, $oldStatus) {
            $report->update([
                'category_id' => $category->id,
                'dept_id' => $category->dept_id,
                'status' => $report->status === 'new' ? 'reviewed' : $report->status,
            ]);

            ReportLog::create([
                'report_id' => $report->id,
                'action_by' => $request->user()->id,
                'action' => 'classified',
                'old_status' => $oldStatus,
                'new_status' => $report->status,
                'note' => $data['note'] ?? 'Report classified by reception.',
            ]);
        });

        return response()->json([
            'message' => 'Report classified successfully.',
            'report' => $report->fresh()->load(['category', 'department', 'logs.actor']),
        ]);
    }

    public function assign(Request $request, Report $report): JsonResponse
    {
        $data = $request->validate([
            'dept_id' => ['required', 'exists:departments,id'],
            'status' => ['nullable', Rule::in(['assigned', 'in_progress', 'pending'])],
            'note' => ['nullable', 'string', 'max:2000'],
        ]);

        $department = Department::findOrFail($data['dept_id']);
        $oldStatus = $report->status;
        $newStatus = $data['status'] ?? 'assigned';

        DB::transaction(function () use ($report, $department, $request, $data, $oldStatus, $newStatus) {
            $report->update([
                'dept_id' => $department->id,
                'status' => $newStatus,
            ]);

            ReportLog::create([
                'report_id' => $report->id,
                'action_by' => $request->user()->id,
                'action' => 'assigned',
                'old_status' => $oldStatus,
                'new_status' => $newStatus,
                'note' => $data['note'] ?? 'Report assigned to department.',
            ]);
        });

        return response()->json([
            'message' => 'Report assigned successfully.',
            'report' => $report->fresh()->load(['category', 'department', 'logs.actor']),
        ]);
    }
}
