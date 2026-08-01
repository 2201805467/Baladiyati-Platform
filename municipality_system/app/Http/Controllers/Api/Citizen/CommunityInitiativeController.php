<?php

namespace App\Http\Controllers\Api\Citizen;

use App\Http\Controllers\Controller;
use App\Models\CommunityInitiative;
use App\Models\InitiativeRegistration;
use App\Models\Notification;
use App\Services\InitiativeVolunteerBlocker;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class CommunityInitiativeController extends Controller
{
    public function __construct(private readonly InitiativeVolunteerBlocker $volunteerBlocker)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $userId = $request->user()->id;
        $scope = $request->string('scope', 'available')->toString();

        $initiatives = CommunityInitiative::withCount([
            'registrations as registered_count' => fn ($query) => $query->where('status', 'registered'),
            'attendees as attendees_count',
        ])
            ->when($scope === 'my', function ($query) use ($userId) {
                $query->whereHas('registrations', fn ($query) => $query
                    ->where('citizen_id', $userId)
                    ->where('status', 'registered'));
            }, function ($query) {
                $query->whereIn('status', ['published', 'registration_closed']);
            })
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('initiative_type'), fn ($query) => $query->where('initiative_type', $request->string('initiative_type')))
            ->orderByDesc('starts_at')
            ->paginate($request->integer('per_page', 15));

        $registrations = InitiativeRegistration::where('citizen_id', $userId)
            ->whereIn('initiative_id', $initiatives->getCollection()->pluck('id'))
            ->get()
            ->keyBy('initiative_id');

        $initiatives->getCollection()->transform(
            fn (CommunityInitiative $initiative) => $this->formatInitiative($initiative, $registrations->get($initiative->id))
        );

        return response()->json($initiatives);
    }

    public function show(Request $request, CommunityInitiative $initiative): JsonResponse
    {
        $initiative->loadCount([
            'registrations as registered_count' => fn ($query) => $query->where('status', 'registered'),
            'attendees as attendees_count',
        ]);

        $registration = InitiativeRegistration::where('initiative_id', $initiative->id)
            ->where('citizen_id', $request->user()->id)
            ->first();

        return response()->json([
            'initiative' => $this->formatInitiative($initiative, $registration),
        ]);
    }

    public function register(Request $request, CommunityInitiative $initiative): JsonResponse
    {
        $user = $this->volunteerBlocker->refreshUser($request->user());

        if ($user->initiative_registration_blocked_at) {
            return response()->json([
                'message' => 'تم حظر حسابك من التسجيل، يرجى التواصل مع البلدية.',
            ], 403);
        }

        if ($initiative->status !== 'published') {
            return response()->json(['message' => 'Registration is not open for this initiative.'], 422);
        }

        if (now()->greaterThanOrEqualTo($initiative->starts_at)) {
            return response()->json(['message' => 'Registration is closed because the initiative has already started.'], 422);
        }

        $registration = DB::transaction(function () use ($initiative, $user) {
            $initiative = CommunityInitiative::whereKey($initiative->id)->lockForUpdate()->firstOrFail();
            $registeredCount = $initiative->activeRegistrations()->count();

            if ($initiative->max_capacity !== null && $registeredCount >= $initiative->max_capacity) {
                return null;
            }

            return InitiativeRegistration::updateOrCreate(
                [
                    'initiative_id' => $initiative->id,
                    'citizen_id' => $user->id,
                ],
                [
                    'status' => 'registered',
                    'registered_at' => now(),
                    'cancelled_at' => null,
                    'attended_at' => null,
                    'attendance_latitude' => null,
                    'attendance_longitude' => null,
                ]
            );
        });

        if (! $registration) {
            return response()->json(['message' => 'The initiative has reached its maximum capacity.'], 422);
        }

        $this->notifyCreatorIfCapacityIsFull($initiative->fresh());

        return response()->json([
            'message' => 'Registered successfully.',
            'initiative' => $this->formatInitiative($initiative->fresh(), $registration->fresh()),
        ]);
    }

    public function cancelRegistration(Request $request, CommunityInitiative $initiative): JsonResponse
    {
        $registration = InitiativeRegistration::where('initiative_id', $initiative->id)
            ->where('citizen_id', $request->user()->id)
            ->where('status', 'registered')
            ->first();

        if (! $registration) {
            return response()->json(['message' => 'You are not registered in this initiative.'], 404);
        }

        if (now()->greaterThanOrEqualTo($initiative->starts_at)) {
            return response()->json(['message' => 'Registration cannot be cancelled after the initiative starts.'], 422);
        }

        $registration->update([
            'status' => 'cancelled',
            'cancelled_at' => now(),
        ]);

        return response()->json([
            'message' => 'Registration cancelled successfully.',
            'initiative' => $this->formatInitiative($initiative->fresh(), $registration->fresh()),
        ]);
    }

    public function confirmAttendance(Request $request, CommunityInitiative $initiative): JsonResponse
    {
        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $registration = InitiativeRegistration::where('initiative_id', $initiative->id)
            ->where('citizen_id', $request->user()->id)
            ->where('status', 'registered')
            ->first();

        if (! $registration) {
            return response()->json(['message' => 'You must register before confirming attendance.'], 422);
        }

        if ($initiative->status !== 'published' && $initiative->status !== 'registration_closed') {
            return response()->json(['message' => 'Attendance cannot be confirmed for this initiative.'], 422);
        }

        $now = now();
        if ($now->lessThan($initiative->starts_at) || $now->greaterThan($initiative->ends_at)) {
            return response()->json(['message' => 'Attendance can be confirmed only during the initiative time.'], 422);
        }

        $distance = $this->distanceMeters(
            (float) $initiative->latitude,
            (float) $initiative->longitude,
            (float) $data['latitude'],
            (float) $data['longitude']
        );

        if ($distance > $initiative->radius_meters) {
            return response()->json([
                'message' => 'Attendance confirmation failed. Please make sure you are inside the initiative area.',
                'distance_meters' => round($distance, 2),
                'radius_meters' => $initiative->radius_meters,
            ], 422);
        }

        $registration->update([
            'attended_at' => $registration->attended_at ?? $now,
            'attendance_latitude' => $data['latitude'],
            'attendance_longitude' => $data['longitude'],
        ]);

        return response()->json([
            'message' => 'Attendance confirmed successfully.',
            'distance_meters' => round($distance, 2),
            'initiative' => $this->formatInitiative($initiative->fresh(), $registration->fresh()),
        ]);
    }

    private function notifyCreatorIfCapacityIsFull(CommunityInitiative $initiative): void
    {
        if (! $initiative->created_by || $initiative->capacity_notified_at || $initiative->max_capacity === null) {
            return;
        }

        $registeredCount = $initiative->activeRegistrations()->count();
        if ($registeredCount < $initiative->max_capacity) {
            return;
        }

        Notification::create([
            'user_id' => $initiative->created_by,
            'title' => 'اكتمل عدد المتطوعين',
            'body' => 'اكتمل العدد المطلوب لمبادرة '.$initiative->title.'.',
            'type' => 'initiative_capacity_full',
            'related_id' => $initiative->id,
            'related_type' => CommunityInitiative::class,
        ]);

        $initiative->update(['capacity_notified_at' => now()]);
    }

    private function formatInitiative(CommunityInitiative $initiative, ?InitiativeRegistration $registration = null): array
    {
        $registeredCount = (int) ($initiative->registered_count ?? $initiative->activeRegistrations()->count());
        $isFull = $initiative->max_capacity !== null && $registeredCount >= $initiative->max_capacity;
        $now = Carbon::now();
        $isRegistered = $registration?->status === 'registered';

        return [
            ...$initiative->toArray(),
            'registered_count' => $registeredCount,
            'attendees_count' => (int) ($initiative->attendees_count ?? $initiative->attendees()->count()),
            'is_full' => $isFull,
            'available_slots' => $initiative->max_capacity === null ? null : max(0, $initiative->max_capacity - $registeredCount),
            'registration' => $registration,
            'is_registered' => $isRegistered,
            'has_attended' => $registration?->attended_at !== null,
            'can_register' => $initiative->status === 'published' && ! $isFull && ! $isRegistered && $now->lessThan($initiative->starts_at),
            'can_cancel_registration' => $isRegistered && $now->lessThan($initiative->starts_at),
            'can_confirm_attendance' => $isRegistered
                && $registration?->attended_at === null
                && in_array($initiative->status, ['published', 'registration_closed'], true)
                && $now->betweenIncluded($initiative->starts_at, $initiative->ends_at),
        ];
    }

    private function distanceMeters(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadius = 6371000;
        $latDelta = deg2rad($lat2 - $lat1);
        $lngDelta = deg2rad($lng2 - $lng1);
        $a = sin($latDelta / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($lngDelta / 2) ** 2;

        return $earthRadius * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
