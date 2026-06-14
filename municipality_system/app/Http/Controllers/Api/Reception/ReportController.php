<?php

namespace App\Http\Controllers\Api\Reception;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Department;
use App\Models\Notification;
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
            ->when(
                $request->filled('status'),
                fn ($query) => $query->where('status', $request->string('status')),
                fn ($query) => $query->where('status', 'new')
            )
            ->when($request->filled('category_id'), fn ($query) => $query->where('category_id', $request->integer('category_id')))
            ->when($request->filled('dept_id'), fn ($query) => $query->where('dept_id', $request->integer('dept_id')))
            ->when($request->filled('area_id'), fn ($query) => $query->where('area_id', $request->integer('area_id')))
            ->when($request->filled('severity'), fn ($query) => $query->where('severity', $request->string('severity')))
            ->when($request->filled('date_from'), fn ($query) => $query->whereDate('created_at', '>=', $request->date('date_from')))
            ->when($request->filled('date_to'), fn ($query) => $query->whereDate('created_at', '<=', $request->date('date_to')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = '%'.$request->string('search')->toString().'%';

                $query->where(function ($query) use ($search) {
                    $query->where('report_number', 'like', $search)
                        ->orWhere('title', 'like', $search)
                        ->orWhere('description', 'like', $search);
                });
            })
            ->orderBy('created_at')
            ->paginate($request->integer('per_page', 15));

        return response()->json($reports);
    }

    public function show(Request $request, Report $report): JsonResponse
    {
        if ($report->status === 'new') {
            $report->update(['status' => 'under_review']);

            ReportLog::create([
                'report_id' => $report->id,
                'action_by' => $request->user()->id,
                'action' => 'opened_for_review',
                'old_status' => 'new',
                'new_status' => 'under_review',
                'note' => 'Report opened by reception.',
            ]);

            $this->notifyCitizen(
                $report,
                'Report under review',
                'Your report '.$report->report_number.' is now under review.',
                'report_status'
            );
        }

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
                'duplicateReports',
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
                'status' => in_array($report->status, ['new', 'reviewed'], true) ? 'under_review' : $report->status,
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
            'note' => ['nullable', 'string', 'max:2000'],
        ]);

        $department = Department::findOrFail($data['dept_id']);
        $oldStatus = $report->status;
        $newStatus = 'transferred';

        DB::transaction(function () use ($report, $department, $request, $data, $oldStatus, $newStatus) {
            $report->update([
                'dept_id' => $department->id,
                'status' => $newStatus,
            ]);

            ReportLog::create([
                'report_id' => $report->id,
                'action_by' => $request->user()->id,
                'action' => 'transferred',
                'old_status' => $oldStatus,
                'new_status' => $newStatus,
                'note' => $data['note'] ?? 'Report transferred to department.',
            ]);

            $this->notifyCitizen(
                $report,
                'Report transferred',
                'Your report '.$report->report_number.' was transferred to '.$department->dept_name.'.',
                'report_status'
            );
        });

        return response()->json([
            'message' => 'Report transferred successfully.',
            'report' => $report->fresh()->load(['category', 'department', 'logs.actor']),
        ]);
    }

    public function reject(Request $request, Report $report): JsonResponse
    {
        $data = $request->validate([
            'rejection_reason' => ['required', 'string', 'max:2000'],
        ]);

        $reportNumber = $report->report_number;
        $citizenId = $report->citizen_id;

        DB::transaction(function () use ($report, $request, $data, $reportNumber, $citizenId) {
            ReportLog::create([
                'report_id' => $report->id,
                'action_by' => $request->user()->id,
                'action' => 'rejected',
                'old_status' => $report->status,
                'new_status' => 'rejected',
                'note' => $data['rejection_reason'],
            ]);

            Notification::create([
                'user_id' => $citizenId,
                'title' => 'Report rejected',
                'body' => 'Your report '.$reportNumber.' was rejected: '.$data['rejection_reason'],
                'type' => 'report_rejected',
                'related_id' => null,
                'related_type' => Report::class,
            ]);

            $report->delete();
        });

        return response()->json([
            'message' => 'Report rejected and deleted successfully.',
        ]);
    }

    private function notifyCitizen(Report $report, string $title, string $body, string $type): void
    {
        Notification::create([
            'user_id' => $report->citizen_id,
            'title' => $title,
            'body' => $body,
            'type' => $type,
            'related_id' => $report->id,
            'related_type' => Report::class,
        ]);
    }
}
