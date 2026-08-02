<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\GeoBroadcast;
use App\Models\Notification;
use App\Services\GeoBroadcastTargetingService;
use App\Support\SecurityLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class GeoBroadcastController extends Controller
{
    public function __construct(private readonly GeoBroadcastTargetingService $targeting)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $broadcasts = GeoBroadcast::with('creator:id,full_name,email')
            ->withCount('recipients')
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('broadcast_type'), fn ($query) => $query->where('broadcast_type', $request->string('broadcast_type')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = '%'.$request->string('search')->toString().'%';
                $query->where(fn ($query) => $query
                    ->where('title', 'like', $search)
                    ->orWhere('body', 'like', $search));
            })
            ->orderByDesc('created_at')
            ->paginate($request->integer('per_page', 15));

        $broadcasts->getCollection()->transform(fn (GeoBroadcast $broadcast) => $this->formatBroadcast($broadcast));

        return response()->json($broadcasts);
    }

    public function preview(Request $request): JsonResponse
    {
        $data = $request->validate($this->locationRules());
        $citizens = $this->targeting->targetedCitizens(
            (float) $data['latitude'],
            (float) $data['longitude'],
            (int) ($data['radius_meters'] ?? 500)
        );

        return response()->json([
            'targeted_count' => $citizens->count(),
            'home_count' => $citizens->where('matched_by', 'home')->count() + $citizens->where('matched_by', 'home_and_live')->count(),
            'live_count' => $citizens->where('matched_by', 'live')->count() + $citizens->where('matched_by', 'home_and_live')->count(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'body' => ['required', 'string'],
            'broadcast_type' => ['required', Rule::in(['critical', 'service', 'works', 'weather', 'info'])],
            'starts_at' => ['required', 'date'],
            'ends_at' => ['required', 'date', 'after:starts_at'],
            ...$this->locationRules(),
        ]);

        $broadcast = DB::transaction(function () use ($request, $data) {
            $broadcast = GeoBroadcast::create([
                ...$data,
                'radius_meters' => (int) ($data['radius_meters'] ?? 500),
                'status' => 'active',
                'created_by' => $request->user()->id,
            ]);

            $citizens = $this->targeting->targetedCitizens(
                (float) $broadcast->latitude,
                (float) $broadcast->longitude,
                $broadcast->radius_meters
            );

            foreach ($citizens as $citizen) {
                $notification = Notification::create([
                    'user_id' => $citizen->id,
                    'title' => $broadcast->title,
                    'body' => $broadcast->body,
                    'type' => 'geo_broadcast_'.$broadcast->broadcast_type,
                    'related_id' => $broadcast->id,
                    'related_type' => GeoBroadcast::class,
                ]);

                $broadcast->recipients()->create([
                    'user_id' => $citizen->id,
                    'matched_by' => $citizen->matched_by,
                    'notification_id' => $notification->id,
                ]);
            }

            return $broadcast;
        });

        SecurityLogger::log(
            $request,
            $request->user(),
            'geo_broadcast.created:'.$broadcast->id.':recipients='.$broadcast->recipients()->count(),
            'success'
        );

        return response()->json([
            'message' => 'Geo broadcast created successfully.',
            'broadcast' => $this->formatBroadcast($broadcast->fresh()->load('creator:id,full_name,email')->loadCount('recipients')),
        ], 201);
    }

    public function show(GeoBroadcast $geoBroadcast): JsonResponse
    {
        $geoBroadcast->load([
            'creator:id,full_name,email',
            'recipients.user:id,full_name,email,phone,home_latitude,home_longitude,last_latitude,last_longitude,last_location_at',
        ])->loadCount('recipients');

        return response()->json([
            'broadcast' => $this->formatBroadcast($geoBroadcast),
            'recipients' => $geoBroadcast->recipients->map(fn ($recipient) => [
                'id' => $recipient->id,
                'matched_by' => $recipient->matched_by,
                'notification_id' => $recipient->notification_id,
                'citizen' => $recipient->user,
                'created_at' => $recipient->created_at,
            ])->values(),
        ]);
    }

    public function cancel(Request $request, GeoBroadcast $geoBroadcast): JsonResponse
    {
        $data = $request->validate([
            'cancel_reason' => ['required', 'string', 'max:1000'],
        ]);

        if ($geoBroadcast->status !== 'active') {
            return response()->json(['message' => 'Only active broadcasts can be cancelled.'], 422);
        }

        DB::transaction(function () use ($geoBroadcast, $data) {
            $geoBroadcast->update([
                'status' => 'cancelled',
                'cancel_reason' => $data['cancel_reason'],
            ]);

            $geoBroadcast->recipients()
                ->select('id', 'user_id')
                ->chunkById(100, function ($recipients) use ($geoBroadcast, $data) {
                    foreach ($recipients as $recipient) {
                        Notification::create([
                            'user_id' => $recipient->user_id,
                            'title' => 'تم إلغاء تنبيه جغرافي',
                            'body' => 'تم إلغاء التنبيه: '.$geoBroadcast->title.'. السبب: '.$data['cancel_reason'],
                            'type' => 'geo_broadcast_cancelled',
                            'related_id' => $geoBroadcast->id,
                            'related_type' => GeoBroadcast::class,
                        ]);
                    }
                });
        });

        SecurityLogger::log($request, $request->user(), 'geo_broadcast.cancelled:'.$geoBroadcast->id, 'success');

        return response()->json([
            'message' => 'Geo broadcast cancelled successfully.',
            'broadcast' => $this->formatBroadcast($geoBroadcast->fresh()->loadCount('recipients')),
        ]);
    }

    private function locationRules(): array
    {
        return [
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'radius_meters' => ['nullable', 'integer', 'min:50', 'max:20000'],
        ];
    }

    private function formatBroadcast(GeoBroadcast $broadcast): array
    {
        return [
            ...$broadcast->toArray(),
            'starts_at' => $broadcast->starts_at?->format('Y-m-d\TH:i:s'),
            'ends_at' => $broadcast->ends_at?->format('Y-m-d\TH:i:s'),
            'recipients_count' => (int) ($broadcast->recipients_count ?? $broadcast->recipients()->count()),
            'is_currently_active' => $broadcast->status === 'active'
                && now()->betweenIncluded($broadcast->starts_at, $broadcast->ends_at),
        ];
    }
}
