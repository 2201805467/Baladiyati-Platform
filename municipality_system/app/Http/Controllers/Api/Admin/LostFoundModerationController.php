<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\LostFoundAbuseReport;
use App\Models\LostFoundItem;
use App\Support\SecurityLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class LostFoundModerationController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $items = LostFoundItem::with('publisher:id,full_name,email,phone')
            ->withCount(['comments', 'chatThreads'])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('item_type'), fn ($query) => $query->where('item_type', $request->string('item_type')))
            ->when($request->filled('category'), fn ($query) => $query->where('category', $request->string('category')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = '%'.$request->string('search')->toString().'%';
                $query->where(fn ($query) => $query
                    ->where('title', 'like', $search)
                    ->orWhere('description', 'like', $search)
                    ->orWhere('area_name', 'like', $search));
            })
            ->latest()
            ->paginate($request->integer('per_page', 30));

        return response()->json($items);
    }

    public function show(LostFoundItem $item): JsonResponse
    {
        $item->load([
            'publisher:id,full_name,email,phone',
            'comments.user:id,full_name,email',
        ])->loadCount(['comments', 'chatThreads']);

        return response()->json([
            'item' => $item,
        ]);
    }

    public function remove(Request $request, LostFoundItem $item): JsonResponse
    {
        $data = $request->validate([
            'removal_reason' => ['required', 'string', 'max:1000'],
        ]);

        if ($item->status === 'removed') {
            return response()->json(['message' => 'Post is already removed.'], 422);
        }

        $item->update([
            'status' => 'removed',
            'removed_by' => $request->user()->id,
            'removed_at' => now(),
            'removal_reason' => $data['removal_reason'],
        ]);

        SecurityLogger::log($request, $request->user(), 'lost_found.removed:'.$item->id, 'success');

        return response()->json([
            'message' => 'Lost and found post removed successfully.',
            'item' => $item->fresh(),
        ]);
    }

    public function abuseReports(Request $request): JsonResponse
    {
        $reports = LostFoundAbuseReport::with([
                'reporter:id,full_name,email,phone',
                'reportable',
            ])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->latest()
            ->paginate($request->integer('per_page', 30));

        $reports->getCollection()->transform(function (LostFoundAbuseReport $report) {
            $reportable = $report->reportable;
            $item = $reportable instanceof LostFoundItem
                ? $reportable
                : $reportable?->thread?->item;

            $payload = $report->toArray();
            unset($payload['reportable']);

            return array_merge($payload, [
                'reportable_label' => $item?->title,
                'reportable_item_id' => $item?->id,
            ]);
        });

        return response()->json($reports);
    }

    public function updateAbuseReport(Request $request, LostFoundAbuseReport $abuseReport): JsonResponse
    {
        $data = $request->validate([
            'status' => ['required', Rule::in(['pending', 'reviewed', 'dismissed'])],
        ]);

        $abuseReport->update([
            'status' => $data['status'],
            'reviewed_by' => $request->user()->id,
            'reviewed_at' => now(),
        ]);

        SecurityLogger::log($request, $request->user(), 'lost_found.abuse_report.updated:'.$abuseReport->id, 'success');

        return response()->json([
            'message' => 'Abuse report updated successfully.',
            'abuse_report' => $abuseReport->fresh(),
        ]);
    }
}
