<?php

namespace App\Http\Controllers\Api\Citizen;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Rating;
use App\Models\Report;
use App\Models\ReportComment;
use App\Models\ReportImage;
use App\Models\ReportLog;
use App\Services\ReportImageClassifier;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class ReportController extends Controller
{
    private const DUPLICATE_RADIUS_METERS = 100;

    public function index(Request $request): JsonResponse
    {
        $reports = Report::with(['category', 'department', 'area', 'images', 'rating'])
            ->where('citizen_id', $request->user()->id)
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return response()->json($reports);
    }

    public function similar(Request $request): JsonResponse
    {
        $data = $request->validate([
            'category_id' => ['required', 'exists:categories,id'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $similarReports = $this->findSimilarReports(
            (int) $data['category_id'],
            (float) $data['latitude'],
            (float) $data['longitude']
        );

        return response()->json([
            'has_similar' => $similarReports->isNotEmpty(),
            'radius_meters' => self::DUPLICATE_RADIUS_METERS,
            'similar_reports' => $similarReports->values(),
        ]);
    }

    public function classifyImage(Request $request, ReportImageClassifier $classifier): JsonResponse
    {
        $data = $request->validate([
            'image' => ['required', 'image', 'mimes:jpg,jpeg,png', 'max:5120'],
        ]);

        return response()->json([
            'classification' => $classifier->classify($data['image']),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'description' => ['nullable', 'string'],
            'category_id' => ['required', 'exists:categories,id'],
            'area_id' => ['nullable', 'exists:areas,id'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'severity' => ['nullable', 'string', 'max:50'],
            'ai_suggested_category' => ['nullable', 'string', 'max:100'],
            'duplicate_action' => ['nullable', Rule::in(['join', 'independent'])],
            'parent_report_id' => ['required_if:duplicate_action,join', 'nullable', 'exists:reports,id'],
            'images' => ['required', 'array', 'min:1', 'max:5'],
            'images.*' => ['image', 'max:5120'],
        ]);

        $user = $request->user();
        $category = Category::findOrFail($data['category_id']);
        $similarReports = $this->findSimilarReports(
            $category->id,
            (float) $data['latitude'],
            (float) $data['longitude']
        );
        $parentReport = null;

        if ($similarReports->isNotEmpty() && empty($data['duplicate_action'])) {
            return response()->json([
                'message' => 'Similar reports were found nearby. Choose whether to join an existing report or submit independently.',
                'has_similar' => true,
                'radius_meters' => self::DUPLICATE_RADIUS_METERS,
                'similar_reports' => $similarReports->values(),
            ], 409);
        }

        if (($data['duplicate_action'] ?? null) === 'join') {
            $parentReport = Report::findOrFail((int) $data['parent_report_id']);

            if (! $this->isValidDuplicateParent($parentReport, $category->id, (float) $data['latitude'], (float) $data['longitude'])) {
                return response()->json([
                    'message' => 'The selected parent report is not similar enough to join.',
                ], 422);
            }
        }

        $report = DB::transaction(function () use ($data, $user, $category, $request, $parentReport) {
            $isDuplicate = $parentReport !== null;

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
                'is_duplicate' => $isDuplicate,
                'parent_report_id' => $parentReport?->id,
                'sla_due_at' => $this->calculateSlaDueAt($data['severity'] ?? 'medium'),
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
                'note' => $isDuplicate
                    ? 'Report submitted by citizen and joined to report '.$parentReport->report_number.'.'
                    : 'Report submitted by citizen.',
            ]);

            return $report;
        });

        return response()->json([
            'message' => $report->is_duplicate
                ? 'Report joined to a similar report successfully.'
                : 'Report submitted successfully.',
            'report' => $report->load(['category', 'department', 'area', 'images', 'logs', 'parentReport']),
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
                'parentReport',
                'duplicateReports',
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

        if (! $report->closed_at || $report->status !== 'closed') {
            return response()->json([
                'message' => 'Only closed reports can be rated.',
            ], 422);
        }

        if (! $report->images()->where('image_type', 'after')->exists()) {
            return response()->json([
                'message' => 'Reports can be rated only after completion evidence is uploaded.',
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

    private function findSimilarReports(int $categoryId, float $latitude, float $longitude): \Illuminate\Support\Collection
    {
        $latDelta = self::DUPLICATE_RADIUS_METERS / 111320;
        $lngDelta = self::DUPLICATE_RADIUS_METERS / (111320 * max(cos(deg2rad($latitude)), 0.000001));

        return Report::with(['category:id,category_name', 'department:id,dept_name'])
            ->where('category_id', $categoryId)
            ->where('is_duplicate', false)
            ->whereNotIn('status', ['closed', 'rejected'])
            ->whereBetween('latitude', [$latitude - $latDelta, $latitude + $latDelta])
            ->whereBetween('longitude', [$longitude - $lngDelta, $longitude + $lngDelta])
            ->latest()
            ->limit(20)
            ->get()
            ->map(function (Report $report) use ($latitude, $longitude) {
                $distance = $this->distanceInMeters(
                    $latitude,
                    $longitude,
                    (float) $report->latitude,
                    (float) $report->longitude
                );

                $report->setAttribute('distance_meters', round($distance, 2));

                return $report;
            })
            ->filter(fn (Report $report) => $report->distance_meters <= self::DUPLICATE_RADIUS_METERS)
            ->sortBy('distance_meters')
            ->values();
    }

    private function isValidDuplicateParent(Report $parentReport, int $categoryId, float $latitude, float $longitude): bool
    {
        if (
            $parentReport->category_id !== $categoryId ||
            $parentReport->is_duplicate ||
            in_array($parentReport->status, ['closed', 'rejected'], true)
        ) {
            return false;
        }

        return $this->distanceInMeters(
            $latitude,
            $longitude,
            (float) $parentReport->latitude,
            (float) $parentReport->longitude
        ) <= self::DUPLICATE_RADIUS_METERS;
    }

    private function distanceInMeters(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadius = 6371000;
        $latFrom = deg2rad($lat1);
        $latTo = deg2rad($lat2);
        $latDelta = deg2rad($lat2 - $lat1);
        $lngDelta = deg2rad($lng2 - $lng1);

        $a = sin($latDelta / 2) ** 2
            + cos($latFrom) * cos($latTo) * sin($lngDelta / 2) ** 2;

        return 2 * $earthRadius * atan2(sqrt($a), sqrt(1 - $a));
    }

    private function generateReportNumber(): string
    {
        do {
            $number = 'REP-'.now()->format('Ymd').'-'.random_int(1000, 9999);
        } while (Report::where('report_number', $number)->exists());

        return $number;
    }

    private function calculateSlaDueAt(string $severity): \Illuminate\Support\Carbon
    {
        return match ($severity) {
            'high' => now()->addDay(),
            'low' => now()->addDays(5),
            default => now()->addDays(3),
        };
    }
}
