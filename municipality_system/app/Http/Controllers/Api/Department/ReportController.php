<?php

namespace App\Http\Controllers\Api\Department;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\Report;
use App\Models\ReportComment;
use App\Models\ReportImage;
use App\Models\ReportLog;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class ReportController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $deptId = $this->departmentId($request);

        $reports = Report::with(['citizen', 'category', 'area', 'images', 'rating'])
            ->where('dept_id', $deptId)
            ->when(
                $request->filled('status'),
                fn ($query) => $query->where('status', $request->string('status')),
                fn ($query) => $query->whereIn('status', ['transferred', 'in_progress', 'pending'])
            )
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
            ->orderByRaw('sla_due_at is null')
            ->orderBy('sla_due_at')
            ->paginate($request->integer('per_page', 15));

        return response()->json($reports);
    }

    public function show(Request $request, Report $report): JsonResponse
    {
        $this->ensureDepartmentOwnsReport($request, $report);

        return response()->json([
            'report' => $report->load([
                'citizen',
                'category',
                'department',
                'area',
                'images.uploader',
                'comments.user.role',
                'logs.actor',
                'rating',
            ]),
        ]);
    }

    public function updateStatus(Request $request, Report $report): JsonResponse
    {
        $this->ensureDepartmentOwnsReport($request, $report);

        $data = $request->validate([
            'status' => ['required', Rule::in(['in_progress', 'pending'])],
            'note' => ['required', 'string', 'max:2000'],
        ]);

        $oldStatus = $report->status;

        DB::transaction(function () use ($report, $request, $data, $oldStatus) {
            $report->update([
                'status' => $data['status'],
            ]);

            ReportLog::create([
                'report_id' => $report->id,
                'action_by' => $request->user()->id,
                'action' => 'status_updated',
                'old_status' => $oldStatus,
                'new_status' => $data['status'],
                'note' => $data['note'] ?? 'Report status updated by department.',
            ]);

            $this->notifyCitizen(
                $report,
                'Report status updated',
                'Your report '.$report->report_number.' status changed to '.$data['status'].'.',
                'report_status'
            );
        });

        return response()->json([
            'message' => 'Report status updated successfully.',
            'report' => $report->fresh()->load(['category', 'department', 'logs.actor']),
        ]);
    }

    public function storeComment(Request $request, Report $report): JsonResponse
    {
        $this->ensureDepartmentOwnsReport($request, $report);

        $data = $request->validate([
            'comment_text' => ['required', 'string', 'max:2000'],
        ]);

        $comment = ReportComment::create([
            'report_id' => $report->id,
            'user_id' => $request->user()->id,
            'comment_text' => $data['comment_text'],
        ]);

        ReportLog::create([
            'report_id' => $report->id,
            'action_by' => $request->user()->id,
            'action' => 'comment_added',
            'old_status' => $report->status,
            'new_status' => $report->status,
            'note' => 'Department added a comment.',
        ]);

        $this->notifyCitizen(
            $report,
            'New reply on your report',
            'A department officer replied to report '.$report->report_number.'.',
            'report_comment'
        );

        return response()->json([
            'message' => 'Comment added successfully.',
            'comment' => $comment->load('user.role'),
        ], 201);
    }

    public function storeAttachment(Request $request, Report $report): JsonResponse
    {
        $this->ensureDepartmentOwnsReport($request, $report);

        $data = $request->validate([
            'image' => ['required', 'image', 'max:5120'],
            'image_type' => ['nullable', Rule::in(['progress', 'after'])],
            'note' => ['nullable', 'string', 'max:2000'],
        ]);

        $path = $data['image']->store('reports/'.$report->id, 'public');

        $image = ReportImage::create([
            'report_id' => $report->id,
            'image_url' => Storage::url($path),
            'image_type' => $data['image_type'] ?? 'progress',
            'uploaded_by' => $request->user()->id,
        ]);

        ReportLog::create([
            'report_id' => $report->id,
            'action_by' => $request->user()->id,
            'action' => 'attachment_uploaded',
            'old_status' => $report->status,
            'new_status' => $report->status,
            'note' => $data['note'] ?? 'Department uploaded report attachment.',
        ]);

        return response()->json([
            'message' => 'Attachment uploaded successfully.',
            'image' => $image->load('uploader'),
        ], 201);
    }

    public function close(Request $request, Report $report): JsonResponse
    {
        $this->ensureDepartmentOwnsReport($request, $report);

        $data = $request->validate([
            'completion_report' => ['required', 'string', 'max:5000'],
            'completion_image' => ['required', 'image', 'max:5120'],
        ]);

        $oldStatus = $report->status;

        DB::transaction(function () use ($report, $request, $data, $oldStatus) {
            $path = $request->file('completion_image')->store('reports/'.$report->id, 'public');

            ReportImage::create([
                'report_id' => $report->id,
                'image_url' => Storage::url($path),
                'image_type' => 'after',
                'uploaded_by' => $request->user()->id,
            ]);

            $report->update([
                'status' => 'closed',
                'completion_report' => $data['completion_report'],
                'closed_at' => now(),
            ]);

            ReportLog::create([
                'report_id' => $report->id,
                'action_by' => $request->user()->id,
                'action' => 'closed',
                'old_status' => $oldStatus,
                'new_status' => 'closed',
                'note' => $data['completion_report'],
            ]);

            $this->notifyCitizen(
                $report,
                'Report closed',
                'Your report '.$report->report_number.' was closed and is ready for rating.',
                'report_status'
            );
        });

        return response()->json([
            'message' => 'Report closed successfully.',
            'report' => $report->fresh()->load(['images', 'logs.actor']),
        ]);
    }

    private function departmentId(Request $request): int
    {
        $deptId = $request->user()->dept_id;

        if (! $deptId) {
            throw new AuthorizationException('Department account is not linked to a department.');
        }

        return $deptId;
    }

    private function ensureDepartmentOwnsReport(Request $request, Report $report): void
    {
        if ($report->dept_id !== $this->departmentId($request)) {
            throw new AuthorizationException('This report is not assigned to your department.');
        }
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
