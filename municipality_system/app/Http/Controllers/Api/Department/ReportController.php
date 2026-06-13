<?php

namespace App\Http\Controllers\Api\Department;

use App\Http\Controllers\Controller;
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
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
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
                'comments.user',
                'logs.actor',
                'rating',
            ]),
        ]);
    }

    public function updateStatus(Request $request, Report $report): JsonResponse
    {
        $this->ensureDepartmentOwnsReport($request, $report);

        $data = $request->validate([
            'status' => ['required', Rule::in(['assigned', 'in_progress', 'pending', 'resolved'])],
            'note' => ['nullable', 'string', 'max:2000'],
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

        return response()->json([
            'message' => 'Comment added successfully.',
            'comment' => $comment->load('user'),
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
            'note' => ['nullable', 'string', 'max:2000'],
            'completion_image' => ['nullable', 'image', 'max:5120'],
        ]);

        $oldStatus = $report->status;

        DB::transaction(function () use ($report, $request, $data, $oldStatus) {
            if ($request->hasFile('completion_image')) {
                $path = $request->file('completion_image')->store('reports/'.$report->id, 'public');

                ReportImage::create([
                    'report_id' => $report->id,
                    'image_url' => Storage::url($path),
                    'image_type' => 'after',
                    'uploaded_by' => $request->user()->id,
                ]);
            }

            $report->update([
                'status' => 'closed',
                'closed_at' => now(),
            ]);

            ReportLog::create([
                'report_id' => $report->id,
                'action_by' => $request->user()->id,
                'action' => 'closed',
                'old_status' => $oldStatus,
                'new_status' => 'closed',
                'note' => $data['note'] ?? 'Report closed by department.',
            ]);
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
}
