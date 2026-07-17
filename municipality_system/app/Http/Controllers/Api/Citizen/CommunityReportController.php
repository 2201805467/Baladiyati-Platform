<?php

namespace App\Http\Controllers\Api\Citizen;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\Report;
use App\Models\ReportComment;
use App\Models\ReportVote;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class CommunityReportController extends Controller
{
    private const DEFAULT_RADIUS_KM = 5;
    private const MAX_RADIUS_KM = 25;

    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'radius_km' => ['nullable', 'numeric', 'min:0.1', 'max:'.self::MAX_RADIUS_KM],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $user = $request->user();
        $latitude = isset($data['latitude']) ? (float) $data['latitude'] : null;
        $longitude = isset($data['longitude']) ? (float) $data['longitude'] : null;
        $radiusKm = isset($data['radius_km']) ? (float) $data['radius_km'] : self::DEFAULT_RADIUS_KM;

        $query = Report::query()
            ->with(['category:id,category_name', 'department:id,dept_name', 'images'])
            ->withCount($this->voteCountColumns())
            ->whereNotNull('citizen_id')
            ->where('citizen_id', '!=', $user->id)
            ->whereNotIn('status', ['closed', 'rejected']);

        if ($latitude !== null && $longitude !== null) {
            $query
                ->select('reports.*')
                ->selectRaw(
                    '(6371 * acos(least(1, greatest(-1, cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude)))))) as distance_km',
                    [$latitude, $longitude, $latitude]
                )
                ->having('distance_km', '<=', $radiusKm)
                ->orderBy('distance_km');
        } else {
            $query->latest();
        }

        $reports = $query
            ->limit($request->integer('per_page', 15))
            ->get()
            ->map(fn (Report $report) => $this->decorateReport($report, $user->id));

        return response()->json([
            'data' => $reports,
            'radius_km' => $radiusKm,
        ]);
    }

    public function show(Request $request, Report $report): JsonResponse
    {
        $this->ensureCommunityReport($request, $report);

        $report->load([
            'category:id,category_name',
            'department:id,dept_name',
            'images.uploader',
            'comments.user.role',
        ])->loadCount($this->voteCountColumns());

        return response()->json([
            'report' => $this->decorateReport($report, $request->user()->id),
        ]);
    }

    public function storeComment(Request $request, Report $report): JsonResponse
    {
        $this->ensureCommunityReport($request, $report);

        $data = $request->validate([
            'comment_text' => ['required', 'string', 'max:2000'],
        ]);

        $comment = ReportComment::create([
            'report_id' => $report->id,
            'user_id' => $request->user()->id,
            'comment_text' => $data['comment_text'],
        ]);

        if ($report->citizen_id) {
            Notification::create([
                'user_id' => $report->citizen_id,
                'title' => 'New community comment',
                'body' => 'A citizen commented on your report: '.$this->reportLabel($report),
                'type' => 'community_report_comment',
                'related_id' => $report->id,
                'related_type' => Report::class,
            ]);
        }

        return response()->json([
            'message' => 'Comment added successfully.',
            'comment' => $comment->load('user.role'),
        ], 201);
    }

    public function vote(Request $request, Report $report): JsonResponse
    {
        $this->ensureCommunityReport($request, $report);

        $data = $request->validate([
            'vote_type' => ['required', Rule::in(['up', 'down'])],
        ]);

        ReportVote::updateOrCreate(
            [
                'report_id' => $report->id,
                'citizen_id' => $request->user()->id,
            ],
            ['vote_type' => $data['vote_type']]
        );

        return response()->json([
            'message' => 'Vote saved successfully.',
            'report' => $this->freshReportPayload($report->id, $request->user()->id),
        ]);
    }

    public function destroyVote(Request $request, Report $report): JsonResponse
    {
        $this->ensureCommunityReport($request, $report);

        ReportVote::where('report_id', $report->id)
            ->where('citizen_id', $request->user()->id)
            ->delete();

        return response()->json([
            'message' => 'Vote removed successfully.',
            'report' => $this->freshReportPayload($report->id, $request->user()->id),
        ]);
    }

    private function ensureCommunityReport(Request $request, Report $report): void
    {
        if (! $report->citizen_id || $report->citizen_id === $request->user()->id) {
            throw new AuthorizationException('This report is not available in community reports.');
        }

        if (in_array($report->status, ['closed', 'rejected'], true)) {
            throw new AuthorizationException('Closed or rejected reports are not available for community interaction.');
        }
    }

    private function freshReportPayload(int $reportId, int $userId): Report
    {
        $report = Report::with([
            'category:id,category_name',
            'department:id,dept_name',
            'images.uploader',
            'comments.user.role',
        ])
            ->withCount($this->voteCountColumns())
            ->findOrFail($reportId);

        return $this->decorateReport($report, $userId);
    }

    private function decorateReport(Report $report, int $userId): Report
    {
        $viewerVote = ReportVote::where('report_id', $report->id)
            ->where('citizen_id', $userId)
            ->value('vote_type');

        $report->setAttribute('viewer_vote', $viewerVote);
        $report->setAttribute('distance_km', isset($report->distance_km) ? round((float) $report->distance_km, 2) : null);

        return $report;
    }

    private function voteCountColumns(): array
    {
        return [
            'votes as upvotes_count' => fn ($query) => $query->where('vote_type', 'up'),
            'votes as downvotes_count' => fn ($query) => $query->where('vote_type', 'down'),
        ];
    }

    private function reportLabel(Report $report): string
    {
        return $report->title
            ?: $report->description
            ?: $report->category?->category_name
            ?: $report->report_number;
    }
}
