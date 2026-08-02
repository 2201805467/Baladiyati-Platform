<?php

namespace App\Http\Controllers\Api\Citizen;

use App\Http\Controllers\Controller;
use App\Models\GeoBroadcast;
use App\Models\Notification;
use App\Models\User;
use App\Services\GeoBroadcastTargetingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class GeoBroadcastController extends Controller
{
    public function __construct(private readonly GeoBroadcastTargetingService $targeting)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $this->syncActiveBroadcastsForUser($user);

        $broadcasts = GeoBroadcast::query()
            ->whereHas('recipients', fn ($query) => $query->where('user_id', $user->id))
            ->when($request->boolean('active_only'), fn ($query) => $query
                ->where('status', 'active')
                ->where('ends_at', '>=', now()))
            ->withCount('recipients')
            ->orderByDesc('created_at')
            ->paginate($request->integer('per_page', 15));

        $broadcasts->getCollection()->transform(fn (GeoBroadcast $broadcast) => $this->formatBroadcast($broadcast, $user));

        return response()->json($broadcasts);
    }

    public function show(Request $request, GeoBroadcast $geoBroadcast): JsonResponse
    {
        $user = $request->user();
        $this->syncBroadcastForUser($geoBroadcast, $user);

        abort_unless(
            $geoBroadcast->recipients()->where('user_id', $user->id)->exists(),
            404
        );

        $geoBroadcast->loadCount('recipients');

        return response()->json([
            'broadcast' => $this->formatBroadcast($geoBroadcast, $user),
        ]);
    }

    public function updateHomeLocation(Request $request): JsonResponse
    {
        $data = $request->validate([
            'home_latitude' => ['required', 'numeric', 'between:-90,90'],
            'home_longitude' => ['required', 'numeric', 'between:-180,180'],
            'location_sharing_enabled' => ['nullable', 'boolean'],
        ]);

        $user = $request->user();
        $user->update([
            'home_latitude' => $data['home_latitude'],
            'home_longitude' => $data['home_longitude'],
            'location_sharing_enabled' => $data['location_sharing_enabled'] ?? $user->location_sharing_enabled,
        ]);

        $this->syncActiveBroadcastsForUser($user->fresh());

        return response()->json([
            'message' => 'Home location updated successfully.',
            'user' => $user->fresh(),
        ]);
    }

    public function updateLastLocation(Request $request): JsonResponse
    {
        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $user = $request->user();
        if (! $user->location_sharing_enabled) {
            return response()->json([
                'message' => 'Location sharing is disabled.',
                'user' => $user,
            ]);
        }

        $user->update([
            'last_latitude' => $data['latitude'],
            'last_longitude' => $data['longitude'],
            'last_location_at' => now(),
        ]);

        $createdCount = $this->syncActiveBroadcastsForUser($user->fresh());

        return response()->json([
            'message' => 'Current location synced successfully.',
            'new_geo_broadcast_notifications' => $createdCount,
            'user' => $user->fresh(),
        ]);
    }

    private function syncActiveBroadcastsForUser(User $user): int
    {
        $createdCount = 0;

        GeoBroadcast::where('status', 'active')
            ->where('ends_at', '>=', now())
            ->chunkById(100, function ($broadcasts) use ($user, &$createdCount) {
                foreach ($broadcasts as $broadcast) {
                    if ($this->syncBroadcastForUser($broadcast, $user)) {
                        $createdCount++;
                    }
                }
            });

        return $createdCount;
    }

    private function syncBroadcastForUser(GeoBroadcast $broadcast, User $user): bool
    {
        if ($broadcast->status !== 'active' || now()->greaterThan($broadcast->ends_at)) {
            return false;
        }

        if ($broadcast->recipients()->where('user_id', $user->id)->exists()) {
            return false;
        }

        $homeMatch = $this->targeting->hasPointInsideRadius(
            $user->home_latitude,
            $user->home_longitude,
            (float) $broadcast->latitude,
            (float) $broadcast->longitude,
            $broadcast->radius_meters
        );
        $liveMatch = $user->location_sharing_enabled && $this->targeting->hasPointInsideRadius(
            $user->last_latitude,
            $user->last_longitude,
            (float) $broadcast->latitude,
            (float) $broadcast->longitude,
            $broadcast->radius_meters
        );

        if (! $homeMatch && ! $liveMatch) {
            return false;
        }

        $matchedBy = $homeMatch && $liveMatch ? 'home_and_live' : ($homeMatch ? 'home' : 'live');
        $notification = Notification::create([
            'user_id' => $user->id,
            'title' => $broadcast->title,
            'body' => $broadcast->body,
            'type' => 'geo_broadcast_'.$broadcast->broadcast_type,
            'related_id' => $broadcast->id,
            'related_type' => GeoBroadcast::class,
        ]);

        $broadcast->recipients()->create([
            'user_id' => $user->id,
            'matched_by' => $matchedBy,
            'notification_id' => $notification->id,
        ]);

        return true;
    }

    private function formatBroadcast(GeoBroadcast $broadcast, User $user): array
    {
        $recipient = $broadcast->recipients()
            ->where('user_id', $user->id)
            ->first();

        return [
            ...$broadcast->toArray(),
            'starts_at' => $broadcast->starts_at?->format('Y-m-d\TH:i:s'),
            'ends_at' => $broadcast->ends_at?->format('Y-m-d\TH:i:s'),
            'recipients_count' => (int) ($broadcast->recipients_count ?? $broadcast->recipients()->count()),
            'matched_by' => $recipient?->matched_by,
            'is_currently_active' => $broadcast->status === 'active'
                && now()->betweenIncluded($broadcast->starts_at, $broadcast->ends_at),
        ];
    }
}
