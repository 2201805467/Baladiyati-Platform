<?php

namespace App\Http\Controllers\Api\Citizen;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Rating;
use App\Models\Report;
use App\Models\ReportComment;
use App\Models\ReportImage;
use App\Models\ReportLog;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class ReportController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $reports = Report::with(['category', 'department', 'area', 'images', 'rating'])
            ->where('citizen_id', $request->user()->id)
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return response()->json($reports);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'description' => ['nullable', 'string'],
            'category_id' => ['nullable', 'exists:categories,id'],
            'area_id' => ['nullable', 'exists:areas,id'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'severity' => ['nullable', 'string', 'max:50'],
            'ai_suggested_category' => ['nullable', 'string', 'max:100'],
            'images' => ['nullable', 'array', 'max:5'],
            'images.*' => ['image', 'max:5120'],
        ]);

        $user = $request->user();
        $category = isset($data['category_id'])
            ? Category::find($data['category_id'])
            : null;

        $report = DB::transaction(function () use ($data, $user, $category, $request) {
            $report = Report::create([
                'report_number' => $this->generateReportNumber(),
                'citizen_id' => $user->id,
                'category_id' => $category?->id,
                'dept_id' => $category?->dept_id,
                'area_id' => $data['area_id'] ?? null,
                'title' => $data['title'],
                'description' => $data['description'] ?? null,
                'latitude' => $data['latitude'],
                'longitude' => $data['longitude'],
                'severity' => $data['severity'] ?? 'medium',
                'status' => 'new',
                'ai_suggested_category' => $data['ai_suggested_category'] ?? null,
            ]);

            foreach ($request->file('images', []) as $image) {
                $path = $image->store('reports/'.$report->id, 'public');

                ReportImage::create([
                    'report_id' => $report->id,
                    'image_url' => Storage::url($path),
                    'image_type' => 'before',
                    'uploaded_by' => $user->id,
                ]);
            }

            ReportLog::create([
                'report_id' => $report->id,
                'action_by' => $user->id,
                'action' => 'created',
                'old_status' => null,
                'new_status' => 'new',
                'note' => 'Report submitted by citizen.',
            ]);

            return $report;
        });

        return response()->json([
            'message' => 'Report submitted successfully.',
            'report' => $report->load(['category', 'department', 'area', 'images', 'logs']),
        ], 201);
    }

    public function show(Request $request, Report $report): JsonResponse
    {
        $this->ensureCitizenOwnsReport($request, $report);

        return response()->json([
            'report' => $report->load([
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

    public function storeComment(Request $request, Report $report): JsonResponse
    {
        $this->ensureCitizenOwnsReport($request, $report);

        $data = $request->validate([
            'comment_text' => ['required', 'string', 'max:2000'],
        ]);

        $comment = ReportComment::create([
            'report_id' => $report->id,
            'user_id' => $request->user()->id,
            'comment_text' => $data['comment_text'],
        ]);

        return response()->json([
            'message' => 'Comment added successfully.',
            'comment' => $comment->load('user'),
        ], 201);
    }

    public function storeRating(Request $request, Report $report): JsonResponse
    {
        $this->ensureCitizenOwnsReport($request, $report);

        if (! $report->closed_at && $report->status !== 'closed') {
            return response()->json([
                'message' => 'Only closed reports can be rated.',
            ], 422);
        }

        $data = $request->validate([
            'stars' => ['required', 'integer', 'min:1', 'max:5'],
            'comment' => ['nullable', 'string', 'max:2000'],
        ]);

        $rating = Rating::updateOrCreate(
            ['report_id' => $report->id],
            [
                'citizen_id' => $request->user()->id,
                'stars' => $data['stars'],
                'comment' => $data['comment'] ?? null,
            ]
        );

        return response()->json([
            'message' => 'Rating saved successfully.',
            'rating' => $rating,
        ]);
    }

    private function ensureCitizenOwnsReport(Request $request, Report $report): void
    {
        if ($report->citizen_id !== $request->user()->id) {
            throw new AuthorizationException('This report does not belong to the authenticated citizen.');
        }
    }

    private function generateReportNumber(): string
    {
        do {
            $number = 'REP-'.now()->format('Ymd').'-'.random_int(1000, 9999);
        } while (Report::where('report_number', $number)->exists());

        return $number;
    }
}
